#!/usr/bin/env bash
set -Eeuo pipefail

VERSION=0.1.0-rc.3
PACKAGING_REVISION=pkg4
MODEL_NAME=Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf
MODEL_SHA256=25233af7642e3a91bd52cc4aeefdbd4a117479088e06cf1aea5b6bedb443c506
MODEL_SIZE=26592508896
MMPROJ_NAME=mmproj-F16.gguf
MMPROJ_SHA256=8971ee4f331ff0a4c609374f32984b3d4e6dc086c0aa35f1d637fad1829e887f
MMPROJ_SIZE=899283680

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
MODEL="$ROOT/$MODEL_NAME"
MMPROJ="$ROOT/$MMPROJ_NAME"
CACHE_ROOT="${TREEBEARD_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/treebeard/$VERSION-$PACKAGING_REVISION}"
VERIFY_ROOT="$CACHE_ROOT/verified"

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "$1 is required"
}

require_positive_integer() {
    local name="$1"
    local value="$2"
    [[ "$value" =~ ^[1-9][0-9]*$ ]] || fail "$name must be a positive integer"
}

verify_payload() {
    local path="$1"
    local expected="$2"
    local expected_size="$3"
    local label="$4"
    local fingerprint stamp

    [[ -f "$path" ]] || fail "$label is missing: $path"
    [[ "$(stat -Lc '%s' "$path")" == "$expected_size" ]] ||
        fail "$label size mismatch: $path"

    case "$VERIFY_MODE" in
        never)
            return
            ;;
        once|always)
            ;;
        *)
            fail "TREEBEARD_VERIFY must be once, always, or never"
            ;;
    esac

    mkdir -p "$VERIFY_ROOT"
    stamp="$VERIFY_ROOT/$expected.ok"
    fingerprint=$(stat -Lc '%d:%i:%s:%Y' "$path")
    if [[ "$VERIFY_MODE" == once && -f "$stamp" && "$(<"$stamp")" == "$fingerprint" ]]; then
        return
    fi
    printf 'Verifying %s...\n' "$label"
    [[ "$(sha256sum -- "$path" | awk '{print $1}')" == "$expected" ]] ||
        fail "$label checksum mismatch: $path"
    printf '%s\n' "$fingerprint" > "$stamp.tmp.$$"
    mv "$stamp.tmp.$$" "$stamp"
}

select_backend() {
    local requested="$1"
    local arch
    local sycl_devices
    arch=$(uname -m)

    if [[ "$requested" == auto ]]; then
        if [[ "$arch" == aarch64 ]] && command -v nvidia-smi >/dev/null 2>&1 &&
                nvidia-smi -L >/dev/null 2>&1; then
            printf 'cuda\n'
            return
        fi
        if [[ "$arch" == x86_64 ]] && ! command -v sycl-ls >/dev/null 2>&1 &&
                [[ -f "${TREEBEARD_ONEAPI_SETVARS:-/opt/intel/oneapi/setvars.sh}" ]]; then
            set +u
            source "${TREEBEARD_ONEAPI_SETVARS:-/opt/intel/oneapi/setvars.sh}" --force >/dev/null
            set -u
        fi
        if [[ "$arch" == x86_64 ]] && command -v sycl-ls >/dev/null 2>&1; then
            sycl_devices=$(sycl-ls 2>&1) || fail "SYCL device discovery failed"
            if grep -Fq '[level_zero:gpu]' <<<"$sycl_devices"; then
                printf 'sycl\n'
                return
            fi
        fi
        if [[ "$arch" == x86_64 ]]; then
            printf 'cpu\n'
            return
        fi
        fail "no packaged backend is available for $arch"
    fi

    case "$requested" in
        cuda)
            [[ "$arch" == aarch64 ]] || fail "packaged CUDA runtime requires Linux ARM64"
            require_command nvidia-smi
            nvidia-smi -L >/dev/null 2>&1 || fail "no NVIDIA GPU detected"
            ;;
        sycl)
            [[ "$arch" == x86_64 ]] || fail "packaged SYCL runtime requires Linux x86_64"
            if ! command -v sycl-ls >/dev/null 2>&1 &&
                    [[ -f "${TREEBEARD_ONEAPI_SETVARS:-/opt/intel/oneapi/setvars.sh}" ]]; then
                set +u
                source "${TREEBEARD_ONEAPI_SETVARS:-/opt/intel/oneapi/setvars.sh}" --force >/dev/null
                set -u
            fi
            require_command sycl-ls
            sycl_devices=$(sycl-ls 2>&1) || fail "SYCL device discovery failed"
            grep -Fq '[level_zero:gpu]' <<<"$sycl_devices" || fail "no Level Zero GPU detected"
            ;;
        cpu)
            [[ "$arch" == x86_64 ]] || fail "packaged CPU runtime requires Linux x86_64"
            ;;
        *)
            fail "TREEBEARD_BACKEND must be auto, cuda, sycl, or cpu"
            ;;
    esac
    printf '%s\n' "$requested"
}

