#!/usr/bin/env bash
# 交叉编译基线版本：在 rvv-cross:2 容器里把 baseline（上游原样）编成 riscv64，
# 探针用 qemu-user 跑，输出与 native 基线逐字段比对。
#
#   ./scripts/cross-baseline.sh                # 默认 -march=rv64gc（无向量，纯基线）
#   MARCH=rv64gcv ./scripts/cross-baseline.sh  # 上游自带 RVV 代码时，看向量路径
#
# 上游是 meson：这里只改"编上游"那一段（meson cross file，见 cmake/meson-cross-riscv64.txt）。
# 纪律：只编 baseline，不编 src，也不开 RVV_KERNELS；性能数字不从这里取。
set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE=${IMAGE:-rvv-cross:2}
MARCH=${MARCH:-rv64gc}
OUT=build/riscv64-b
HARNESS=${HARNESS:-apm_harness}

docker run --rm -v "$PWD":/work -w /work "${IMAGE}" bash -lc "
set -e
rm -rf ${OUT}
mkdir -p ${OUT}

# 1) 编上游到 ${OUT}/prefix（meson + abseil 子项目，交叉文件指定 riscv 工具链）
./cmake/pkg-build.sh baseline /work/${OUT} /work/cmake/meson-cross-riscv64.txt \
  > /tmp/pkg.log 2>&1 || { tail -40 /tmp/pkg.log; exit 1; }

# 2) 编探针（-DPKG_PREFIX 跳过 pkg 目标，直接用上面的前缀）
cmake -S . -B ${OUT}/harness -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE=/work/cmake/toolchain-riscv64-linux.cmake \
  -DCMAKE_C_FLAGS='-march=${MARCH}' \
  -DCMAKE_CXX_FLAGS='-march=${MARCH}' \
  -DPKG_PREFIX=/work/${OUT}/prefix > /tmp/h.log 2>&1 || { tail -30 /tmp/h.log; exit 1; }
cmake --build ${OUT}/harness -j > /tmp/hb.log 2>&1 || { tail -20 /tmp/hb.log; exit 1; }

# 3) 跑（qemu-user + 目标 sysroot）
cd /work && mkdir -p ${OUT}/out
qemu-riscv64 -L /usr/riscv64-linux-gnu ${OUT}/harness/${HARNESS} ${OUT}/out/hash.txt \
  > /dev/null 2>/tmp/run.log || { echo 'qemu 运行失败'; tail -5 /tmp/run.log; exit 1; }
echo '--- riscv64（${MARCH}）---'; cat ${OUT}/out/hash.txt
echo '--- native 基线 ---'; cat build/ab-data/out/01_*/a/hash.txt
"
