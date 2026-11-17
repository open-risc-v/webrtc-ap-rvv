// webrtc-audio-processing A/B 探针：48 kHz 单声道 10 ms 帧 ×200，
// 开 high-pass filter（最简单的确定性路径），哈希输出 PCM16。
// 注：APM 内部是 float，跨编译器可能存在末位差；判据先取"量化后逐字节一致"。
#include <stdint.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <memory>

#include "api/audio/audio_processing.h"

#define FS 48000
#define FB (FS / 100)   /* 10 ms */
#define NFRAMES 200

int main(int argc, char **argv)
{
    const char *outp = argc > 1 ? argv[1] : NULL;

    rtc::scoped_refptr<webrtc::AudioProcessing> apm =
        webrtc::AudioProcessingBuilder().Create();
    if (!apm) { fprintf(stderr, "APM 创建失败\n"); return 2; }

    webrtc::AudioProcessing::Config cfg;
    cfg.high_pass_filter.enabled = true;
    cfg.echo_canceller.enabled = false;
    cfg.noise_suppression.enabled = false;
    cfg.gain_controller1.enabled = false;
    cfg.gain_controller2.enabled = false;
    apm->ApplyConfig(cfg);

    float *buf = (float *)malloc(sizeof(float) * FB);
    if (!buf) return 3;
    float *chans[1] = {buf};

    uint64_t hpcm = 1469598103934665603ULL;
    uint64_t hq8 = 1469598103934665603ULL;   /* 量化到 8bit 的哈希：浮点末位差异不该被它抓到 */
    double energy = 0.0;
    unsigned int s = 0x2468aceu;

    for (int f = 0; f < NFRAMES; f++) {
        for (int i = 0; i < FB; i++) {
            s = s * 1103515245u + 12345u;
            float noise = ((float)((s >> 16) & 0xffff) / 65535.0f - 0.5f) * 0.05f;
            double t = (double)(f * FB + i) / FS;
            double v = 0.4 * sin(2 * 3.14159265358979 * 300.0 * t)
                     + 0.2 * sin(2 * 3.14159265358979 * 1200.0 * t);
            buf[i] = (float)(v + noise);
        }
        webrtc::StreamConfig sc(FS, 1);
        if (apm->ProcessStream(chans, sc, sc, chans) != 0) {
            fprintf(stderr, "ProcessStream 失败 f=%d\n", f); return 4;
        }
        for (int i = 0; i < FB; i++) {
            double v = buf[i];
            int iv = (int)(v * 32768.0);
            if (iv > 32767) iv = 32767;
            if (iv < -32768) iv = -32768;
            hpcm ^= (uint64_t)(uint16_t)iv;
            hpcm *= 1099511628211ULL;
            hq8 ^= (uint64_t)(uint8_t)((iv + 128) >> 8);
            hq8 *= 1099511628211ULL;
            energy += v * v;
        }
    }

    char line[256];
    snprintf(line, sizeof line, "frames=%d pcm=%d fnv_pcm=%016llx fnv_q8=%016llx energy=%.6f\n",
             NFRAMES, NFRAMES * FB, (unsigned long long)hpcm, (unsigned long long)hq8, energy);
    if (outp) { FILE *fp = fopen(outp, "wb"); if (fp) { fwrite(line, 1, strlen(line), fp); fclose(fp); } }
    fputs(line, stdout);
    free(buf);
    return 0;
}
