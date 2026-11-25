#!/usr/bin/env bash
# shellcheck disable=SC2016
# Behavioral tests for the Treebeard installer and launcher. They do not download
# the model or require a GPU. Dry-run launch tests use a sparse model file so
# the size check matches the pin without writing the full payload to disk.
set -Eeuo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
PASSED=0
FAILED=0

fail() {
    printf 'FAIL %s\n' "$*" >&2
    FAILED=$((FAILED + 1))
    return 1
}

ok() {
    printf 'ok %s\n' "$*"
    PASSED=$((PASSED + 1))
}

assert_eq() {
    local actual=$1 expected=$2 label=$3
    if [[ "$actual" == "$expected" ]]; then
        ok "$label"
    else
        fail "$label: expected [$expected] got [$actual]" || true
    fi
}

assert_contains() {
    local haystack=$1 needle=$2 label=$3
    if [[ "$haystack" == *"$needle"* ]]; then
        ok "$label"
    else
        fail "$label: missing [$needle] in [$haystack]" || true
    fi
}

assert_not_contains() {
    local haystack=$1 needle=$2 label=$3
    if [[ "$haystack" == *"$needle"* ]]; then
        fail "$label: unexpectedly found [$needle]" || true
    else
        ok "$label"
    fi
}

run_capture() {
    set +e
    LAST_OUT=$("$@" 2>&1)
    LAST_STATUS=$?
    set -e
}

expect_fail() {
    local label=$1
    shift
    run_capture "$@"
    if [[ "$LAST_STATUS" -ne 0 ]]; then
        ok "$label"
    else
        fail "$label: expected non-zero exit" || true
    fi
}

expect_ok() {
    local label=$1
    shift
    run_capture "$@"
    if [[ "$LAST_STATUS" -eq 0 ]]; then
        ok "$label"
    else
        fail "$label: exit $LAST_STATUS
$LAST_OUT" || true
    fi
}

cpu_threads() {
    local threads
    threads=$(getconf _NPROCESSORS_ONLN)
    if (( threads > 32 )); then
        threads=32
    fi
    printf '%s\n' "$threads"
}

prepare_package() {
    local dest=$1
    local backend=$2
    local directory archive_name stage sha
    case "$backend" in
        cpu) directory=runtime/cpu-linux-x86_64 ;;
        sycl) directory=runtime/sycl-linux-x86_64 ;;
        *) printf 'unknown backend %s\n' "$backend" >&2; return 1 ;;
    esac
    archive_name=runtime.tar.gz
    mkdir -p "$dest/$directory"
    stage=$(mktemp -d)
    mkdir -p "$stage/opt/treebeard-0.2.0-rc.1/bin" "$stage/opt/treebeard-0.2.0-rc.1/lib"
    cat > "$stage/opt/treebeard-0.2.0-rc.1/bin/llama-server" <<'EOF'
#!/bin/sh
printf 'llama-server\n'
EOF
    chmod 0755 "$stage/opt/treebeard-0.2.0-rc.1/bin/llama-server"
    echo 'shared' > "$stage/opt/treebeard-0.2.0-rc.1/lib/libllama.so.0"
    ln -s libllama.so.0 "$stage/opt/treebeard-0.2.0-rc.1/lib/libllama.so"
    tar -C "$stage" -czf "$dest/$directory/$archive_name" opt
    sha=$(sha256sum -- "$dest/$directory/$archive_name" | awk '{print $1}')
    printf '%s  %s\n' "$sha" "$directory/$archive_name" > "$dest/runtime/SHA256SUMS"
    cp -- "$ROOT/package/run.sh" "$dest/run.sh"
    chmod 0755 "$dest/run.sh"
    truncate -s 26592508896 "$dest/Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf"
    rm -rf -- "$stage"
}

write_meminfo() {
    local path=$1 kib=$2
    printf 'MemTotal: %s kB\n' "$kib" > "$path"
}

on_exit() {
    if [[ -n "${SERVER_PID:-}" ]]; then
        kill "$SERVER_PID" >/dev/null 2>&1 || true
        wait "$SERVER_PID" >/dev/null 2>&1 || true
    fi
}
trap on_exit EXIT

# --- CLI ---------------------------------------------------------------

