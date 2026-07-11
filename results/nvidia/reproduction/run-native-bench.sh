#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=/home/frosty40/treebeard-nvidia-rc3-0424f677f
BUILD="$ROOT/build-candidate"
MODEL=/home/frosty40/models/treebeard-qwen3.6-35b-a3b-q5/Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf
OUT="${TREEBEARD_NVIDIA_OUT:-$ROOT/evidence/native-bench-final}"
MODEL_SHA256=25233af7642e3a91bd52cc4aeefdbd4a117479088e06cf1aea5b6bedb443c506

mkdir -p "$OUT"
test -x "$BUILD/bin/llama-bench"
printf '%s  %s\n' "$MODEL_SHA256" "$MODEL" | sha256sum --check --status

date --iso-8601=seconds > "$OUT/start-date.txt"
nvidia-smi -q > "$OUT/nvidia-smi-before.txt"
"$BUILD/bin/llama-bench" --list-devices > "$OUT/devices.txt" 2>&1

common=(
    -m "$MODEL"
    -ngl 99
    -ncmoe 0
    -fa on
    -b 8192
    -ub 1024
    -t 15
    -r 5
    --progress
    -o json
)

"$BUILD/bin/llama-bench" "${common[@]}" -p 4096 -n 0 \
    > "$OUT/pp4096.json" 2> "$OUT/pp4096.log"
"$BUILD/bin/llama-bench" "${common[@]}" -p 0 -n 128 \
    > "$OUT/tg128.json" 2> "$OUT/tg128.log"

jq -e 'length == 1 and .[0].n_prompt == 4096 and .[0].n_gen == 0 and (.[] | .samples_ns | length == 5)' \
    "$OUT/pp4096.json" >/dev/null
jq -e 'length == 1 and .[0].n_prompt == 0 and .[0].n_gen == 128 and (.[] | .samples_ns | length == 5)' \
    "$OUT/tg128.json" >/dev/null

nvidia-smi -q > "$OUT/nvidia-smi-after.txt"
date --iso-8601=seconds > "$OUT/completed-date.txt"
(
    cd "$ROOT"
    find evidence/native-bench-final -type f ! -name SHA256SUMS -print0 \
        | sort -z \
        | xargs -0 sha256sum
) > "$OUT/SHA256SUMS"

printf 'TREEBEARD_NVIDIA_NATIVE_BENCH_OK\n'
