#!/usr/bin/env bash
set -Eeuo pipefail

REMOTE=dgx-spark
REMOTE_ROOT=/home/frosty40/treebeard-nvidia-rc3-0424f677f
PACKAGE="$REMOTE_ROOT/package-test/Treebeard-Qwen3.6-35B-A3B-GGUF"
CACHE="$REMOTE_ROOT/package-test/cache"
LOCAL_ROOT=/home/frosty40/turbo/results/treebeard-0.1.0-rc.3/20260711-release
FIXTURE="$LOCAL_ROOT/agent/single-slot-quality-seed42/report-preview.png"
OUT="${TREEBEARD_PACKAGE_SMOKE_OUT:-$LOCAL_ROOT/nvidia/package-smoke}"
MODEL_ALIAS=treebeard-0.1.0-rc.3-Qwen3.6-35B-A3B-Q5-cuda-c32768-np1
SERVICE=treebeard-packaged-cuda-smoke.service
REMOTE_PORT=18101
LOCAL_PORT=8102
TUNNEL_PID=
START_DATE=
TMP=

mkdir -p "$OUT"/{api,gpu-health,maintenance}
exec > >(tee -a "$OUT/guard.log") 2>&1

phase() {
    printf '\n[%s] PHASE %s\n' "$(date --iso-8601=seconds)" "$1"
}

cleanup() {
    local rc="${1:-0}"
    trap - EXIT INT TERM HUP
    set +e
    phase "stop packaged NVIDIA server and collect evidence"
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
    [[ -z "${TMP:-}" ]] || rm -rf "$TMP"
    date --iso-8601=seconds > "$OUT/completed-date.txt"
    if (( rc == 0 )) && [[ -f "$OUT/api/vision-response.json" ]]; then
        touch "$OUT/SUCCESS"
    fi
    exit "$rc"
}

trap 'cleanup $?' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

phase "preflight"
test ! -e "$OUT/SUCCESS"
test -f "$FIXTURE"
if ss -ltn "( sport = :$LOCAL_PORT )" | grep -q LISTEN; then
    printf 'LOCAL_PORT_BUSY=%s\n' "$LOCAL_PORT" >&2
    exit 1
fi
ssh "$REMOTE" "test -x '$PACKAGE/run.sh'; test -f '$PACKAGE/Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf'; test -f '$PACKAGE/mmproj-F16.gguf'; ! systemctl --user is-active --quiet '$SERVICE'"
START_DATE=$(ssh "$REMOTE" 'date --iso-8601=seconds')
printf '%s\n' "$START_DATE" > "$OUT/maintenance/start-date.txt"
ssh "$REMOTE" "nvidia-smi -q" > "$OUT/gpu-health/nvidia-smi-before.txt"
sha256sum "$FIXTURE" > "$OUT/api/vision-fixture.sha256"

phase "start full Treebeard package with multimodal projector"
ssh "$REMOTE" "systemd-run --user --unit='$SERVICE' --description='Treebeard pkg2 CUDA multimodal smoke' --collect --setenv=TREEBEARD_BACKEND=cuda --setenv=TREEBEARD_PROFILE=quality --setenv=TREEBEARD_CONTEXT=32768 --setenv=TREEBEARD_VERIFY=once --setenv=TREEBEARD_MULTIMODAL=1 --setenv=TREEBEARD_PORT=$REMOTE_PORT --setenv=TREEBEARD_CACHE_DIR='$CACHE' '$PACKAGE/run.sh'"
for _ in {1..600}; do
    if ssh "$REMOTE" "curl -fsS --max-time 5 http://127.0.0.1:$REMOTE_PORT/health" \
        > "$OUT/maintenance/remote-health.json" 2>/dev/null; then
        break
    fi
    ssh "$REMOTE" "systemctl --user is-active --quiet '$SERVICE'" || {
        ssh "$REMOTE" "journalctl --user-unit '$SERVICE' --no-pager -n 240" >&2
        exit 1
    }
    sleep 1
done
ssh "$REMOTE" "curl -fsS --max-time 5 http://127.0.0.1:$REMOTE_PORT/props" \
    > "$OUT/maintenance/remote-props.json"
jq -e --arg alias "$MODEL_ALIAS" \
    '.build_info == "b9624-0424f677f-cuda12" and .model_alias == $alias and .total_slots == 1 and .default_generation_settings.n_ctx == 32768 and .modalities.vision == true' \
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
    > "$OUT/api/models.json"

phase "tool-call API smoke"
TMP=$(mktemp -d)
jq -n --arg model "$MODEL_ALIAS" '{
    model: $model,
    messages: [{role: "user", content: "What is the weather in Chicago? Use the tool."}],
    tools: [{type: "function", function: {name: "get_weather", description: "Get current weather", parameters: {type: "object", properties: {city: {type: "string"}}, required: ["city"]}}}],
    tool_choice: "required",
    chat_template_kwargs: {enable_thinking: false},
    temperature: 0,
    max_tokens: 256
}' > "$TMP/tool-request.json"
curl -fsS --max-time 180 \
    -H 'Content-Type: application/json' \
    --data-binary "@$TMP/tool-request.json" \
    "http://127.0.0.1:$LOCAL_PORT/v1/chat/completions" \
    > "$OUT/api/tool-response.json"
jq -e '.choices[0].message.tool_calls[0].function.name == "get_weather"' \
    "$OUT/api/tool-response.json" >/dev/null

phase "bundled-projector vision smoke"
base64 -w 0 "$FIXTURE" > "$TMP/fixture.b64"
jq -n --arg model "$MODEL_ALIAS" --rawfile image "$TMP/fixture.b64" '{
    model: $model,
    messages: [{role: "user", content: [
        {type: "text", text: "Look at this benchmark report. What is the large score inside the green ring? Reply with only the number."},
        {type: "image_url", image_url: {url: ("data:image/png;base64," + $image)}}
    ]}],
    chat_template_kwargs: {enable_thinking: false},
    temperature: 0,
    max_tokens: 128
}' > "$TMP/vision-request.json"
curl -fsS --max-time 300 \
    -H 'Content-Type: application/json' \
    --data-binary "@$TMP/vision-request.json" \
    "http://127.0.0.1:$LOCAL_PORT/v1/chat/completions" \
    > "$OUT/api/vision-response.json"
jq -e '.choices[0].message.content | test("94")' \
    "$OUT/api/vision-response.json" >/dev/null

curl -fsS --max-time 5 "http://127.0.0.1:$LOCAL_PORT/health" \
    > "$OUT/maintenance/health-after.json"
curl -fsS --max-time 5 "http://127.0.0.1:$LOCAL_PORT/props" \
    > "$OUT/maintenance/props-after.json"

printf 'TREEBEARD_PACKAGED_CUDA_MULTIMODAL_SMOKE_OK\n'