expect_ok "help exits 0" bash "$ROOT/package/treebeard" help
assert_contains "$LAST_OUT" "treebeard serve" "help names serve"
expect_ok "version flag" bash "$ROOT/package/treebeard" --version
assert_eq "$LAST_OUT" "Treebeard 0.2.0-rc.1 (pkg5)" "version string"
expect_ok "report url" bash "$ROOT/package/treebeard" report
assert_eq "$LAST_OUT" "https://newjordan.github.io/treebeard/" "report url value"
expect_fail "unknown command" bash "$ROOT/package/treebeard" not-a-command
assert_eq "$LAST_STATUS" "2" "unknown command exits 2"

expect_ok "health url formatting" bash -c '
source "$1"
[[ "$(health_url 127.0.0.1 8093)" == "http://127.0.0.1:8093/health" ]]
[[ "$(health_url ::1 8093)" == "http://[::1]:8093/health" ]]
' bash "$ROOT/package/treebeard"

PORT_FILE=$(mktemp)
python3 - "$PORT_FILE" <<'PY' &
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
port_file = sys.argv[1]
class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.split("?", 1)[0] == "/health":
            body = b'{"status":"ok"}\n'
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_error(404)
    def log_message(self, fmt, *args):
        return
server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
with open(port_file, "w", encoding="utf-8") as handle:
    handle.write(str(server.server_address[1]))
server.serve_forever()
PY
SERVER_PID=$!
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
    if [[ -s "$PORT_FILE" ]]; then
        break
    fi
    sleep 0.05
done
SERVER_PORT=$(cat "$PORT_FILE")
[[ -n "$SERVER_PORT" ]] || fail "status fixture did not start" || true
if [[ -n "$SERVER_PORT" ]]; then
    expect_ok "status against local health endpoint" env TREEBEARD_HOST=127.0.0.1 TREEBEARD_PORT="$SERVER_PORT" bash "$ROOT/package/treebeard" status
    assert_contains "$LAST_OUT" '{"status":"ok"}' "status prints health body"
    assert_contains "$LAST_OUT" "Checking http://127.0.0.1:$SERVER_PORT/health" "status prints the URL it checks"
fi
expect_fail "status reports a closed port" env TREEBEARD_HOST=127.0.0.1 TREEBEARD_PORT=1 bash "$ROOT/package/treebeard" status
assert_contains "$LAST_OUT" "API health check failed" "status failure names the check"
rm -f -- "$PORT_FILE"

# --- launcher validation (no model required) ---------------------------

expect_fail "rejects a port above 65535" env TREEBEARD_PORT=65536 bash "$ROOT/package/run.sh"
assert_contains "$LAST_OUT" "TREEBEARD_PORT must be at most 65535" "port error text"
expect_fail "rejects an oversized context" env TREEBEARD_CONTEXT=99999999999999999999 bash "$ROOT/package/run.sh"
assert_contains "$LAST_OUT" "TREEBEARD_CONTEXT is too large" "overflow error text"
expect_fail "rejects parallel above context" env TREEBEARD_CONTEXT=4 TREEBEARD_PARALLEL=8 bash "$ROOT/package/run.sh"
assert_contains "$LAST_OUT" "TREEBEARD_PARALLEL cannot exceed TREEBEARD_CONTEXT" "parallel error text"
expect_fail "rejects an unknown profile" env TREEBEARD_PROFILE=fast bash "$ROOT/package/run.sh"
assert_contains "$LAST_OUT" "TREEBEARD_PROFILE must be quality, throughput, or custom" "profile error text"
expect_fail "rejects an unknown speculation mode" env TREEBEARD_SPECULATION=draft bash "$ROOT/package/run.sh"
assert_contains "$LAST_OUT" "TREEBEARD_SPECULATION must be off, ngram, mtp, or hybrid" "speculation error text"
expect_fail "rejects a non-numeric layer count" env TREEBEARD_NGL=many bash "$ROOT/package/run.sh"
assert_contains "$LAST_OUT" "TREEBEARD_NGL must be an integer from 0 through 999" "ngl error text"
expect_fail "rejects a host with spaces" env TREEBEARD_HOST='127.0.0.1 1' bash "$ROOT/package/run.sh"
assert_contains "$LAST_OUT" "TREEBEARD_HOST must be a hostname or IP address" "host error text"
expect_fail "rejects cuda on this architecture" env TREEBEARD_BACKEND=cuda bash "$ROOT/package/run.sh"
assert_contains "$LAST_OUT" "packaged CUDA runtime requires Linux ARM64" "cuda arch error"

# --- dry-run launch ----------------------------------------------------

