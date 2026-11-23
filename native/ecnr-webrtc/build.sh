#!/bin/bash
# Copyright (C) 2026 LibreHU
# SPDX-License-Identifier: Apache-2.0
#
# Builds libEcnrForCustomer.so (WebRTC ECNR of the UJC201, see ecnr_webrtc.cpp and README.md).
#   ./build.sh host                       host build, then the test (test/ecnr_test.cpp)
#   ./build.sh android <abi> [out dir]    Android build with the NDK ($ANDROID_NDK_HOME or $ANDROID_NDK_LATEST_HOME),
#                                         abi = armeabi-v7a or arm64-v8a, API 28 (Android 9, the vendor of the unit);
#                                         stripped and checked (only libc / libm / libdl / liblog needed, only
#                                         AUDIO_ECNR_SYM exported), copied to <out dir>/libEcnrForCustomer_<abi>.so
# Needs meson and ninja. WebRTC audio processing and abseil come from the wrap files of subprojects/.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

case "${1:-}" in
host)
    # rtc_base/trace_event.h of WebRTC 2.1 uses uint8_t without <cstdint>: some libstdc++ versions (GitHub's Ubuntu)
    # do not bring it in transitively. -include cstdint for the whole build, subprojects included (machine file).
    printf "[built-in options]\ncpp_args = ['-include', 'cstdint']\n" > native-host.ini
    rm -rf build-host
    meson setup build-host --native-file native-host.ini -Ddefault_library=static
    ninja -C build-host
    meson test -C build-host --print-errorlogs -v
    ;;
android)
    ABI="${2:?abi}"
    OUT="${3:-$HERE/dist}"
    NDK="${ANDROID_NDK_HOME:-${ANDROID_NDK_LATEST_HOME:-}}"
    [ -d "$NDK" ] || { echo "Android NDK not found (ANDROID_NDK_HOME)" >&2; exit 1; }
    TC="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin"
    case "$ABI" in
        armeabi-v7a) TRIPLE=armv7a-linux-androideabi28; FAMILY=arm; CPU=armv7a; MACHINE=ARM ;;
        arm64-v8a) TRIPLE=aarch64-linux-android28; FAMILY=aarch64; CPU=armv8a; MACHINE=AArch64 ;;
        *) echo "unknown abi $ABI" >&2; exit 1 ;;
    esac
    B="build-$ABI"
    cat > "cross-$ABI.ini" <<EOF
[binaries]
c = '$TC/$TRIPLE-clang'
cpp = '$TC/$TRIPLE-clang++'
ar = '$TC/llvm-ar'
strip = '$TC/llvm-strip'

[built-in options]
cpp_args = ['-include', 'cstdint']
cpp_link_args = ['-static-libstdc++']

[host_machine]
system = 'android'
cpu_family = '$FAMILY'
cpu = '$CPU'
endian = 'little'
EOF
    rm -rf "$B"
    meson setup "$B" --cross-file "cross-$ABI.ini" -Ddefault_library=static
    ninja -C "$B" libEcnrForCustomer.so
    mkdir -p "$OUT"
    SO="$OUT/libEcnrForCustomer_$ABI.so"
    "$TC/llvm-strip" --strip-unneeded -o "$SO" "$B/libEcnrForCustomer.so"
    # checks: machine, libraries needed (all LLNDK, nothing from the NDK such as libc++_shared.so), exports
    RE="$TC/llvm-readelf"
    # outputs read into variables first: grep -q closing the pipe early would make pipefail fail the check
    HEADER=$("$RE" -h "$SO")
    case "$HEADER" in *"Machine:"*"$MACHINE"*) ;; *) echo "$SO: not $MACHINE" >&2; exit 1 ;; esac
    NEEDED=$("$RE" -d "$SO" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p' | sort | tr '\n' ' ')
    for n in $NEEDED; do
        case "$n" in libc.so|libm.so|libdl.so|liblog.so) ;; *) echo "$SO needs $n" >&2; exit 1 ;; esac
    done
    EXPORTS=$("$RE" --dyn-syms -W "$SO" | awk '$7 != "UND" && ($5 == "GLOBAL" || $5 == "WEAK") && $8 != "" {print $8}' | sort -u | tr '\n' ' ')
    [ "$EXPORTS" = "AUDIO_ECNR_SYM " ] || { echo "$SO exports: $EXPORTS" >&2; exit 1; }
    echo "$SO: $(stat -c %s "$SO") bytes, needs $NEEDED, exports $EXPORTS"
    ;;
*)
    echo "usage: $0 host | android <armeabi-v7a|arm64-v8a> [out dir]" >&2
    exit 2
    ;;
esac
