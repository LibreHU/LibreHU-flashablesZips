// Copyright (C) 2026 LibreHU
// SPDX-License-Identifier: Apache-2.0
//
// Host test of libEcnrForCustomer.so, called the way libecnrhelper.so of the UJC201 calls it: dlopen, dlsym of
// AUDIO_ECNR_SYM, a copy of the object passed by value to init / process / deinit, input of 4 x int16 per frame
// [mic left, mic right, ref left, ref right], mono output, *outBytes = N * 2, N not a multiple of 10 ms.
//   - echo only (far end playing, room echo in the mic): the echo must drop by 20 dB or more (AEC3 + NS);
//   - near-end talk only: kept (less than 10 dB lower);
//   - steady noise only, echo canceller off, noise suppression very high: 6 dB lower or more;
//   - 8, 32 and 48 kHz: sizes right, no crash.
//   ecnr_test <path of libEcnrForCustomer.so>

#include <dlfcn.h>

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <vector>

struct AudioEcnrSym {
    const char* name;
    const char* version;
    void* priv;
    int (*prepare)();
    int (*init)(AudioEcnrSym sym, int a, int b, int c, int rate);
    int (*process)(AudioEcnrSym sym, void* in, void* out, unsigned int in_bytes, unsigned int* out_bytes);
    int (*deinit)(AudioEcnrSym sym);
    int (*reserved)();
};

namespace {

uint32_t seed = 12345;
double noise() {  // uniform in [-1, 1)
    seed = seed * 1664525u + 1013904223u;
    return (seed >> 8) / 8388608.0 - 1.0;
}

// speech-like: low-passed noise with a syllable envelope
struct Talker {
    double lp = 0, phase = 0, rate_hz, level;
    Talker(double r, double l) : rate_hz(r), level(l) {}
    double next(int fs) {
        lp = 0.85 * lp + 0.15 * noise();
        phase += rate_hz / fs;
        double env = 0.5 - 0.5 * std::cos(2 * M_PI * phase);
        return level * 3.0 * lp * env * env;
    }
};

int16_t clip(double v) {
    v *= 32767.0;
    return static_cast<int16_t>(v > 32767 ? 32767 : v < -32768 ? -32768 : v);
}

double db(double a, double b) { return 10.0 * std::log10((a + 1e-9) / (b + 1e-9)); }

int failures = 0;
void check(bool ok, const char* what) {
    printf("%s %s\n", ok ? "PASS" : "FAIL", what);
    if (!ok) failures++;
}

}  // namespace

