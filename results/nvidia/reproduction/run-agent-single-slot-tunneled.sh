#!/usr/bin/env bash
set -Eeuo pipefail

REMOTE=dgx-spark
REMOTE_ROOT=/home/frosty40/treebeard-nvidia-rc3-0424f677f
REMOTE_BUILD="$REMOTE_ROOT/build-candidate"
REMOTE_MODEL=/home/frosty40/models/treebeard-qwen3.6-35b-a3b-q5/Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf
REMOTE_OUT="$REMOTE_ROOT/evidence/agent-single-slot-final"
LOCAL_ROOT=/home/frosty40/turbo/results/treebeard-0.1.0-rc.3/20260711-release/nvidia
OUT="${TREEBEARD_NVIDIA_AGENT_OUT:-$LOCAL_ROOT/agent/single-slot-quality-seed42}"
TOOL_ROOT=/tmp/tool-eval-bench
TOOL_BIN="$TOOL_ROOT/.venv/bin/tool-eval-bench"
MODEL_ALIAS=treebeard-0.1.0-rc.3-Qwen3.6-35B-A3B-Q5-cuda-c262144-np1
MODEL_SHA256=25233af7642e3a91bd52cc4aeefdbd4a117479088e06cf1aea5b6bedb443c506
SERVICE=treebeard-nvidia-quality-server.service
REMOTE_PORT=18098
LOCAL_PORT=8101
TUNNEL_PID=
START_DATE=

mkdir -p "$OUT"/{maintenance,gpu-health,runs}
exec > >(tee -a "$OUT/guard.log") 2>&1

phase() {
    printf '\n[%s] PHASE %s\n' "$(date --iso-8601=seconds)" "$1"
}

cleanup() {
    local rc="${1:-0}"
    trap - EXIT INT TERM HUP
    set +e
    phase "stop NVIDIA candidate and collect evidence"
    if [[ -n "${TUNNEL_PID:-}" ]] && kill -0 "$TUNNEL_PID" 2>/dev/null; then
        kill "$TUNNEL_PID" 2>/dev/null
        wait "$TUNNEL_PID" 2>/dev/null
    fi
    ssh "$REMOTE" "systemctl --user stop '$SERVICE' 2>/dev/null || true"
    ssh "$REMOTE" "journalctl --user-unit '$SERVICE' --no-pager" \
        > "$OUT/maintenance/server-journal.log" 2>&1
    ssh "$REMOTE" "nvidia-smi -q" > "$OUT/gpu-health/nvidia-smi-after.txt" 2>&1
    if [[ -n "${START_DATE:-}" ]]; then
        ssh "$REMOTE" "journalctl -k --since '$START_DATE' --no-pager" \
            > "$OUT/gpu-health/kernel-journal.log" 2>&1 || true
        if rg -n -i '(NVRM: Xid|gpu.*(fault|reset|hang)|out of memory|oom-kill)' \
            "$OUT/gpu-health/kernel-journal.log" \
            > "$OUT/gpu-health/fault-signatures.txt"; then
            printf 'NVIDIA_FAULT_SIGNATURE_FOUND\n' >&2
            rc=1
        else
            printf 'no matching NVIDIA Xid, fault, reset, hang, or OOM signatures\n' \
                > "$OUT/gpu-health/fault-signatures.txt"
        fi
    fi
    date --iso-8601=seconds > "$OUT/completed-date.txt"
    if (( rc == 0 )) && [[ -f "$OUT/result.json" ]]; then
        touch "$OUT/SUCCESS"
    fi
    exit "$rc"
}

trap 'cleanup $?' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

phase "preflight"
test ! -e "$OUT/result.json"
test -x "$TOOL_BIN"
test "$(git -C "$TOOL_ROOT" rev-parse HEAD)" = 8b3259be7411fe27c7610d0de64ae1d3b622b9ef
test -z "$(git -C "$TOOL_ROOT" status --short)"
test "$($TOOL_BIN --version)" = "tool-eval-bench 2.1.0"
if ss -ltn "( sport = :$LOCAL_PORT )" | grep -q LISTEN; then
    printf 'LOCAL_PORT_BUSY=%s\n' "$LOCAL_PORT" >&2
    exit 1
