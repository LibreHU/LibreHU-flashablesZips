// Copyright (C) 2026 LibreHU
// SPDX-License-Identifier: Apache-2.0
//
// libEcnrForCustomer.so for the Jancar UJC201 (Autochips AC8257): echo cancellation and noise reduction of phone calls
// with WebRTC audio processing (webrtc-audio-processing 2.1: AEC3 or AECM, noise suppression, AGC2, high-pass
// filter), in place of the uVoice library that needs an online licence.
//
// The audio HAL of the vendor (audio.primary.ac8257.so) loads libecnrhelper.so, which dlopen()s
// /vendor/lib[64]/libEcnrForCustomer.so when vendor.audiohal.third_ecnr_lib.enable / persist.audiohal.third_ecnr_lib.enable
// is 1, and looks up the AUDIO_ECNR_SYM object: 8 pointer-sized fields, copied once (64 bytes on arm64), then passed
// by value (disassembly of libecnrhelper.so, atcecnr::SpeechECNRController init / process / deinit and
// DataCombiner::processThread, vendor of the UJC201):
//   [0] name, [1] version: strings, logged when not null
//   [2] must not be null (process and deinit are only called then)
//   [3] called first, with a pointer to the copy; return value ignored
//   [4] init(SYM, mEcnrMode, dataMode, source rate, target rate); return value ignored
//   [5] process(SYM, in, out, inBytes, outBytes*) -> 0 = OK, else logged "ECNR process failed: %d"
//   [6] deinit(SYM)
//   [7] never called
// Input of process: N frames of 4 x int16, [mic left, mic right, ref left, ref right] (ref = what the speakers play,
// the far end of the call), at the target rate (the helper resamples); output: N x int16 mono, *outBytes set to
// N * 2 by the caller, which checks it after the call.
//
// Settings: system properties, read at each init (call start) and again every second during a call, so the LibreHU
// service can change them while a call runs:
//   persist.vendor.librehu.ecnr.aec    0 off, 1 AEC3 (default), 2 AECM (mobile mode, lighter)
//   persist.vendor.librehu.ecnr.ns     0 off, 1 low, 2 moderate (default), 3 high, 4 very high
//   persist.vendor.librehu.ecnr.agc    0 off (default), 1 adaptive digital gain (AGC2)
//   persist.vendor.librehu.ecnr.mic    0 left channel (default), 1 right, 2 average of both
//   persist.vendor.librehu.ecnr.delay  echo path delay hint in ms (default 0; AEC3 finds it alone, AECM needs it)
// Log tag: LibreHU-ECNR (parameters of each call, then statistics every 30 s).

#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstdarg>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include "api/audio/audio_processing.h"
#include "api/scoped_refptr.h"

#ifdef __ANDROID__
#include <android/log.h>
#include <sys/system_properties.h>
#endif

#define ECNR_EXPORT __attribute__((visibility("default")))