WORK=$(mktemp -d)
CACHE=$(mktemp -d)
prepare_package "$WORK" cpu
THREADS=$(cpu_threads)
COMMON_ENV=(
    env
    TREEBEARD_CACHE_DIR="$CACHE"
    TREEBEARD_VERIFY=never
    TREEBEARD_DRY_RUN=1
    HOME="$WORK/home"
)

expect_ok "cpu quality dry-run" "${COMMON_ENV[@]}" bash "$WORK/run.sh"
assert_contains "$LAST_OUT" "backend=cpu" "dry-run selects cpu"
assert_contains "$LAST_OUT" "profile=quality" "dry-run quality profile"
assert_contains "$LAST_OUT" "context=32768" "cpu default context"
assert_contains "$LAST_OUT" "slots=1" "cpu quality slots"
assert_contains "$LAST_OUT" "reasoning=off(off)" "reasoning defaults off"
assert_contains "$LAST_OUT" "listen=http://127.0.0.1:8093/v1" "default listen url"
assert_contains "$LAST_OUT" "--reasoning off" "server reasoning flag"
assert_contains "$LAST_OUT" "--reasoning-budget -1" "server reasoning budget"
assert_contains "$LAST_OUT" "-t $THREADS" "cpu thread cap"
assert_not_contains "$LAST_OUT" "--spec-type" "speculation stays off"
assert_not_contains "$LAST_OUT" "-ngl" "cpu launch omits ngl"
assert_contains "$LAST_OUT" "/bin/llama-server" "command names llama-server"

expect_ok "cpu throughput profile" "${COMMON_ENV[@]}" TREEBEARD_PROFILE=throughput bash "$WORK/run.sh"
assert_contains "$LAST_OUT" "slots=2" "cpu throughput slots"
assert_contains "$LAST_OUT" "context=32768" "cpu throughput keeps the smaller context"

expect_ok "bounded cpu reasoning" "${COMMON_ENV[@]}" TREEBEARD_REASONING=bounded bash "$WORK/run.sh"
assert_contains "$LAST_OUT" "reasoning=bounded(16)" "cpu bounded budget"
assert_contains "$LAST_OUT" "--reasoning-budget 16" "cpu budget flag"

expect_ok "ngram speculation" "${COMMON_ENV[@]}" TREEBEARD_SPECULATION=ngram bash "$WORK/run.sh"
assert_contains "$LAST_OUT" "--spec-type ngram-map-k" "ngram spec type"
assert_contains "$LAST_OUT" "--spec-ngram-map-k-min-hits 2" "ngram min hits"

expect_ok "ipv6 listen url" "${COMMON_ENV[@]}" TREEBEARD_HOST=::1 TREEBEARD_PORT=8080 bash "$WORK/run.sh"
assert_contains "$LAST_OUT" "listen=http://[::1]:8080/v1" "bracketed ipv6 listen url"
assert_contains "$LAST_OUT" "--host ::1" "host argument preserved"

SYCL=$WORK-sycl
prepare_package "$SYCL" sycl
printf 'true\n' > "$SYCL/setvars.sh"
SYCL_BIN=$(mktemp -d)
cat > "$SYCL_BIN/sycl-ls" <<'EOF'
#!/bin/sh
printf '[level_zero:gpu]\n'
exit 0
EOF
chmod 0755 "$SYCL_BIN/sycl-ls"
expect_ok "sycl throughput dry-run" \
    "${COMMON_ENV[@]}" \
    PATH="$SYCL_BIN:$PATH" \
    TREEBEARD_ONEAPI_SETVARS="$SYCL/setvars.sh" \
    TREEBEARD_BACKEND=sycl \
    TREEBEARD_PROFILE=throughput \
    TREEBEARD_REASONING=bounded \
    bash "$SYCL/run.sh"
assert_contains "$LAST_OUT" "backend=sycl" "explicit sycl backend"
assert_contains "$LAST_OUT" "context=262144" "gpu default context"
assert_contains "$LAST_OUT" "slots=12" "gpu throughput slots"
assert_contains "$LAST_OUT" "reasoning=bounded(64)" "gpu bounded budget"
assert_contains "$LAST_OUT" "-ngl 99" "gpu layer offload"
assert_contains "$LAST_OUT" "--no-op-offload" "sycl no-op offload"
assert_not_contains "$LAST_OUT" "--mmproj" "multimodal flag stays off"