runtime_archive_for_backend() {
    local backend="$1"
    local directory
    local -a archives

    case "$backend" in
        cuda) directory="$ROOT/runtime/cuda-linux-aarch64" ;;
        sycl) directory="$ROOT/runtime/sycl-linux-x86_64" ;;
        cpu) directory="$ROOT/runtime/cpu-linux-x86_64" ;;
        *) fail "unsupported backend: $backend" ;;
    esac
    shopt -s nullglob
    archives=("$directory"/*.tar.gz)
    shopt -u nullglob
    [[ ${#archives[@]} -eq 1 ]] || fail "expected one runtime archive in $directory"
    printf '%s\n' "${archives[0]}"
}

install_runtime() {
    local backend="$1"
    local archive="$2"
    local relative expected actual runtime_root stage install_root member

    relative=${archive#"$ROOT/"}
    [[ -f "$ROOT/runtime/SHA256SUMS" ]] || fail "runtime/SHA256SUMS is missing"
    expected=$(awk -v file="$relative" '$2 == file { print $1 }' "$ROOT/runtime/SHA256SUMS")
    [[ "$expected" =~ ^[0-9a-f]{64}$ ]] || fail "runtime checksum is missing for $relative"
    actual=$(sha256sum -- "$archive" | awk '{print $1}')
    [[ "$actual" == "$expected" ]] || fail "runtime archive checksum mismatch: $relative"

    runtime_root="$CACHE_ROOT/runtime/$backend-$expected"
    if [[ ! -f "$runtime_root/.complete" ]]; then
        mkdir -p "$CACHE_ROOT/runtime"
        exec 9>>"$CACHE_ROOT/.install.lock"
        flock -w "${TREEBEARD_LOCK_TIMEOUT:-1800}" 9 || fail "timed out waiting for runtime lock"
        if [[ ! -f "$runtime_root/.complete" ]]; then
            stage="$CACHE_ROOT/runtime/.stage-$backend-$$"
            rm -rf -- "$stage"
            mkdir -p "$stage"
            while IFS= read -r member; do
                if [[ "$member" == /* || "$member" =~ (^|/)\.\.(/|$) ]]; then
                    fail "unsafe path in runtime archive: $member"
                fi
            done < <(tar -tzf "$archive")
            tar -xzf "$archive" -C "$stage" --no-same-owner --no-same-permissions
            install_root="$stage/opt/treebeard-$VERSION"
            [[ -x "$install_root/bin/llama-server" ]] || fail "runtime does not contain llama-server"
            if [[ -f "$install_root/FILES.sha256" ]]; then
                (cd "$install_root" && sha256sum --check FILES.sha256 >/dev/null)
            fi
            printf '%s\n' "$expected" > "$stage/.complete"
            rm -rf -- "$runtime_root"
            mv "$stage" "$runtime_root"
        fi
        flock -u 9
        exec 9>&-
    fi
    printf '%s\n' "$runtime_root/opt/treebeard-$VERSION"
}

require_command awk
require_command flock
require_command grep
require_command sha256sum
require_command stat
require_command tar

[[ "$(uname -s)" == Linux ]] || fail "this package requires Linux"

VERIFY_MODE="${TREEBEARD_VERIFY:-once}"
BACKEND=$(select_backend "${TREEBEARD_BACKEND:-auto}")
PROFILE="${TREEBEARD_PROFILE:-quality}"
case "$PROFILE" in
    quality)
        if [[ "$BACKEND" == cpu ]]; then
            DEFAULT_CONTEXT=32768
        else
            DEFAULT_CONTEXT=262144
        fi
        DEFAULT_PARALLEL=1
        ;;
    throughput)
        if [[ "$BACKEND" == cpu ]]; then
            DEFAULT_CONTEXT=32768
            DEFAULT_PARALLEL=2
        else
            DEFAULT_CONTEXT=262144
            DEFAULT_PARALLEL=12
        fi
        ;;
    custom)
        if [[ "$BACKEND" == cpu ]]; then
            DEFAULT_CONTEXT=32768
        else
            DEFAULT_CONTEXT=262144
        fi
        DEFAULT_PARALLEL=1
        ;;
    *)
        fail "TREEBEARD_PROFILE must be quality, throughput, or custom"
        ;;
esac

if [[ "$BACKEND" == cpu ]]; then
    DEFAULT_BATCH=2048
    DEFAULT_UBATCH=512
    DEFAULT_NGL=0
    DEFAULT_FLASH_ATTN=auto
    DEFAULT_THREADS=$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf '1\n')
    if (( DEFAULT_THREADS > 32 )); then
        DEFAULT_THREADS=32
    fi
else
    DEFAULT_BATCH=8192
    DEFAULT_UBATCH=1024
    DEFAULT_NGL=99
    DEFAULT_FLASH_ATTN=on
    DEFAULT_THREADS=15
fi

CONTEXT="${TREEBEARD_CONTEXT:-$DEFAULT_CONTEXT}"
PARALLEL="${TREEBEARD_PARALLEL:-$DEFAULT_PARALLEL}"
BATCH="${TREEBEARD_BATCH:-$DEFAULT_BATCH}"
UBATCH="${TREEBEARD_UBATCH:-$DEFAULT_UBATCH}"
THREADS="${TREEBEARD_THREADS:-$DEFAULT_THREADS}"
NGL="${TREEBEARD_NGL:-$DEFAULT_NGL}"
FLASH_ATTN="${TREEBEARD_FLASH_ATTN:-$DEFAULT_FLASH_ATTN}"
HOST="${TREEBEARD_HOST:-127.0.0.1}"
PORT="${TREEBEARD_PORT:-8093}"
MULTIMODAL="${TREEBEARD_MULTIMODAL:-0}"
DRY_RUN="${TREEBEARD_DRY_RUN:-0}"
REASONING="${TREEBEARD_REASONING:-off}"
SPECULATION="${TREEBEARD_SPECULATION:-off}"

if [[ "$BACKEND" == cpu ]]; then
    DEFAULT_REASONING_BUDGET=16
else
    DEFAULT_REASONING_BUDGET=64
fi
REASONING_BUDGET="${TREEBEARD_REASONING_BUDGET:-$DEFAULT_REASONING_BUDGET}"

require_positive_integer TREEBEARD_CONTEXT "$CONTEXT"
require_positive_integer TREEBEARD_PARALLEL "$PARALLEL"
require_positive_integer TREEBEARD_BATCH "$BATCH"
require_positive_integer TREEBEARD_UBATCH "$UBATCH"
require_positive_integer TREEBEARD_THREADS "$THREADS"
require_positive_integer TREEBEARD_PORT "$PORT"
(( PARALLEL <= CONTEXT )) || fail "TREEBEARD_PARALLEL cannot exceed TREEBEARD_CONTEXT"
(( UBATCH <= BATCH )) || fail "TREEBEARD_UBATCH cannot exceed TREEBEARD_BATCH"
(( 10#$PORT <= 65535 )) || fail "TREEBEARD_PORT must be at most 65535"
[[ "$MULTIMODAL" == 0 || "$MULTIMODAL" == 1 ]] || fail "TREEBEARD_MULTIMODAL must be 0 or 1"
[[ "$DRY_RUN" == 0 || "$DRY_RUN" == 1 ]] || fail "TREEBEARD_DRY_RUN must be 0 or 1"
[[ "$FLASH_ATTN" == on || "$FLASH_ATTN" == off || "$FLASH_ATTN" == auto ]] ||
    fail "TREEBEARD_FLASH_ATTN must be on, off, or auto"

case "$REASONING" in
    off|unrestricted)
        ;;
    bounded)
        require_positive_integer TREEBEARD_REASONING_BUDGET "$REASONING_BUDGET"
        ;;
    *)
        fail "TREEBEARD_REASONING must be off, bounded, or unrestricted"
        ;;
esac

case "$SPECULATION" in
    off|ngram|mtp|hybrid)
        ;;
    *)
        fail "TREEBEARD_SPECULATION must be off, ngram, mtp, or hybrid"
        ;;
esac

mkdir -p "$CACHE_ROOT"
chmod 700 "$CACHE_ROOT"
verify_payload "$MODEL" "$MODEL_SHA256" "$MODEL_SIZE" "model"
if [[ "$MULTIMODAL" == 1 ]]; then
    verify_payload "$MMPROJ" "$MMPROJ_SHA256" "$MMPROJ_SIZE" "multimodal projector"
fi

if [[ -n "${TREEBEARD_RUNTIME_ROOT:-}" ]]; then
    [[ "${TREEBEARD_ALLOW_UNVERIFIED_RUNTIME:-0}" == 1 ]] ||
        fail "TREEBEARD_RUNTIME_ROOT requires TREEBEARD_ALLOW_UNVERIFIED_RUNTIME=1"
    INSTALL_ROOT="$TREEBEARD_RUNTIME_ROOT"
else
    RUNTIME_ARCHIVE=$(runtime_archive_for_backend "$BACKEND")
    INSTALL_ROOT=$(install_runtime "$BACKEND" "$RUNTIME_ARCHIVE")
fi

SERVER="$INSTALL_ROOT/bin/llama-server"
[[ -x "$SERVER" ]] || fail "llama-server is missing: $SERVER"
export LD_LIBRARY_PATH="$INSTALL_ROOT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

if [[ "$BACKEND" == sycl ]]; then
    ONEAPI_SETVARS="${TREEBEARD_ONEAPI_SETVARS:-/opt/intel/oneapi/setvars.sh}"
    [[ -f "$ONEAPI_SETVARS" ]] || fail "Intel oneAPI setup is missing: $ONEAPI_SETVARS"
    set +u
    source "$ONEAPI_SETVARS" --force >/dev/null
    set -u
    export GGML_SYCL_ENABLE_FUSION="${GGML_SYCL_ENABLE_FUSION:-1}"
fi

args=(
    -m "$MODEL"
)
if [[ "$BACKEND" != cpu ]]; then
    args+=(-ngl "$NGL")
fi
args+=(
    -ncmoe "${TREEBEARD_NCMOE:-0}"
    -c "$CONTEXT"
    -np "$PARALLEL"
    -kvu
    -fa "$FLASH_ATTN"
    -ctk f16
    -ctv f16
    -b "$BATCH"
    -ub "$UBATCH"
    -t "$THREADS"
    --host "$HOST"
    --port "$PORT"
    --jinja
    --metrics
    -a "treebeard-$VERSION-Qwen3.6-35B-A3B-Q5-${BACKEND}-c${CONTEXT}-np${PARALLEL}"
)

case "$REASONING" in
    off)
        # Preserve the validated no-thinking server default. Clients can still
        # opt individual requests into thinking with request-level controls.
        args+=(--reasoning off --reasoning-budget -1)
        REASONING_DETAIL=off
        ;;
    bounded)
        args+=(--reasoning on --reasoning-budget "$REASONING_BUDGET")
        REASONING_DETAIL="$REASONING_BUDGET"
        ;;
    unrestricted)
        args+=(--reasoning on --reasoning-budget -1)
        REASONING_DETAIL=unlimited
        ;;
esac

case "$SPECULATION" in
    off)
        # The pinned runtime already defaults to one NONE sentinel. Do not add
        # another --spec-type none entry on its append-style parser.
        ;;
    ngram)
        # Short drafts and two required prompt hits are deliberately
        # conservative; acceptance and speed remain workload-dependent.
        args+=(
            --spec-type ngram-map-k
            --spec-ngram-map-k-size-n 12
            --spec-ngram-map-k-size-m 16
            --spec-ngram-map-k-min-hits 2
        )
        ;;
    mtp|hybrid)
        spec_types=draft-mtp
        if [[ "$SPECULATION" == hybrid ]]; then
            spec_types=ngram-map-k,draft-mtp
            args+=(
                --spec-ngram-map-k-size-n 12
                --spec-ngram-map-k-size-m 16
                --spec-ngram-map-k-min-hits 2
            )
        fi
        # Qwen3.6's native one-layer MTP head is carried by the model GGUF.
        # Keep the verification batch narrow until a workload proves a larger
        # draft profitable on its backend and concurrency shape.
        args+=(
            --spec-type "$spec_types"
            --spec-draft-n-max 2
            --spec-draft-n-min 1
            --spec-draft-p-min 0.20
            --spec-draft-mtp-branch-k 1
            --spec-draft-mtp-tree-width 1
            --spec-draft-mtp-tree-depth 2
        )
        ;;
esac

if [[ "$BACKEND" == sycl ]]; then
    args+=(--no-op-offload)
fi
if [[ "$MULTIMODAL" == 1 ]]; then
    args+=(--mmproj "$MMPROJ")
fi
args+=("$@")

printf 'Treebeard %s %s: backend=%s profile=%s context=%s slots=%s multimodal=%s reasoning=%s(%s) speculation=%s\n' \
    "$VERSION" "$PACKAGING_REVISION" "$BACKEND" "$PROFILE" "$CONTEXT" "$PARALLEL" "$MULTIMODAL" \
    "$REASONING" "$REASONING_DETAIL" "$SPECULATION"

if [[ "$DRY_RUN" == 1 ]]; then
    printf 'Command:'
    printf ' %q' "$SERVER" "${args[@]}"
    printf '\n'
    exit 0
fi

if [[ -n "${TREEBEARD_CPUSET:-}" ]]; then
    require_command taskset
    exec taskset -c "$TREEBEARD_CPUSET" "$SERVER" "${args[@]}"
fi
exec "$SERVER" "${args[@]}"
