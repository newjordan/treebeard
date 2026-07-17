#!/usr/bin/env bash
set -Eeuo pipefail

VERSION=0.1.0-rc.3
REVISION=pkg4
MODEL_REPO=Frosty40/Treebeard-Qwen3.6-35B-A3B-GGUF
ASSET_BASE=${TREEBEARD_ASSET_BASE:-https://huggingface.co/$MODEL_REPO/resolve/main}
INSTALL_ROOT=${TREEBEARD_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/treebeard/$VERSION-$REVISION}
BIN_DIR=${TREEBEARD_BIN_DIR:-$HOME/.local/bin}
BACKEND=${TREEBEARD_BACKEND:-auto}
MULTIMODAL=${TREEBEARD_INSTALL_MULTIMODAL:-0}
ALLOW_LOW_MEMORY=${TREEBEARD_ALLOW_LOW_MEMORY:-0}

MODEL=Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf
MODEL_SIZE=26592508896
MODEL_SHA=25233af7642e3a91bd52cc4aeefdbd4a117479088e06cf1aea5b6bedb443c506
MMPROJ=mmproj-F16.gguf
MMPROJ_SIZE=899283680
MMPROJ_SHA=8971ee4f331ff0a4c609374f32984b3d4e6dc086c0aa35f1d637fad1829e887f
RUN_SHA=acd5c33ea206ba86814c5c739647a08f80b693332354c7a753a1eac9bade9206
CLI_SHA=16eb404820fb872f14460a546e79f3cf99c98d2314b40167c105ed08f2f1c132

usage() {
    cat <<'EOF'
Install Treebeard on Linux.

Usage: install.sh [options]

  --backend auto|cpu|sycl|cuda  Select a packaged runtime
  --multimodal                   Also install the F16 vision projector
  --install-dir PATH             Install package files under PATH
  --bin-dir PATH                 Put the treebeard command under PATH
  --allow-low-memory             Continue with less than 32 GB of system memory
  -h, --help                     Show this help

Environment variables with the same names are also supported; see README.md.
EOF
}

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

while (( $# > 0 )); do
    case "$1" in
        --backend)
            (( $# >= 2 )) || fail '--backend requires a value'
            BACKEND=$2
            shift 2
            ;;
        --multimodal)
            MULTIMODAL=1
            shift
            ;;
        --install-dir)
            (( $# >= 2 )) || fail '--install-dir requires a value'
            INSTALL_ROOT=$2
            shift 2
            ;;
        --bin-dir)
            (( $# >= 2 )) || fail '--bin-dir requires a value'
            BIN_DIR=$2
            shift 2
            ;;
        --allow-low-memory)
            ALLOW_LOW_MEMORY=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "unknown option: $1"
            ;;
    esac
done

for command in awk curl df sha256sum stat tar uname; do
    command -v "$command" >/dev/null 2>&1 || fail "$command is required"
done
[[ "$(uname -s)" == Linux ]] || fail 'Treebeard pkg3 supports Linux only'
[[ "$MULTIMODAL" == 0 || "$MULTIMODAL" == 1 ]] || fail 'TREEBEARD_INSTALL_MULTIMODAL must be 0 or 1'
[[ "$ALLOW_LOW_MEMORY" == 0 || "$ALLOW_LOW_MEMORY" == 1 ]] || fail 'TREEBEARD_ALLOW_LOW_MEMORY must be 0 or 1'

arch=$(uname -m)
select_backend() {
    local requested=$1
    local sycl_devices=

    if [[ "$requested" == auto ]]; then
        if [[ "$arch" == aarch64 ]] && command -v nvidia-smi >/dev/null 2>&1 &&
                nvidia-smi -L >/dev/null 2>&1; then
            printf 'cuda\n'
            return
        fi
        if [[ "$arch" == x86_64 ]] && ! command -v sycl-ls >/dev/null 2>&1 &&
                [[ -f /opt/intel/oneapi/setvars.sh ]]; then
            set +u
            source /opt/intel/oneapi/setvars.sh --force >/dev/null
            set -u
        fi
        if [[ "$arch" == x86_64 ]] && command -v sycl-ls >/dev/null 2>&1; then
            sycl_devices=$(sycl-ls 2>&1 || true)
            if grep -Fq '[level_zero:gpu]' <<<"$sycl_devices"; then
                printf 'sycl\n'
                return
            fi
        fi
        [[ "$arch" == x86_64 ]] || fail "no packaged runtime is available for $arch"
        if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
            printf 'note: pkg3 NVIDIA acceleration targets ARM64 GB10; selecting portable x86_64 CPU runtime\n' >&2
        fi
        printf 'cpu\n'
        return
    fi

    case "$requested" in
        cpu)
            [[ "$arch" == x86_64 ]] || fail 'the packaged CPU runtime requires Linux x86_64'
            ;;
        sycl)
            [[ "$arch" == x86_64 ]] || fail 'the packaged SYCL runtime requires Linux x86_64'
            ;;
        cuda)
            [[ "$arch" == aarch64 ]] || fail 'the packaged CUDA runtime requires Linux ARM64'
            command -v nvidia-smi >/dev/null 2>&1 || fail 'nvidia-smi is required for the CUDA runtime'
            nvidia-smi -L >/dev/null 2>&1 || fail 'no NVIDIA GPU was detected'
            ;;
        *)
            fail 'backend must be auto, cpu, sycl, or cuda'
            ;;
    esac
    printf '%s\n' "$requested"
}