namespace {

constexpr const char* kTag = "LibreHU-ECNR";
constexpr const char* kName = "LibreHU WebRTC ECNR";
constexpr const char* kVersion = "1.0 (webrtc-audio-processing 2.1)";

void logf(int level, const char* fmt, ...) __attribute__((format(printf, 2, 3)));
void logf(int level, const char* fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
#ifdef __ANDROID__
    __android_log_vprint(level, kTag, fmt, ap);
#else
    (void)level;
    if (getenv("LIBREHU_ECNR_VERBOSE")) {
        fprintf(stderr, "%s: ", kTag);
        vfprintf(stderr, fmt, ap);
        fputc('\n', stderr);
    }
#endif
    va_end(ap);
}
#ifdef __ANDROID__
#define LOGI(...) logf(ANDROID_LOG_INFO, __VA_ARGS__)
#define LOGW(...) logf(ANDROID_LOG_WARN, __VA_ARGS__)
#else
#define LOGI(...) logf(4, __VA_ARGS__)
#define LOGW(...) logf(5, __VA_ARGS__)
#endif

// Integer property, def when absent or not a number. Host builds (tests): environment, dots replaced by '_'.
int prop_int(const char* name, int def) {
    char v[96] = {0};
#ifdef __ANDROID__
    if (__system_property_get(name, v) <= 0) return def;
#else
    std::string env(name);
    std::replace(env.begin(), env.end(), '.', '_');
    const char* e = getenv(env.c_str());
    if (e == nullptr) return def;
    snprintf(v, sizeof(v), "%s", e);
#endif
    char* end = nullptr;
    long r = strtol(v, &end, 10);
    if (end == v) return def;
    return static_cast<int>(r);
}

struct Settings {
    int aec = 1;
    int ns = 2;
    int agc = 0;
    int mic = 0;
    int delay = 0;
    bool operator==(const Settings& o) const {
        return aec == o.aec && ns == o.ns && agc == o.agc && mic == o.mic && delay == o.delay;
    }
    bool operator!=(const Settings& o) const { return !(*this == o); }
};

Settings read_settings() {
    Settings s;
    s.aec = std::clamp(prop_int("persist.vendor.librehu.ecnr.aec", 1), 0, 2);
    s.ns = std::clamp(prop_int("persist.vendor.librehu.ecnr.ns", 2), 0, 4);
    s.agc = std::clamp(prop_int("persist.vendor.librehu.ecnr.agc", 0), 0, 1);
    s.mic = std::clamp(prop_int("persist.vendor.librehu.ecnr.mic", 0), 0, 2);
    s.delay = std::clamp(prop_int("persist.vendor.librehu.ecnr.delay", 0), 0, 500);
    return s;
}

webrtc::AudioProcessing::Config apm_config(const Settings& s) {
    webrtc::AudioProcessing::Config c;
    c.high_pass_filter.enabled = true;  // road and engine rumble, and needed by AEC3
    c.echo_canceller.enabled = s.aec != 0;
    c.echo_canceller.mobile_mode = s.aec == 2;
    c.noise_suppression.enabled = s.ns != 0;
    switch (s.ns) {
        case 1: c.noise_suppression.level = webrtc::AudioProcessing::Config::NoiseSuppression::kLow; break;
        case 3: c.noise_suppression.level = webrtc::AudioProcessing::Config::NoiseSuppression::kHigh; break;
        case 4: c.noise_suppression.level = webrtc::AudioProcessing::Config::NoiseSuppression::kVeryHigh; break;
        default: c.noise_suppression.level = webrtc::AudioProcessing::Config::NoiseSuppression::kModerate; break;
    }
    // no analog volume to drive here: digital adaptive gain only
    c.gain_controller1.enabled = false;
    c.gain_controller2.enabled = s.agc != 0;
    c.gain_controller2.adaptive_digital.enabled = s.agc != 0;
    return c;
}

bool valid_rate(int r) {
    return r == 8000 || r == 11025 || r == 16000 || r == 22050 || r == 24000 || r == 32000 || r == 44100 || r == 48000;
}

double rms_dbfs(double sum_sq, uint64_t n) {
    if (n == 0 || sum_sq <= 0) return -120.0;
    return 10.0 * std::log10(sum_sq / static_cast<double>(n) / (32768.0 * 32768.0));
}

// One call at a time (the HAL opens one voice path); state shared by init / process / deinit, which get the
// AUDIO_ECNR_SYM object by value and so cannot keep anything in it.
struct Engine {
    std::mutex lock;
    rtc::scoped_refptr<webrtc::AudioProcessing> apm;
    Settings settings;
    int rate = 16000;
    size_t block = 160;           // frames of 10 ms
    std::vector<int16_t> cap;     // mono mic samples waiting for a whole block
    std::vector<int16_t> ref;     // mono reference samples, same count as cap
    std::vector<int16_t> out;     // processed samples waiting to be returned (starts with one block of silence)
    std::vector<int16_t> cap_blk, ref_blk;
    uint64_t blocks = 0;
    uint64_t calls = 0;
    bool warned_size = false;
    double in_sq = 0, out_sq = 0, ref_sq = 0;
    uint64_t stat_n = 0;
} g;

std::atomic<int> g_priv{1};

void reset_buffers_locked() {
    g.cap.clear();
    g.ref.clear();
    g.out.assign(g.block, 0);  // 10 ms latency: process always has N samples to return
    g.cap_blk.assign(g.block, 0);
    g.ref_blk.assign(g.block, 0);
    g.blocks = 0;
    g.calls = 0;
    g.warned_size = false;
    g.in_sq = g.out_sq = g.ref_sq = 0;
    g.stat_n = 0;
}

void log_settings(const char* what, const Settings& s) {
    static const char* aec[] = {"off", "AEC3", "AECM"};
    static const char* ns[] = {"off", "low", "moderate", "high", "very high"};
    static const char* mic[] = {"left", "right", "average"};
    LOGI("%s: echo canceller %s, noise suppression %s, AGC2 %s, mic %s, delay hint %d ms", what, aec[s.aec], ns[s.ns],
         s.agc ? "on" : "off", mic[s.mic], s.delay);
}

void log_stats_locked() {
    std::string erle = "n/a", delay = "n/a";
    if (g.apm) {
        webrtc::AudioProcessingStats st = g.apm->GetStatistics();
        char b[32];
        if (st.echo_return_loss_enhancement) {
            snprintf(b, sizeof(b), "%.1f dB", *st.echo_return_loss_enhancement);
            erle = b;
        }
        if (st.delay_ms) {
            snprintf(b, sizeof(b), "%d ms", *st.delay_ms);
            delay = b;
        }
    }
    LOGI("stats: %llu calls, mic %.1f dBFS, ref %.1f dBFS, out %.1f dBFS, ERLE %s, delay %s",
         static_cast<unsigned long long>(g.calls), rms_dbfs(g.in_sq, g.stat_n), rms_dbfs(g.ref_sq, g.stat_n),
         rms_dbfs(g.out_sq, g.stat_n), erle.c_str(), delay.c_str());
    g.in_sq = g.out_sq = g.ref_sq = 0;
    g.stat_n = 0;
}

// Runs WebRTC on every whole block of cap / ref, appends the result to out.
void run_blocks_locked() {
    size_t used = 0;
    const webrtc::StreamConfig sc(g.rate, 1);
    while (g.cap.size() - used >= g.block) {
        std::copy_n(g.cap.begin() + used, g.block, g.cap_blk.begin());
        std::copy_n(g.ref.begin() + used, g.block, g.ref_blk.begin());
        used += g.block;
        if (g.apm) {
            int err = g.apm->ProcessReverseStream(g.ref_blk.data(), sc, sc, g.ref_blk.data());
            g.apm->set_stream_delay_ms(g.settings.delay);
            if (err == 0) err = g.apm->ProcessStream(g.cap_blk.data(), sc, sc, g.cap_blk.data());
            if (err != 0) {
                // keeps the (partly) unprocessed block rather than silence
                if (!g.warned_size) LOGW("WebRTC refused a block (rate %d, error %d)", g.rate, err);
                g.warned_size = true;
            }
        }
        g.out.insert(g.out.end(), g.cap_blk.begin(), g.cap_blk.end());
        g.blocks++;
        // settings again every second (100 blocks of 10 ms), applied without stopping the call
        if (g.blocks % 100 == 0) {
            Settings s = read_settings();
            if (s != g.settings) {
                g.settings = s;
                if (g.apm) g.apm->ApplyConfig(apm_config(s));
                log_settings("settings changed", s);
            }
        }
        if (g.blocks % 3000 == 0) log_stats_locked();
    }
    if (used) {
        g.cap.erase(g.cap.begin(), g.cap.begin() + used);
        g.ref.erase(g.ref.begin(), g.ref.begin() + used);
    }
}

}  // namespace

