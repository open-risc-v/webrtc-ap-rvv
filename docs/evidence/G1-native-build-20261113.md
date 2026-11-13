# webrtc-audio-processing：native 构建 + 探针就位（交叉待跑）

## 已完成
- meson + abseil wrap（`subprojects/abseil-cpp.wrap` → 20240722.0 + wrapdb 补丁）能编出
  `webrtc/modules/audio_processing/libwebrtc-audio-processing-2.a` 并 install 到 `<out>/prefix`
- `cmake/meson-cross-riscv64.txt` 就位（riscv64 gcc/g++ + qemu wrapper）
- `test/pkg_apm.cpp`：48 kHz/10 ms ×200 帧，high-pass filter 单路径，哈希量化 PCM16

## 未完成 / 卡点
1. **上游 examples 在 macOS 链接失败**（与移植无关）：`logging.cc` 引用 CoreFoundation
   `_CFBundleGetIdentifier` / `_CFBundleGetMainBundle` / `_CFPreferencesGetAppBooleanValue` /
   `___CFConstantStringClassReference`，`examples/run-offline` 链接不过。绕法：只 ninja 库目标 +
   `meson install --no-rebuild`。
2. **探针要 absl 头与静态库**：abseil 由 meson subproject 编在 `bld/subprojects/` 下，不 install，
   所以 `pkg_apm.cpp` 现在 `#include "absl/base/config.h"` 找不到。需要在 pkg-build 里把
   subproject 的 `absl/` 头和 `libabsl_*.a` 拷进 prefix，再让 harness 链接。

## 复现
```bash
cd ~/work/webrtc-ap-rvv
./cmake/pkg-build.sh src /tmp/apmpkg   # 能出库
```
