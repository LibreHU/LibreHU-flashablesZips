# Copyright (C) 2026 LibreHU
# SPDX-License-Identifier: Apache-2.0
#
# libEcnrForCustomer.so (WebRTC ECNR, see ecnr_webrtc.cpp) and its host test. WebRTC audio processing and abseil are
# subprojects (wrap files), built as static libraries: build.sh passes -Ddefault_library=static.
project('librehu-ecnr-webrtc', 'cpp',
  version: '1.0',
  meson_version: '>= 0.63',
  default_options: ['cpp_std=c++17', 'buildtype=release', 'b_ndebug=true', 'warning_level=1'])

apm = dependency('webrtc-audio-processing-2', default_options: ['default_library=static'])
cpp = meson.get_compiler('cpp')
deps = [apm]
if host_machine.system() == 'android'
  deps += cpp.find_library('log')
endif

map = meson.current_source_dir() / 'exports.map'
lib = shared_library('EcnrForCustomer', 'ecnr_webrtc.cpp',
  dependencies: deps,
  gnu_symbol_visibility: 'hidden',
  cpp_args: ['-DWEBRTC_POSIX'],
  link_args: ['-Wl,--version-script=' + map, '-Wl,--exclude-libs,ALL', '-Wl,--gc-sections', '-Wl,-z,defs',
              '-Wl,--no-undefined'],
  link_depends: map,
  install: false)

if not meson.is_cross_build()
  test_exe = executable('ecnr_test', 'test/ecnr_test.cpp',
    dependencies: cpp.find_library('dl', required: false))
  test('ecnr', test_exe, args: [lib.full_path()], depends: lib, timeout: 300)
endif