extern "C" {

// Layout of the object libecnrhelper.so reads (fields of pointer size, functions taking it by value).
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

static int ecnr_prepare() {
    LOGI("%s %s: prepare", kName, kVersion);
    return 0;
}

static int ecnr_init(AudioEcnrSym, int a, int b, int c, int d) {
    std::lock_guard<std::mutex> l(g.lock);
    // a = mEcnrMode, b = dataMode, c = source rate, d = target rate (the rate of the data given to process)
    int rate = valid_rate(d) ? d : valid_rate(c) ? c : 16000;
    g.settings = read_settings();
    g.rate = rate;
    g.block = static_cast<size_t>(rate / 100);
    reset_buffers_locked();
    g.apm = webrtc::AudioProcessingBuilder().SetConfig(apm_config(g.settings)).Create();
    if (!g.apm) {
        LOGW("init(%d, %d, %d, %d): WebRTC not created, microphone passed through", a, b, c, d);
    } else {
        g.apm->Initialize();
        LOGI("init(%d, %d, %d, %d): %s %s, %d Hz, blocks of %zu frames", a, b, c, d, kName, kVersion, rate, g.block);
    }
    log_settings("settings", g.settings);
    return 0;
}

static int ecnr_process(AudioEcnrSym, void* in, void* out, unsigned int in_bytes, unsigned int* out_bytes) {
    if (in == nullptr || out == nullptr) return -1;
    std::lock_guard<std::mutex> l(g.lock);
    // N frames: from the output size the caller expects (N * 2 bytes), checked against the input (N * 4 * 2 bytes)
    size_t n = (out_bytes && *out_bytes >= 2) ? *out_bytes / 2 : in_bytes / 8;
    if (static_cast<size_t>(in_bytes) / 8 < n) {
        if (!g.warned_size) LOGW("process: %u input bytes for %zu output frames, using %u", in_bytes, n, in_bytes / 8);
        g.warned_size = true;
        n = in_bytes / 8;
    }
    const int16_t* src = static_cast<const int16_t*>(in);
    int16_t* dst = static_cast<int16_t*>(out);
    if (g.calls == 0) LOGI("first process: %u input bytes, %zu frames, %d Hz", in_bytes, n, g.rate);
    g.calls++;
    const int mic = g.settings.mic;
    for (size_t i = 0; i < n; i++) {
        const int16_t* f = src + 4 * i;
        int m = mic == 0 ? f[0] : mic == 1 ? f[1] : (f[0] + f[1]) / 2;
        int r = (f[2] + f[3]) / 2;
        g.cap.push_back(static_cast<int16_t>(m));
        g.ref.push_back(static_cast<int16_t>(r));
        g.in_sq += static_cast<double>(m) * m;
        g.ref_sq += static_cast<double>(r) * r;
    }
    g.stat_n += n;
    run_blocks_locked();
    // out always holds at least n samples (one block of silence ahead); zeros only if something went wrong
    size_t have = std::min(n, g.out.size());
    std::copy_n(g.out.begin(), have, dst);
    if (have < n) std::fill(dst + have, dst + n, 0);
    for (size_t i = 0; i < have; i++) g.out_sq += static_cast<double>(dst[i]) * dst[i];
    g.out.erase(g.out.begin(), g.out.begin() + have);
    if (out_bytes) *out_bytes = static_cast<unsigned int>(n * 2);
    return 0;
}

static int ecnr_deinit(AudioEcnrSym) {
    std::lock_guard<std::mutex> l(g.lock);
    if (g.calls) log_stats_locked();
    LOGI("deinit after %llu blocks", static_cast<unsigned long long>(g.blocks));
    g.apm = nullptr;
    reset_buffers_locked();
    return 0;
}

static int ecnr_reserved() { return 0; }

ECNR_EXPORT AudioEcnrSym AUDIO_ECNR_SYM = {
    kName, kVersion, &g_priv, ecnr_prepare, ecnr_init, ecnr_process, ecnr_deinit, ecnr_reserved,
};

}  // extern "C"