fi
ssh "$REMOTE" "test -x '$REMOTE_BUILD/bin/llama-server'; test -f '$REMOTE_MODEL'; printf '%s  %s\n' '$MODEL_SHA256' '$REMOTE_MODEL' | sha256sum --check --status; ! systemctl --user is-active --quiet '$SERVICE'"
START_DATE=$(ssh "$REMOTE" 'date --iso-8601=seconds')
printf '%s\n' "$START_DATE" > "$OUT/maintenance/start-date.txt"
ssh "$REMOTE" "nvidia-smi -q" > "$OUT/gpu-health/nvidia-smi-before.txt"

phase "start Treebeard NVIDIA single-slot server"
ssh "$REMOTE" "rm -rf '$REMOTE_OUT'; mkdir -p '$REMOTE_OUT'; systemd-run --user --unit='$SERVICE' --description='Treebeard NVIDIA single-slot quality server' --collect --setenv=GGML_CUDA_DISABLE_MMVQ_12COL=0 '$REMOTE_BUILD/bin/llama-server' -m '$REMOTE_MODEL' -ngl 99 -ncmoe 0 -c 262144 -np 1 -kvu -fa on -ctk f16 -ctv f16 -b 8192 -ub 1024 -t 15 --host 127.0.0.1 --port '$REMOTE_PORT' --jinja --metrics -a '$MODEL_ALIAS'"
for _ in {1..600}; do
    if ssh "$REMOTE" "curl -fsS --max-time 5 http://127.0.0.1:$REMOTE_PORT/health" \
        > "$OUT/maintenance/remote-health.json" 2>/dev/null; then
        break
    fi
    ssh "$REMOTE" "systemctl --user is-active --quiet '$SERVICE'" || {
        ssh "$REMOTE" "journalctl --user-unit '$SERVICE' --no-pager -n 200" >&2
        exit 1
    }
    sleep 1
done
ssh "$REMOTE" "curl -fsS --max-time 5 http://127.0.0.1:$REMOTE_PORT/props" \
    > "$OUT/maintenance/remote-props.json"
jq -e --arg alias "$MODEL_ALIAS" \
    '.build_info == "b9624-0424f677f-cuda12" and .model_alias == $alias and .total_slots == 1 and .default_generation_settings.n_ctx == 262144' \
    "$OUT/maintenance/remote-props.json" >/dev/null

phase "open loopback SSH tunnel"
ssh -N -o ExitOnForwardFailure=yes \
    -L "127.0.0.1:$LOCAL_PORT:127.0.0.1:$REMOTE_PORT" "$REMOTE" &
TUNNEL_PID=$!
for _ in {1..60}; do
    curl -fsS --max-time 5 "http://127.0.0.1:$LOCAL_PORT/health" \
        > "$OUT/maintenance/tunnel-health.json" 2>/dev/null && break
    kill -0 "$TUNNEL_PID" 2>/dev/null || exit 1
    sleep 1
done
curl -fsS --max-time 5 "http://127.0.0.1:$LOCAL_PORT/v1/models" \
    > "$OUT/maintenance/models.json"

phase "full 69-case NVIDIA single-slot agent quality benchmark"
(
    cd "$TOOL_ROOT"
    timeout 3600 "$TOOL_BIN" --backend llamacpp \
        --base-url "http://127.0.0.1:$LOCAL_PORT" --model "$MODEL_ALIAS" \
        --no-think --seed 42 --reference-date 2026-03-20 \
        --parallel 1 --timeout 180 \
        --output-dir "$OUT/runs" \
        --json-file "$OUT/result.json" \
        --no-live --redact-url
) 2>&1 | tee "$OUT/console.log"

jq -e \
    '.status == "completed" and .total_scenarios == 69 and .config.concurrency == 1 and .config.error_rate == 0 and .scores.max_points == 138' \
    "$OUT/result.json" >/dev/null
jq '{run_id,status,final_score,total_points:.scores.total_points,max_points:.scores.max_points,pass_count:([.scores.scenario_results[] | select(.status == "pass")] | length),partial_count:([.scores.scenario_results[] | select(.status == "partial")] | length),fail_count:([.scores.scenario_results[] | select(.status == "fail")] | length),deployability,responsiveness,median_turn_ms:.scores.median_turn_ms,error_rate:.config.error_rate}' \
    "$OUT/result.json" > "$OUT/summary.json"
curl -fsS --max-time 5 "http://127.0.0.1:$LOCAL_PORT/health" \
    > "$OUT/maintenance/health-after.json"
curl -fsS --max-time 5 "http://127.0.0.1:$LOCAL_PORT/props" \
    > "$OUT/maintenance/props-after.json"

printf 'TREEBEARD_NVIDIA_AGENT_SINGLE_SLOT_OK\n'