BROKEN=$(mktemp -d)
cat > "$BROKEN/sycl-ls" <<'EOF'
#!/bin/sh
printf 'no devices\n' >&2
exit 1
EOF
chmod 0755 "$BROKEN/sycl-ls"
expect_ok "auto falls back to cpu when sycl-ls fails" \
    "${COMMON_ENV[@]}" PATH="$BROKEN:$PATH" bash "$WORK/run.sh"
assert_contains "$LAST_OUT" "backend=cpu" "failed sycl-ls does not abort auto"

LEAK_BIN=$(mktemp -d)
EMPTY=$(mktemp -d)
cat > "$LEAK_BIN/sycl-ls" <<'EOF'
#!/bin/sh
printf 'cpu only\n'
exit 0
EOF
chmod 0755 "$LEAK_BIN/sycl-ls"
cat > "$WORK/setvars.sh" <<EOF
export PATH="$EMPTY"
EOF
expect_ok "oneAPI detection does not replace the launcher PATH" \
    "${COMMON_ENV[@]}" \
    PATH="$LEAK_BIN:$PATH" \
    TREEBEARD_ONEAPI_SETVARS="$WORK/setvars.sh" \
    bash "$WORK/run.sh"
assert_contains "$LAST_OUT" "backend=cpu" "leaky setvars still selects cpu"

NVIDIA_BIN=$(mktemp -d)
cat > "$NVIDIA_BIN/nvidia-smi" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod 0755 "$NVIDIA_BIN/nvidia-smi"
expect_ok "x86 NVIDIA note selects cpu" \
    "${COMMON_ENV[@]}" PATH="$NVIDIA_BIN:$PATH" bash "$WORK/run.sh"
assert_contains "$LAST_OUT" "backend=cpu" "x86 nvidia host stays on cpu"
assert_contains "$LAST_OUT" "Linux ARM64 (GB10)" "x86 nvidia host explains the cpu fallback"

# Unsafe archives.
evil_archive() {
    local dest=$1 kind=$2
    python3 - "$dest" "$kind" <<'PY'
import io, sys, tarfile
dest, kind = sys.argv[1], sys.argv[2]
with tarfile.open(dest, "w:gz") as tar:
    if kind == "dotdot":
        info = tarfile.TarInfo("../evil")
        data = b"x"
        info.size = len(data)
        tar.addfile(info, io.BytesIO(data))
    elif kind == "symlink":
        info = tarfile.TarInfo("opt/treebeard-0.2.0-rc.1/bin/llama-server")
        info.type = tarfile.SYMTYPE
        info.linkname = "/tmp/treebeard-escaped"
        tar.addfile(info)
    else:
        raise SystemExit("unknown kind")
PY
}

EVIL=$(mktemp -d)
mkdir -p "$EVIL/runtime/cpu-linux-x86_64"
cp -- "$ROOT/package/run.sh" "$EVIL/run.sh"
truncate -s 26592508896 "$EVIL/Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf"
evil_archive "$EVIL/runtime/cpu-linux-x86_64/runtime.tar.gz" dotdot
sha=$(sha256sum -- "$EVIL/runtime/cpu-linux-x86_64/runtime.tar.gz" | awk '{print $1}')
printf '%s  %s\n' "$sha" "runtime/cpu-linux-x86_64/runtime.tar.gz" > "$EVIL/runtime/SHA256SUMS"
expect_fail "rejects parent-directory archive members" \
    "${COMMON_ENV[@]}" TREEBEARD_CACHE_DIR="$EVIL/cache" bash "$EVIL/run.sh"
assert_contains "$LAST_OUT" "unsafe path in runtime archive" "dotdot member error"

evil_archive "$EVIL/runtime/cpu-linux-x86_64/runtime.tar.gz" symlink
sha=$(sha256sum -- "$EVIL/runtime/cpu-linux-x86_64/runtime.tar.gz" | awk '{print $1}')
printf '%s  %s\n' "$sha" "runtime/cpu-linux-x86_64/runtime.tar.gz" > "$EVIL/runtime/SHA256SUMS"
expect_fail "rejects absolute symlink members" \
    "${COMMON_ENV[@]}" TREEBEARD_CACHE_DIR="$EVIL/cache2" bash "$EVIL/run.sh"
assert_contains "$LAST_OUT" "unsafe symlink in runtime archive" "absolute symlink error"

printf '%s  %s\n' "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" \
    "runtime/cpu-linux-x86_64/runtime.tar.gz" > "$WORK/runtime/SHA256SUMS"