BACKEND=$(select_backend "$BACKEND")
case "$BACKEND" in
    cpu)
        RUNTIME_PATH=runtime/cpu-linux-x86_64/treebeard-0.1.0-rc.3-b9624-pkg3-cpu-ubuntu22.04-linux-x86_64.tar.gz
        RUNTIME_SIZE=11033535
        RUNTIME_SHA=51497d7a72cfe8cdf3d66fcbf3ba36f8d5130084cc339cdc49995ec131126732
        ;;
    sycl)
        RUNTIME_PATH=runtime/sycl-linux-x86_64/treebeard-0.1.0-rc.3-b9624-pkg2-sycl-oneapi2026-linux-x86_64.tar.gz
        RUNTIME_SIZE=21576232
        RUNTIME_SHA=beec6bd316cc5285481d1545e66b31f984b1eb93e69fe05c7d0b1c5e1bafc756
        ;;
    cuda)
        RUNTIME_PATH=runtime/cuda-linux-aarch64/treebeard-0.1.0-rc.3-b9624-pkg2-cuda13.3-linux-aarch64.tar.gz
        RUNTIME_SIZE=51818280
        RUNTIME_SHA=0dfadb9ed53c66ab5a23b6731988d833b223af4e51c8f11ad9522a95eb0f04f3
        ;;
esac

memory_bytes=$(awk '$1 == "MemTotal:" { print $2 * 1024 }' /proc/meminfo)
if (( memory_bytes < 30000000000 )) && [[ "$ALLOW_LOW_MEMORY" != 1 ]]; then
    fail 'Treebeard needs about 32 GB of system or unified memory; use --allow-low-memory to override'
fi

mkdir -p "$INSTALL_ROOT" "$INSTALL_ROOT/$(dirname -- "$RUNTIME_PATH")" "$BIN_DIR"

if [[ -z "${TREEBEARD_MODEL_FILE:-}" ]] && [[ ! -f "$INSTALL_ROOT/$MODEL" ]]; then
    available=$(df -PB1 "$INSTALL_ROOT" | awk 'NR == 2 { print $4 }')
    required=$((MODEL_SIZE + RUNTIME_SIZE + 1073741824))
    if [[ "$MULTIMODAL" == 1 ]]; then
        required=$((required + MMPROJ_SIZE))
    fi
    (( available >= required )) || fail 'not enough free disk space; at least 28 GB is required'
fi

verify_file() {
    local path=$1
    local expected_size=$2
    local expected_sha=$3
    [[ -f "$path" ]] || return 1
    [[ "$(stat -Lc '%s' "$path")" == "$expected_size" ]] || return 1
    [[ "$(sha256sum -- "$path" | awk '{print $1}')" == "$expected_sha" ]]
}