int main(int argc, char** argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s libEcnrForCustomer.so\n", argv[0]);
        return 2;
    }
    void* h = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!h) {
        fprintf(stderr, "dlopen: %s\n", dlerror());
        return 1;
    }
    auto* p = static_cast<AudioEcnrSym*>(dlsym(h, "AUDIO_ECNR_SYM"));
    if (!p) {
        fprintf(stderr, "AUDIO_ECNR_SYM not found\n");
        return 1;
    }
    AudioEcnrSym sym = *p;
    printf("%s %s\n", sym.name, sym.version);
    check(sym.priv != nullptr && sym.prepare && sym.init && sym.process && sym.deinit, "fields of AUDIO_ECNR_SYM set");

    // --- echo, then near-end talk, 16 kHz, 256 frames per call
    {
        const int fs = 16000, n = 256;
        unsetenv("persist_vendor_librehu_ecnr_aec");
        unsetenv("persist_vendor_librehu_ecnr_ns");
        check(sym.prepare() == 0, "prepare");
        check(sym.init(sym, 1, 1, fs, fs) == 0, "init 16 kHz");
        // room: direct path 30 ms, then 100 ms of decaying reflections
        std::vector<double> ir(fs * 130 / 1000, 0.0);
        ir[fs * 30 / 1000] = 0.4;
        for (size_t i = fs * 30 / 1000 + 1; i < ir.size(); i++)
            ir[i] = 0.15 * noise() * std::exp(-static_cast<double>(i - fs * 30 / 1000) / (fs * 0.025));
        std::vector<double> hist(ir.size(), 0.0);
        size_t hp = 0;
        Talker far(3.7, 0.1), near(4.3, 0.1);
        std::vector<int16_t> in(4 * n), out(n);
        double mic_a = 0, out_a = 0, mic_b = 0, out_b = 0;
        const int total = fs * 14;
        bool sizes_ok = true;
        for (int t = 0; t < total; t += n) {
            for (int i = 0; i < n; i++) {
                double s = t + i;
                double f = s < fs * 10 ? far.next(fs) : 0.0;
                hist[hp] = f;
                double e = 0;
                for (size_t k = 0; k < ir.size(); k++) e += ir[k] * hist[(hp + hist.size() - k) % hist.size()];
                hp = (hp + 1) % hist.size();
                double nr = s >= fs * 10 ? near.next(fs) : 0.0;
                double m = e + nr + 0.001 * noise();
                in[4 * i] = in[4 * i + 1] = clip(m);
                in[4 * i + 2] = in[4 * i + 3] = clip(f);
            }
            unsigned int ob = n * 2;
            int r = sym.process(sym, in.data(), out.data(), static_cast<unsigned int>(in.size() * 2), &ob);
            if (r != 0 || ob != n * 2u) sizes_ok = false;
            for (int i = 0; i < n; i++) {
                double s = t + i;
                double mi = in[4 * i] * static_cast<double>(in[4 * i]), o = out[i] * static_cast<double>(out[i]);
                if (s >= fs * 6 && s < fs * 10) { mic_a += mi; out_a += o; }
                if (s >= fs * 11 && s < fs * 14) { mic_b += mi; out_b += o; }
            }
        }
        sym.deinit(sym);
        check(sizes_ok, "process returns 0 and N * 2 bytes");
        double erle = db(mic_a, out_a), keep = db(mic_b, out_b);
        printf("     echo reduced by %.1f dB, near-end talk lowered by %.1f dB\n", erle, keep);
        check(erle >= 20.0, "echo only: 20 dB lower or more");
        check(keep < 10.0, "near-end talk kept (less than 10 dB lower)");
    }

    // --- steady noise, echo canceller off, noise suppression very high
    {
        const int fs = 16000, n = 200;
        setenv("persist_vendor_librehu_ecnr_aec", "0", 1);
        setenv("persist_vendor_librehu_ecnr_ns", "4", 1);
        sym.init(sym, 1, 1, fs, fs);
        std::vector<int16_t> in(4 * n), out(n);
        double a = 0, b = 0;
        for (int t = 0; t < fs * 6; t += n) {
            for (int i = 0; i < n; i++) {
                in[4 * i] = in[4 * i + 1] = clip(0.03 * noise());
                in[4 * i + 2] = in[4 * i + 3] = 0;
            }
            unsigned int ob = n * 2;
            sym.process(sym, in.data(), out.data(), static_cast<unsigned int>(in.size() * 2), &ob);
            if (t >= fs * 3)
                for (int i = 0; i < n; i++) {
                    a += in[4 * i] * static_cast<double>(in[4 * i]);
                    b += out[i] * static_cast<double>(out[i]);
                }
        }
        sym.deinit(sym);
        printf("     steady noise lowered by %.1f dB\n", db(a, b));
        check(db(a, b) >= 6.0, "steady noise: 6 dB lower or more");
        unsetenv("persist_vendor_librehu_ecnr_aec");
        unsetenv("persist_vendor_librehu_ecnr_ns");
    }

    // --- other rates and odd sizes
    for (int fs : {8000, 32000, 48000}) {
        sym.init(sym, 1, 1, fs, fs);
        bool ok = true;
        for (int n : {1, 37, 160, 480, 1023}) {
            std::vector<int16_t> in(4 * n, 100), out(n, 0);
            unsigned int ob = n * 2;
            if (sym.process(sym, in.data(), out.data(), static_cast<unsigned int>(in.size() * 2), &ob) != 0 ||
                ob != n * 2u)
                ok = false;
        }
        sym.deinit(sym);
        char what[64];
        snprintf(what, sizeof(what), "%d Hz: sizes right", fs);
        check(ok, what);
    }

    printf("%s\n", failures ? "FAILED" : "all tests passed");
    return failures ? 1 : 0;
}
