#!/usr/bin/env bash
# 构建上游 webrtc-audio-processing（meson）→ <out>/prefix。
# abseil 走 subprojects/abseil-cpp.wrap（meson 自动下载 20240722.0 + wrapdb 补丁）。
# NEON / inline SSE 全关：riscv 上没有这两类指令，两侧同口径。
set -euo pipefail
SRC=$1
OUT=$2
CROSS=${3:-}
ARGS=(-Ddefault_library=static -Dneon=disabled -Dinline-sse=false --prefix="$OUT/prefix")
if [ -n "$CROSS" ]; then
  ARGS+=(--cross-file "$CROSS")
fi
mkdir -p "$OUT"; rm -rf "$OUT/bld"
meson setup "$OUT/bld" "$SRC" "${ARGS[@]}" > "$OUT/meson-setup.log" 2>&1 || { tail -30 "$OUT/meson-setup.log"; exit 1; }
# 只编库：上游 examples/run-offline 在 macOS 上缺 CoreFoundation 链接（上游 bug），
# 与移植无关，跳过它。
ninja -C "$OUT/bld" webrtc/modules/audio_processing/libwebrtc-audio-processing-2.a \
  > "$OUT/ninja.log" 2>&1 || { tail -30 "$OUT/ninja.log"; exit 1; }
meson install --no-rebuild -C "$OUT/bld" > "$OUT/install.log" 2>&1 || { tail -20 "$OUT/install.log"; exit 1; }