download() {
    local relative=$1
    local expected_size=$2
    local expected_sha=$3
    local destination="$INSTALL_ROOT/$relative"
    local partial="$destination.part"

    mkdir -p "$(dirname -- "$destination")"
    if verify_file "$destination" "$expected_size" "$expected_sha"; then
        printf 'Reusing verified %s\n' "$relative"
        return
    fi
    rm -f -- "$destination"
    printf 'Downloading %s\n' "$relative"
    if ! curl -fL --retry 5 --retry-delay 2 --retry-connrefused -C - \
            --output "$partial" "$ASSET_BASE/$relative"; then
        printf 'Resume failed; retrying %s from the beginning\n' "$relative" >&2
        rm -f -- "$partial"
        curl -fL --retry 5 --retry-delay 2 --retry-connrefused \
            --output "$partial" "$ASSET_BASE/$relative"
    fi
    verify_file "$partial" "$expected_size" "$expected_sha" || {
        rm -f -- "$partial"
        fail "checksum or size mismatch for $relative"
    }
    mv -- "$partial" "$destination"
}

install_local_file() {
    local source=$1
    local relative=$2
    local expected_size=$3
    local expected_sha=$4
    local destination="$INSTALL_ROOT/$relative"

    source=$(readlink -f -- "$source")
    [[ -f "$source" ]] || fail "local source is missing: $source"
    verify_file "$source" "$expected_size" "$expected_sha" || fail "local source failed verification: $source"
    if [[ "$(readlink -f -- "$destination" 2>/dev/null || true)" == "$source" ]]; then
        return
    fi
    rm -f -- "$destination"
    if ! ln -- "$source" "$destination" 2>/dev/null; then
        cp --reflink=auto -- "$source" "$destination"
    fi
    verify_file "$destination" "$expected_size" "$expected_sha" || fail "installed local file failed verification: $relative"
}

printf 'Installing Treebeard %s %s for %s (%s)\n' "$VERSION" "$REVISION" "$BACKEND" "$arch"
printf 'Destination: %s\n' "$INSTALL_ROOT"

if [[ -n "${TREEBEARD_MODEL_FILE:-}" ]]; then
    install_local_file "$TREEBEARD_MODEL_FILE" "$MODEL" "$MODEL_SIZE" "$MODEL_SHA"
else
    download "$MODEL" "$MODEL_SIZE" "$MODEL_SHA"
fi
download "$RUNTIME_PATH" "$RUNTIME_SIZE" "$RUNTIME_SHA"
download run.sh 14341 "$RUN_SHA"
download treebeard 3089 "$CLI_SHA"

if [[ "$MULTIMODAL" == 1 ]]; then
    if [[ -n "${TREEBEARD_MMPROJ_FILE:-}" ]]; then
        install_local_file "$TREEBEARD_MMPROJ_FILE" "$MMPROJ" "$MMPROJ_SIZE" "$MMPROJ_SHA"
    else
        download "$MMPROJ" "$MMPROJ_SIZE" "$MMPROJ_SHA"
    fi
fi

chmod 0755 "$INSTALL_ROOT/run.sh" "$INSTALL_ROOT/treebeard"
printf '%s  %s\n' "$RUNTIME_SHA" "$RUNTIME_PATH" > "$INSTALL_ROOT/runtime/SHA256SUMS"
{
    printf '%s  %s\n' "$MODEL_SHA" "$MODEL"
    printf '%s  %s\n' "$RUNTIME_SHA" "$RUNTIME_PATH"
    printf '%s  %s\n' "$RUN_SHA" run.sh
    printf '%s  %s\n' "$CLI_SHA" treebeard
    if [[ "$MULTIMODAL" == 1 ]]; then
        printf '%s  %s\n' "$MMPROJ_SHA" "$MMPROJ"
    fi
} > "$INSTALL_ROOT/INSTALL-SHA256SUMS"
(cd "$INSTALL_ROOT" && sha256sum --check INSTALL-SHA256SUMS >/dev/null)

wrapper="$BIN_DIR/.treebeard.tmp.$$"
{
    printf '#!/usr/bin/env bash\n'
    printf 'exec %q "$@"\n' "$INSTALL_ROOT/treebeard"
} > "$wrapper"
chmod 0755 "$wrapper"
mv -- "$wrapper" "$BIN_DIR/treebeard"

printf '\nTreebeard is installed and verified.\n'
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    printf 'Add %s to PATH, or run %s directly.\n' "$BIN_DIR" "$BIN_DIR/treebeard"
fi
printf 'Run: %s doctor\n' "$BIN_DIR/treebeard"
printf 'Then: %s serve\n' "$BIN_DIR/treebeard"
printf 'API: http://127.0.0.1:8093/v1\n'
