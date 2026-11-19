#!/usr/bin/env bash
# 构建上游 webrtc-audio-processing（meson）→ <out>/prefix。
# abseil 走 subprojects/abseil-cpp.wrap（meson 自动下载/解包 20240722.0 + wrapdb 补丁）。
# NEON / inline SSE 全关：riscv 上没有这两类指令，两侧同口径。
#
# 全部在 Linux 容器里编译（本机 macOS 不再参与），因此 examples 也能正常链接。
set -euo pipefail
SRC=$1
OUT=$2
MARCH=${3:-rv64gcv}
KERN=${4:-0}
if [ "$KERN" = "1" ]; then export CFLAGS="${CFLAGS:-} -march=${MARCH} -DRVV_KERNELS=1"; export CXXFLAGS="${CXXFLAGS:-} -march=${MARCH} -DRVV_KERNELS=1"; fi
CROSS=${3:-}
if [ -n "$CROSS" ] && [ ! -f "$CROSS" ]; then CROSS=""; fi
ARGS=(-Ddefault_library=static -Dneon=disabled -Dinline-sse=false --prefix="$OUT/prefix")
if [ -n "$CROSS" ]; then
  ARGS+=(--cross-file "$CROSS")
fi
mkdir -p "$OUT"
rm -rf "$OUT/bld"
meson setup "$OUT/bld" "$SRC" "${ARGS[@]}" > "$OUT/meson-setup.log" 2>&1 || { tail -30 "$OUT/meson-setup.log"; exit 1; }
# 全量编（含 abseil 子项目与 examples）。若 examples 编不过（历史上 macOS 缺 CoreFoundation），
# 退化成只编库 —— 库本身和移植相关，examples 不相关。
ninja -C "$OUT/bld" > "$OUT/ninja.log" 2>&1 || {
  echo "  全量编译失败，退化只编库（详见 $OUT/ninja.log）"
  ninja -C "$OUT/bld" webrtc/modules/audio_processing/libwebrtc-audio-processing-2.a \
    >> "$OUT/ninja.log" 2>&1 || { tail -30 "$OUT/ninja.log"; exit 1; }
}
meson install --no-rebuild -C "$OUT/bld" > "$OUT/install.log" 2>&1 || { tail -20 "$OUT/install.log"; exit 1; }

# 1) 把 multiarch 子目录（prefix/lib/<tuple>）里的库摊平到 prefix/lib
mkdir -p "$OUT/prefix/lib"
for d in "$OUT/prefix/lib"/*/; do
  [ -d "$d" ] || continue
  cp -a "$d". "$OUT/prefix/lib/" 2>/dev/null || true
done

# 2) 探针要链 absl，而 meson 产出的是 **thin archive**（成员按相对路径引用，
#    换个目录就失效，`ar x` 也不支持 thin），所以直接从 .o 目标目录重新打包成一个归档。
#    单个归档有符号索引，成员顺序无关。
ABSL_DIR=$(ls -d "$OUT/bld/subprojects/abseil-cpp-"* 2>/dev/null | head -1 || true)
W_DIR="$OUT/bld/webrtc/modules/audio_processing"
if [ -n "${ABSL_DIR}" ] && [ -d "${W_DIR}" ]; then
  rm -f "$OUT/prefix/lib/libwebrtc-ap-full.a" "$OUT/objs.txt"
  # 上游不止一个静态库（APM 之外还有 isac/rdft 等），把所有 *.a.p 目录里的成员都收进来
  find "$OUT/bld" -path "*.a.p/*" -name "*.o" > "$OUT/objs.txt"
  ar rcs "$OUT/prefix/lib/libwebrtc-ap-full.a" $(cat "$OUT/objs.txt")
  echo "  合并归档: libwebrtc-ap-full.a（$(ar t "$OUT/prefix/lib/libwebrtc-ap-full.a" | wc -l | tr -d ' ') 个成员）"
else
  echo "警告：找不到 abseil/webrtc 目标目录，探针可能链接失败" >&2
fi
