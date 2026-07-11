#!/usr/bin/env bash
set -Eeuo pipefail

PACKAGE_ROOT=${1:-/home/frosty40/turbo/turbo-combined/release/treebeard-0.1.0-rc.3-pkg3/huggingface/Treebeard-Qwen3.6-35B-A3B-GGUF}
OUT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
PORT=${TREEBEARD_SMOKE_PORT:-8110}
TMP=$(mktemp -d)
PID=

stop_server() {
    if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
        kill -INT "$PID" 2>/dev/null || true
        wait "$PID" 2>/dev/null || true
    fi
    PID=
}

sanitize_log() {
    if [[ -f "$TMP/server.log" ]]; then
        sed -e "s|$PACKAGE_ROOT|\$TREEBEARD_PACKAGE|g" \
            -e 's|/tmp/treebeard-pkg3-cpu-smoke|$TREEBEARD_CACHE|g' \
            "$TMP/server.log" > "$OUT/server.log"
    fi
}

cleanup() {
    stop_server
    sanitize_log
    rm -rf -- "$TMP"
}
trap cleanup EXIT INT TERM

started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
env \
    TREEBEARD_BACKEND=cpu \
    TREEBEARD_CONTEXT=4096 \
    TREEBEARD_PARALLEL=1 \
    TREEBEARD_PORT="$PORT" \
    TREEBEARD_HOST=127.0.0.1 \
    TREEBEARD_VERIFY=never \
    TREEBEARD_CACHE_DIR=/tmp/treebeard-pkg3-cpu-smoke \
    "$PACKAGE_ROOT/run.sh" > "$TMP/server.log" 2>&1 &
PID=$!

for _ in $(seq 1 120); do
    if curl -fsS --max-time 2 "http://127.0.0.1:$PORT/health" > "$OUT/health.json" 2>/dev/null; then
        break
    fi
    kill -0 "$PID" 2>/dev/null || {
        printf 'server exited before it became healthy\n' >&2
        exit 1
    }
    sleep 1
done
jq -e '.status == "ok"' "$OUT/health.json" >/dev/null

curl -fsS --max-time 10 "http://127.0.0.1:$PORT/props" |
    jq '{build_info, model_alias, total_slots, default_generation_settings: {n_ctx: .default_generation_settings.n_ctx}}' \
        > "$OUT/props.json"

curl -fsS --max-time 300 "http://127.0.0.1:$PORT/v1/chat/completions" \
    -H 'Content-Type: application/json' \
    --data-binary @- > "$OUT/chat-response.json" <<'JSON'
{"model":"treebeard","messages":[{"role":"system","content":"Answer with exactly: TREEBEARD READY"},{"role":"user","content":"Status?"}],"temperature":0,"max_tokens":16,"chat_template_kwargs":{"enable_thinking":false}}
JSON
jq -e '.choices[0].message.content == "TREEBEARD READY"' "$OUT/chat-response.json" >/dev/null

curl -fsS --max-time 300 "http://127.0.0.1:$PORT/v1/chat/completions" \
    -H 'Content-Type: application/json' \
    --data-binary @- > "$OUT/tool-response.json" <<'JSON'
{"model":"treebeard","messages":[{"role":"user","content":"Use the multiply tool to calculate 17 times 23."}],"tools":[{"type":"function","function":{"name":"multiply","description":"Multiply two integers","parameters":{"type":"object","properties":{"a":{"type":"integer"},"b":{"type":"integer"}},"required":["a","b"]}}}],"tool_choice":"required","temperature":0,"max_tokens":64,"chat_template_kwargs":{"enable_thinking":false}}
JSON
jq -e '
    .choices[0].finish_reason == "tool_calls" and
    .choices[0].message.tool_calls[0].function.name == "multiply" and
    ((.choices[0].message.tool_calls[0].function.arguments | fromjson) == {"a":17,"b":23})
' "$OUT/tool-response.json" >/dev/null

stop_server
sanitize_log
completed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq -n \
    --arg started_at "$started_at" \
    --arg completed_at "$completed_at" \
    --arg kernel "$(uname -srmo)" \
    --arg cpu "$(lscpu | awk -F: '$1 == "Model name" { sub(/^[[:space:]]+/, "", $2); print $2; exit }')" \
    --argjson memory_bytes "$(awk '$1 == "MemTotal:" { print $2 * 1024 }' /proc/meminfo)" \
    --slurpfile props "$OUT/props.json" \
    --slurpfile chat "$OUT/chat-response.json" \
    --slurpfile tool "$OUT/tool-response.json" \
    '{
        schema: "treebeard.cpu_package_smoke.v1",
        status: "passed",
        started_at: $started_at,
        completed_at: $completed_at,
        host: {kernel: $kernel, cpu: $cpu, memory_bytes: $memory_bytes},
        package: {version: "0.1.0-rc.3", revision: "pkg3", backend: "cpu", context_tokens: 4096, slots: 1},
        server: $props[0],
        chat: {
            expected: "TREEBEARD READY",
            actual: $chat[0].choices[0].message.content,
            prompt_tokens_per_second: $chat[0].timings.prompt_per_second,
            generation_tokens_per_second: $chat[0].timings.predicted_per_second
        },
        tool_call: {
            expected: {name: "multiply", arguments: {a: 17, b: 23}},
            actual: {
                name: $tool[0].choices[0].message.tool_calls[0].function.name,
                arguments: ($tool[0].choices[0].message.tool_calls[0].function.arguments | fromjson)
            },
            generation_tokens_per_second: $tool[0].timings.predicted_per_second
        }
    }' > "$OUT/summary.json"

find "$OUT" -maxdepth 1 -type f ! -name SHA256SUMS -printf '%f\0' |
    sort -z |
    xargs -0 -r sha256sum --tag |
    sed "s| ($OUT/| (|" > "$OUT/SHA256SUMS"

printf 'Treebeard CPU package smoke passed.\n'
