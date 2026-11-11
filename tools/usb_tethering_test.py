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
APK_ON_DEVICE = "/vendor/overlay/LibreHUEthernetUsb.apk"
# The feature that starts EthernetService (SystemServer): the head unit has it, the emulator does not.
USB_HOST = "/vendor/etc/permissions/android.hardware.usb.host.xml"
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


def remount(name):
    """System and vendor writable until the next reboot (-writable-system emulator)."""
    out = adb("remount", timeout=180)
    if "remount succeeded" not in out:
        save(name.replace(".txt", "-first.txt"), out)
        adb("disable-verity", timeout=120)
        reboot()
        out = adb("remount", timeout=180)
    save(name, out)


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

    # The head unit's USB host feature, which starts EthernetService (writable system and vendor first).
    remount("remount.txt")
    feature = os.path.join(OUT, "android.hardware.usb.host.xml")
    with open(feature, "w", encoding="utf-8") as f:
        f.write('<permissions>\n    <feature name="android.hardware.usb.host" />\n</permissions>\n')
    adb("push", feature, USB_HOST)
    sh(f"chmod 0644 {USB_HOST}; chcon u:object_r:vendor_configs_file:s0 {USB_HOST}")
    save("usb-host.txt", sh(f"cat {USB_HOST}; ls -lZ {USB_HOST}"))
    reboot()
    check("USB host feature", "android.hardware.usb.host" in sh("pm list features"))

    # Without the overlay: Android 9's default.
    veth_up()
    time.sleep(8)
    dump = sh("dumpsys ethernet")
    save("ethernet-before.txt", dump)
    check("filter without the overlay is eth\\d", filter_line(dump) == "eth\\d", str(filter_line(dump)))
    check("usb0 ignored without the overlay", "usb0" not in tracked(dump), ", ".join(sorted(tracked(dump))) or "none tracked")
    sh("ip link del usb0")

    # The overlay where the zip puts it, then a reboot (zygote makes the idmap of static overlays at its start,
    # system_server reads the filter once, at its start).
    remount("remount-2.txt")  # read-only again after each reboot
    save("push.txt", adb("push", APK, APK_ON_DEVICE))
    sh(f"chmod 0644 {APK_ON_DEVICE}; chcon u:object_r:vendor_overlay_file:s0 {APK_ON_DEVICE}")
    save("overlay-files.txt", sh("ls -laZ /vendor/overlay"))
    reboot()
    save("resource-cache.txt", sh("ls -laZ /data/resource-cache; echo; cat /data/resource-cache/overlays.list"))

    # Static overlays are not in `cmd overlay list`: their state is in `dumpsys overlay`.
    overlays = sh("dumpsys overlay")
    save("overlays.txt", overlays)
    m = re.search(r"org\.librehu\.overlay\.ethernetusb:0 \{.*?mState\.*: (\w+)", overlays, re.S)
    check("overlay applied (static, with its idmap)", m is not None and m.group(1) == "STATE_ENABLED_STATIC", m.group(1) if m else "absent")
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
    # The phone is another machine; here its side shares the emulator's routing, where Android's policy rules send
    # unmarked traffic to the default network: the DHCP replies to 192.168.42.0/24 must leave by phone0 (main table).
    sh("ip rule add to 192.168.42.0/24 lookup main pref 9000")
    sh("nohup /system/bin/dnsmasq --keep-in-foreground --no-resolv --no-poll --bind-interfaces --interface=phone0 "
       "--except-interface=lo --dhcp-range=192.168.42.10,192.168.42.20,1h --dhcp-option=3,192.168.42.129 "
       "--dhcp-option=6,192.168.42.129 --dhcp-leasefile=/data/local/tmp/dnsmasq.leases --pid-file=/data/local/tmp/dnsmasq.pid --log-dhcp "
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
    save("ip-rules.txt", sh("ip rule; echo; ip route show table main"))
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