expect_fail "rejects a runtime checksum mismatch" \
    "${COMMON_ENV[@]}" TREEBEARD_CACHE_DIR="$WORK/cache-mismatch" bash "$WORK/run.sh"
assert_contains "$LAST_OUT" "runtime archive checksum mismatch" "checksum error text"

# --- installer ---------------------------------------------------------

expect_ok "installer help" bash "$ROOT/install.sh" --help
assert_contains "$LAST_OUT" "--allow-low-memory" "installer help lists the memory override"
expect_fail "installer rejects an unknown option" bash "$ROOT/install.sh" --nope
assert_contains "$LAST_OUT" "unknown option" "unknown installer option text"
expect_fail "installer rejects cuda on x86_64" bash "$ROOT/install.sh" --backend cuda
assert_contains "$LAST_OUT" "packaged CUDA runtime requires Linux ARM64" "installer cuda error"

MEM=$(mktemp)
write_meminfo "$MEM" 67108864
MISSING=$WORK/not-created
expect_ok "installer dry-run does not download" \
    env TREEBEARD_INSTALL_DRY_RUN=1 TREEBEARD_MEMINFO="$MEM" TREEBEARD_INSTALL_DIR="$MISSING" \
    bash "$ROOT/install.sh" --backend cpu
assert_contains "$LAST_OUT" "backend=cpu" "installer dry-run backend"
assert_contains "$LAST_OUT" "memory=ok" "installer dry-run memory"
if [[ -d "$MISSING" ]]; then
    fail "installer dry-run created $MISSING" || true
else
    ok "installer dry-run creates nothing"
fi

write_meminfo "$MEM" 1024
expect_fail "installer dry-run blocks low memory" \
    env TREEBEARD_INSTALL_DRY_RUN=1 TREEBEARD_MEMINFO="$MEM" bash "$ROOT/install.sh"
assert_contains "$LAST_OUT" "memory=blocked" "low memory marker"
assert_contains "$LAST_OUT" "--allow-low-memory" "low memory hint"

expect_ok "installer accepts an uppercase backend" \
    env TREEBEARD_INSTALL_DRY_RUN=1 TREEBEARD_MEMINFO="$MEM" \
    bash "$ROOT/install.sh" --allow-low-memory --backend CPU
assert_contains "$LAST_OUT" "backend=cpu" "uppercase backend normalized"

CURL_LOG=$(mktemp)
CURL_BIN=$(mktemp -d)
cat > "$CURL_BIN/curl" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$CURL_LOG"
exit 99
EOF
chmod 0755 "$CURL_BIN/curl"
: > "$CURL_LOG"
expect_ok "dry-run does not invoke curl" \
    env PATH="$CURL_BIN:$PATH" TREEBEARD_INSTALL_DRY_RUN=1 TREEBEARD_MEMINFO="$MEM" \
    bash "$ROOT/install.sh" --allow-low-memory
if [[ -s "$CURL_LOG" ]]; then
    fail "curl was invoked during dry-run: $(cat "$CURL_LOG")" || true
else
    ok "curl log stayed empty"
fi

expect_ok "download verifies, reuses, and refuses file URLs" bash -c '
set -Eeuo pipefail
source "$1"
sample=$(mktemp -d)
printf "treebeard\n" > "$sample/body"
size=$(wc -c < "$sample/body" | tr -d " ")
sha=$(sha256sum -- "$sample/body" | awk "{print \$1}")
INSTALL_ROOT=$sample/install
calls=0
curl() {
    if [[ "${1:-}" == --help ]]; then
        printf "%s\n" "--retry-all-errors"
        return 0
    fi
    calls=$((calls + 1))
    local previous="" destination=""
    for arg in "$@"; do
        if [[ "$previous" == --output ]]; then
            destination=$arg
        fi
        previous=$arg
    done
    cp -- "$sample/body" "$destination"
}
download_from "https://example.test/body" "nested/body" "$size" "$sha"
verify_file "$INSTALL_ROOT/nested/body" "$size" "$sha"
download_from "https://example.test/body" "nested/body" "$size" "$sha"
[[ "$calls" == 1 ]]
if (download_from "file:///tmp/body" "other" "$size" "$sha") >"$sample/err" 2>&1; then
    exit 1
fi
grep -q "unsupported download URL" "$sample/err"
if (download_from "https://example.test/body" "bad" "$size" "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb") >"$sample/bad" 2>&1; then
    exit 1
