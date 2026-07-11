#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=${TREEBEARD_NVIDIA_ROOT:-/home/frosty40/treebeard-nvidia-rc3-0424f677f}
BUILD=${TREEBEARD_NVIDIA_BUILD:-$ROOT/build-candidate}
OUT=${TREEBEARD_NVIDIA_OUT:-$ROOT/evidence/attribution-q8-final}

mkdir -p "$OUT"
nvidia-smi -q > "$OUT/nvidia-smi-before.txt"

mat='^type_a=q8_0,type_b=f32,m=512,n=12,k=256,bs=\[1,1\],nr=\[1,1\],per=\[0,1,2,3\],k_v=0,o=1$'
mmid='^type_a=q8_0,type_b=f32,n_mats=256,n_used=8,b=0,m=2048,n=12,k=512$'

run_mode() {
    local mode="$1"
    local wave="$2"
    local log="$OUT/wave-$wave-$mode.log"
    local telemetry="$OUT/wave-$wave-$mode-telemetry.csv"
    local -a mode_env=()

    if [[ "$mode" == fallback ]]; then
        mode_env+=(GGML_CUDA_DISABLE_MMVQ_12COL=1)
    fi

    nvidia-smi --query-gpu=utilization.gpu,power.draw,clocks.gr,pstate \
        --format=csv,noheader > "$telemetry"
    env "${mode_env[@]}" "$BUILD/bin/test-backend-ops" perf \
        -b CUDA0 -o MUL_MAT -p "$mat" > "$log" 2>&1
    env GGML_TEST_MUL_MAT_ID_SEED=42 "${mode_env[@]}" \
        "$BUILD/bin/test-backend-ops" perf \
        -b CUDA0 -o MUL_MAT_ID -p "$mmid" >> "$log" 2>&1
    nvidia-smi --query-gpu=utilization.gpu,power.draw,clocks.gr,pstate \
        --format=csv,noheader >> "$telemetry"
    [[ "$(grep -c 'us/run' "$log")" == 2 ]]
}

for wave in 1 2 3 4 5 6 7; do
    if (( wave % 2 )); then
        run_mode fallback "$wave"
        run_mode candidate "$wave"
    else
        run_mode candidate "$wave"
        run_mode fallback "$wave"
    fi
done

nvidia-smi -q > "$OUT/nvidia-smi-after.txt"
sha256sum "$OUT"/wave-*.log "$OUT"/wave-*-telemetry.csv > "$OUT/attribution.sha256"
printf 'TREEBEARD_CUDA_Q8_ATTRIBUTION_OK\n'
