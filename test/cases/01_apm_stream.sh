#!/usr/bin/env bash
# 真实包用例：webrtc APM 处理 200 帧 10ms 单声道音频，输出 PCM 哈希。
set -euo pipefail
: "${STAGE:=run}" "${SIDE:=A}" "${BIN:=build/native}" "${DATA:=build/ab-data}" "${OUT:=build/ab-data/out}"
mkdir -p "$DATA" "$OUT"
case "$STAGE" in
  gen) ;;
  run)
    [ -x "$BIN/apm_harness" ] || { echo "缺少 $BIN/apm_harness" >&2; exit 1; }
    "$BIN/apm_harness" "$OUT/hash.txt" > /dev/null
    grep -q "fnv_pcm=" "$OUT/hash.txt" || { echo "探针未产出" >&2; exit 1; }
    ;;
  *) echo "未知 STAGE=$STAGE" >&2; exit 2 ;;
esac