fi
grep -q "checksum or size mismatch" "$sample/bad"
[[ ! -e "$INSTALL_ROOT/bad" && ! -e "$INSTALL_ROOT/bad.part" ]]
' bash "$ROOT/install.sh"

expect_ok "sourced backend selection" bash -c '
set -Eeuo pipefail
source "$1"
arch=aarch64
nvidia-smi() { return 0; }
[[ "$(select_backend cuda)" == cuda ]]
arch=x86_64
if (select_backend cuda) >/tmp/treebeard-cuda-err 2>&1; then exit 1; fi
grep -q "Linux ARM64" /tmp/treebeard-cuda-err
arch=aarch64
if (select_backend cpu) >/tmp/treebeard-cpu-err 2>&1; then exit 1; fi
grep -q "Linux x86_64" /tmp/treebeard-cpu-err
' bash "$ROOT/install.sh"

LOW_DISK=$(mktemp -d)
write_meminfo "$MEM" 67108864
expect_fail "installer reports the computed disk requirement" \
    env TREEBEARD_MEMINFO="$MEM" TREEBEARD_INSTALL_DIR="$LOW_DISK/root" bash -c '
set -Eeuo pipefail
source "$1"
filesystem_free_bytes() { printf "10\n"; }
download_from() { printf "download called\n" >&2; exit 9; }
main --backend cpu
' bash "$ROOT/install.sh"
assert_contains "$LAST_OUT" "not enough free disk space" "disk error names the shortage"

expect_ok "installer pins match package/run.sh and package/treebeard" bash -c '
set -Eeuo pipefail
source "$1"
root=$2
run_size=$(wc -c < "$root/package/run.sh" | tr -d " ")
cli_size=$(wc -c < "$root/package/treebeard" | tr -d " ")
run_sha=$(sha256sum -- "$root/package/run.sh" | awk "{print \$1}")
cli_sha=$(sha256sum -- "$root/package/treebeard" | awk "{print \$1}")
[[ "$RUN_SIZE" == "$run_size" ]]
[[ "$CLI_SIZE" == "$cli_size" ]]
[[ "$RUN_SHA" == "$run_sha" ]]
[[ "$CLI_SHA" == "$cli_sha" ]]
' bash "$ROOT/install.sh" "$ROOT"

# --- repository integrity ----------------------------------------------

if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    list=$(mktemp)
    git -C "$ROOT" ls-files -co --exclude-standard | grep -v '^SHA256SUMS$' | LC_ALL=C sort > "$list"
    awk '{print $2}' "$ROOT/SHA256SUMS" | LC_ALL=C sort > "$list.sums"
    if diff -u "$list.sums" "$list" >/tmp/treebeard-sum-diff; then
        ok "SHA256SUMS lists every tracked file"
    else
        fail "SHA256SUMS file list drifted:
$(cat /tmp/treebeard-sum-diff)" || true
    fi
    if (cd "$ROOT" && sha256sum --check SHA256SUMS >/tmp/treebeard-sum-check 2>&1); then
        ok "SHA256SUMS matches file bytes"
    else
        fail "SHA256SUMS byte check failed:
$(tail -n 20 /tmp/treebeard-sum-check)" || true
    fi
    if (cd "$ROOT/docs" && sha256sum --check SHA256SUMS >/tmp/treebeard-docs-check 2>&1); then
        ok "docs/SHA256SUMS matches the site files"
    else
        fail "docs/SHA256SUMS byte check failed:
$(tail -n 20 /tmp/treebeard-docs-check)" || true
    fi
    rm -f -- "$list" "$list.sums"
fi

if [[ -f "$ROOT/SHA256SUMS" ]] && grep -q '  package/run.sh$' "$ROOT/SHA256SUMS"; then
    expect_ok "treebeard verify checks the repository manifest" bash "$ROOT/package/treebeard" verify
    assert_contains "$LAST_OUT" "repository files verified" "verify success line"
fi

rm -rf -- "$WORK" "$SYCL" "$EVIL" "$BROKEN" "$LEAK_BIN" "$EMPTY" "$NVIDIA_BIN" "$CURL_BIN" "$LOW_DISK" "$CACHE"
rm -f -- "$MEM" "$CURL_LOG"

printf '\n%d passed, %d failed\n' "$PASSED" "$FAILED"
if (( FAILED > 0 )); then
    exit 1
fi
