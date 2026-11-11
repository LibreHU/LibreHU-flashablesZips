#!/usr/bin/env python3
"""zip usb-tethering on an Android 9 emulator (CI: .github/workflows/usb-tethering-test.yml): Android's EthernetTracker
without, then with the overlay (LibreHUEthernetUsb.apk in /vendor/overlay, as the zip puts it). A veth pair stands for a
phone's USB tethering: usb0 on the head unit's side, phone0 for the phone's side, with Android's dnsmasq as the phone's
DHCP server. Checks: the name filter of `dumpsys ethernet` (eth\\d, then (eth|usb)\\d+), usb0 ignored then tracked,
then an IPv4 address on usb0 from DHCP. Outputs in <out>. Exit 1 on a failure.

    python3 tools/usb_tethering_test.py zips/tweaks/usb-tethering/files/LibreHUEthernetUsb.apk out
"""
import os
import re
import subprocess
import sys
import time

APK, OUT = sys.argv[1:3]
DIR = "/vendor/overlay/LibreHUEthernetUsb"
results, failures = [], []


def adb(*args, timeout=120):
    try:
        r = subprocess.run(["adb", *args], text=True, capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return "TIMEOUT"
    return r.stdout + r.stderr


def sh(cmd, timeout=120):
    return adb("shell", cmd, timeout=timeout)


def save(name, text):
    with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
        f.write(text)


def check(what, ok, detail=""):
    results.append(f"{what}: {'ok' if ok else 'FAILED'}{' (' + detail + ')' if detail else ''}")
    if not ok:
        failures.append(what)


def boot():
    adb("wait-for-device", timeout=600)
    for _ in range(180):
        if sh("getprop sys.boot_completed").strip() == "1":
            break
        time.sleep(2)
    time.sleep(10)
    adb("root")
    time.sleep(3)
    adb("wait-for-device", timeout=300)


def reboot():
    adb("reboot", timeout=60)
    time.sleep(10)
    boot()


def filter_line(dump):
    m = re.search(r"Ethernet interface name filter: (\S+)", dump)
    return m.group(1) if m else None


def tracked(dump):
    """Interfaces under "Tracking interfaces:" of EthernetNetworkFactory's dump."""
    part = dump.split("Tracking interfaces:", 1)
    return set(re.findall(r"^\s*(\w+\d+):", part[1], re.M)) if len(part) == 2 else set()


def veth_up():
    """usb0 with its peer phone0 (veth); a dummy usb0 when the kernel has no veth (then no DHCP test). True: veth."""
    sh("ip link del usb0 2>/dev/null")
    out = sh("ip link add usb0 type veth peer name phone0 && ip link set phone0 up && ip link set usb0 up && echo VETH_OK")
    if "VETH_OK" in out:
        return True
    save("veth-error.txt", out)
    sh("ip link add usb0 type dummy && ip link set usb0 up")
    return False


def main():
    os.makedirs(OUT, exist_ok=True)
    boot()
    save("getprop.txt", sh("getprop"))
    check("Android 9", sh("getprop ro.build.version.sdk").strip() == "28")

    # Without the overlay: Android 9's default.
    veth_up()
    time.sleep(8)
    dump = sh("dumpsys ethernet")
    save("ethernet-before.txt", dump)
    check("filter without the overlay is eth\\d", filter_line(dump) == "eth\\d", str(filter_line(dump)))
    check("usb0 ignored without the overlay", "usb0" not in tracked(dump), ", ".join(sorted(tracked(dump))) or "none tracked")
    sh("ip link del usb0")

    # The overlay where the zip puts it, then a reboot (system_server reads the filter once, at its start).
    out = adb("remount", timeout=180)
    if "remount succeeded" not in out:
        save("remount-1.txt", out)
        adb("disable-verity", timeout=120)
        reboot()
        out = adb("remount", timeout=180)
    save("remount.txt", out)
    sh(f"mkdir -p {DIR}")
    save("push.txt", adb("push", APK, f"{DIR}/LibreHUEthernetUsb.apk"))
    sh(f"chmod 0755 {DIR}; chmod 0644 {DIR}/LibreHUEthernetUsb.apk; chcon -R u:object_r:vendor_overlay_file:s0 {DIR}")
    save("overlay-files.txt", sh(f"ls -laZ {DIR}"))
    reboot()

    overlays = sh("cmd overlay list")
    save("overlays.txt", overlays + "\n\n" + sh("dumpsys overlay"))
    check("overlay known to Android", "org.librehu.overlay.ethernetusb" in overlays)
    veth = veth_up()
    time.sleep(8)
    dump = sh("dumpsys ethernet")
    save("ethernet-after.txt", dump)
    check("filter with the overlay is (eth|usb)\\d+", filter_line(dump) == "(eth|usb)\\d+", str(filter_line(dump)))
    check("usb0 tracked with the overlay", "usb0" in tracked(dump), ", ".join(sorted(tracked(dump))) or "none tracked")

    if not veth:
        results.append("DHCP on usb0: not tested (no veth in this kernel)")
        return finish()
    # The phone's side: an address and a DHCP server on phone0, then usb0 must get an address.
    sh("ip addr add 192.168.42.129/24 dev phone0")
    sh("nohup /system/bin/dnsmasq --keep-in-foreground --no-resolv --no-poll --bind-interfaces --interface=phone0 "
       "--except-interface=lo --dhcp-range=192.168.42.10,192.168.42.20,1h --dhcp-option=3,192.168.42.129 "
       "--dhcp-option=6,192.168.42.129 --dhcp-leasefile=/data/local/tmp/dnsmasq.leases "
       "> /data/local/tmp/dnsmasq.log 2>&1 &")
    # Link down and up again: EthernetNetworkFactory starts IpClient (DHCP) when the link comes up.
    sh("ip link set usb0 down; sleep 2; ip link set usb0 up")
    addr = ""
    for _ in range(30):
        addr = sh("ip -4 addr show usb0")
        if "inet 192.168.42." in addr:
            break
        time.sleep(2)
    save("usb0-addr.txt", addr)
    save("dnsmasq.txt", sh("cat /data/local/tmp/dnsmasq.log; ps -A | grep dnsmasq"))
    save("ethernet-dhcp.txt", sh("dumpsys ethernet"))
    save("connectivity.txt", sh("dumpsys connectivity"))
    m = re.search(r"inet (192\.168\.42\.\d+)", addr)
    check("usb0 address from DHCP", m is not None, m.group(1) if m else "none")
    finish()


def finish():
    save("logcat.txt", adb("logcat", "-d", "-v", "threadtime", "-b", "all", timeout=300))
    summary = "\n".join(results + [f"FAILED: {x}" for x in failures])
    print(summary, flush=True)
    save("summary.txt", summary + "\n")
    with open(os.environ.get("GITHUB_STEP_SUMMARY", os.devnull), "a", encoding="utf-8") as f:
        f.write("## zip usb-tethering on Android 9\n\n```\n" + summary + "\n```\n")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
