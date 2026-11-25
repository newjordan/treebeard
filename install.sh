#!/usr/bin/env bash
set -Eeuo pipefail

VERSION=0.2.0-rc.1
REVISION=pkg5
MODEL_REPO=Frosty40/Treebeard-Qwen3.6-35B-A3B-GGUF
ASSET_BASE=${TREEBEARD_ASSET_BASE:-https://huggingface.co/$MODEL_REPO/resolve/main}
GITHUB_RAW=${TREEBEARD_GITHUB_RAW:-https://raw.githubusercontent.com/newjordan/treebeard/${TREEBEARD_GIT_REF:-main}}
INSTALL_ROOT=${TREEBEARD_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/treebeard/$VERSION-$REVISION}
BIN_DIR=${TREEBEARD_BIN_DIR:-$HOME/.local/bin}
BACKEND=${TREEBEARD_BACKEND:-auto}
MULTIMODAL=${TREEBEARD_INSTALL_MULTIMODAL:-0}
ALLOW_LOW_MEMORY=${TREEBEARD_ALLOW_LOW_MEMORY:-0}
DRY_RUN=${TREEBEARD_INSTALL_DRY_RUN:-0}
MEMINFO=${TREEBEARD_MEMINFO:-/proc/meminfo}
MIN_MEMORY_BYTES=30000000000
DISK_SLACK_BYTES=1073741824

MODEL=Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf
MODEL_SIZE=26592508896
MODEL_SHA=25233af7642e3a91bd52cc4aeefdbd4a117479088e06cf1aea5b6bedb443c506
MMPROJ=mmproj-F16.gguf
MMPROJ_SIZE=899283680
MMPROJ_SHA=8971ee4f331ff0a4c609374f32984b3d4e6dc086c0aa35f1d637fad1829e887f
RUN_SHA=890d4da5bcabc667fe9d80be99286c75e90129c97060d503f876f16a209bd354
RUN_SIZE=19048
CLI_SHA=17dd9f8b23f5a884b0c89f8c00dfa5fe729cb17a7b4cbe2eae1e4443ec2f0bb5
CLI_SIZE=4922

if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
    SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
else
    SCRIPT_DIR=
fi

usage() {
    cat <<EOF
Install Treebeard $VERSION $REVISION on Linux.

Usage: install.sh [options]

  --backend auto|cpu|sycl|cuda   Select a packaged runtime (default: auto)
  --multimodal                   Also install the F16 vision projector
  --install-dir PATH             Install package files under PATH
  --bin-dir PATH                 Put the treebeard command under PATH
  --allow-low-memory             Continue with less than 30 GB of MemTotal
  -h, --help                     Show this help

Environment:
  TREEBEARD_BACKEND              auto, cpu, sycl, or cuda
  TREEBEARD_INSTALL_MULTIMODAL   0 or 1
  TREEBEARD_INSTALL_DIR          Package directory
  TREEBEARD_BIN_DIR              Command directory
  TREEBEARD_ALLOW_LOW_MEMORY     0 or 1
  TREEBEARD_INSTALL_DRY_RUN      1 prints the selected backend and exits
  TREEBEARD_ASSET_BASE           Model and runtime download prefix
  TREEBEARD_GITHUB_RAW           Launcher script download prefix
  TREEBEARD_MODEL_FILE           Use this local model instead of downloading
  TREEBEARD_MMPROJ_FILE          Use this local projector instead of downloading
  TREEBEARD_ONEAPI_SETVARS       oneAPI setvars.sh used only for detection

A checkout install uses package/run.sh and package/treebeard beside this
script when those files match the pinned checksums. A piped install downloads
the same paths from GitHub. Model weights and runtime archives come from
Hugging Face.
EOF
}

fail() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

format_gib() {
    awk -v bytes="$1" 'BEGIN { printf "%.1f GiB", bytes / 1024 / 1024 / 1024 }'
}

memory_bytes() {
    local memory_kib
    [[ -r "$MEMINFO" ]] || fail "could not read $MEMINFO"
    memory_kib=$(awk '$1 == "MemTotal:" { print $2; exit }' "$MEMINFO")
    [[ "$memory_kib" =~ ^[0-9]+$ ]] || fail "could not read MemTotal from $MEMINFO"
    printf '%s\n' $((memory_kib * 1024))
}

filesystem_free_bytes() {
    local path=$1 blocks size
    read -r blocks size < <(stat -fc '%a %S' "$path")
    [[ "$blocks" =~ ^[0-9]+$ && "$size" =~ ^[0-9]+$ ]] || fail "could not read free space for $path"
    printf '%s\n' $((blocks * size))
}

curl_fetch() {
    local url=$1
    local destination=$2
    shift 2
    local -a proto=()
    local -a retry=(--retry 5 --retry-delay 2 --retry-connrefused)
    case "$url" in
        https://*)
            proto=(--proto '=https' --proto-redir '=https')
            ;;
        http://127.0.0.1/*|http://127.0.0.1:*|http://localhost/*|http://localhost:*)
            proto=(--proto '=http' --proto-redir '=http')
            ;;
        http://*)
            [[ "${TREEBEARD_ALLOW_INSECURE_DOWNLOAD:-0}" == 1 ]] || fail "refusing non-https URL: $url"
            proto=(--proto '=http' --proto-redir '=http')
            ;;
        *)
            fail "unsupported download URL: $url"
            ;;
    esac
    if curl --help all 2>/dev/null | grep -q -- '--retry-all-errors'; then
        retry+=(--retry-all-errors)
    fi
    curl -fL "${retry[@]}" "${proto[@]}" "$@" --output "$destination" "$url"
}

read_sycl_devices() {
    local setvars=${TREEBEARD_ONEAPI_SETVARS:-/opt/intel/oneapi/setvars.sh}
    (
        set +e
        if ! command -v sycl-ls >/dev/null 2>&1 && [[ -f "$setvars" ]]; then
            set +u
            # shellcheck disable=SC1090
            source "$setvars" --force >/dev/null 2>&1 || exit 0
        fi
        if command -v sycl-ls >/dev/null 2>&1; then
            sycl-ls 2>&1 || true
        fi
    )
}

select_backend() {
    local requested=$1
    local sycl_devices=
    requested=$(printf '%s' "$requested" | tr '[:upper:]' '[:lower:]')

    if [[ "$requested" == auto ]]; then
        if [[ "$arch" == aarch64 ]] && command -v nvidia-smi >/dev/null 2>&1 &&
                nvidia-smi -L >/dev/null 2>&1; then
            printf 'cuda\n'
            return
        fi
        if [[ "$arch" == x86_64 ]]; then
            sycl_devices=$(read_sycl_devices || true)
            if grep -Fq '[level_zero:gpu]' <<<"$sycl_devices"; then
                printf 'sycl\n'
                return
            fi
        fi
        [[ "$arch" == x86_64 ]] || fail "no packaged runtime is available for $arch"
        if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
            printf 'note: NVIDIA GPU acceleration in this package targets Linux ARM64 (GB10). Selecting the portable x86_64 CPU runtime.\n' >&2
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

verify_file() {
    local path=$1
    local expected_size=$2
    local expected_sha=$3
    [[ -f "$path" ]] || return 1
    [[ "$(stat -Lc '%s' "$path")" == "$expected_size" ]] || return 1
    [[ "$(sha256sum -- "$path" | awk '{print $1}')" == "$expected_sha" ]]
}

bytes_if_size_differs() {
    local path=$1
    local expected_size=$2
    if [[ -f "$path" && "$(stat -Lc '%s' "$path")" == "$expected_size" ]]; then
        printf '0\n'
    else
        printf '%s\n' "$expected_size"
    fi
}

download_from() {
    local url=$1
    local relative=$2
    local expected_size=$3
    local expected_sha=$4
    local destination="$INSTALL_ROOT/$relative"
    local partial="$destination.part"
    local partial_size

    mkdir -p "$(dirname -- "$destination")"
    if verify_file "$destination" "$expected_size" "$expected_sha"; then
        printf 'Reusing verified %s\n' "$relative"
        return
    fi
    rm -f -- "$destination"
    if [[ -f "$partial" ]]; then
        partial_size=$(stat -Lc '%s' "$partial")
        if (( partial_size > expected_size )); then
            rm -f -- "$partial"
        fi
    fi
    printf 'Downloading %s\n' "$relative"
    if ! curl_fetch "$url" "$partial" -C -; then
        printf 'Resume failed; retrying %s from the beginning\n' "$relative" >&2
        rm -f -- "$partial"
        curl_fetch "$url" "$partial" || fail "download failed for $relative"
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
    mkdir -p "$(dirname -- "$destination")"
    if [[ "$(readlink -f -- "$destination" 2>/dev/null || true)" == "$source" ]]; then
        return
    fi
    rm -f -- "$destination"
    if ! ln -- "$source" "$destination" 2>/dev/null; then
        cp --reflink=auto -- "$source" "$destination"
    fi
    verify_file "$destination" "$expected_size" "$expected_sha" || fail "installed local file failed verification: $relative"
}

install_launcher() {
    local name=$1
    local expected_size=$2
    local expected_sha=$3
    if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/package/$name" ]]; then
        install_local_file "$SCRIPT_DIR/package/$name" "$name" "$expected_size" "$expected_sha"
        return
    fi
    download_from "$GITHUB_RAW/package/$name" "$name" "$expected_size" "$expected_sha"
}

main() {
    local arch runtime_path runtime_size runtime_sha memory available required
    local wrapper

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

    for command in awk curl sha256sum stat tar tr uname; do
        command -v "$command" >/dev/null 2>&1 || fail "$command is required"
    done
    [[ "$(uname -s)" == Linux ]] || fail "Treebeard $VERSION $REVISION supports Linux only"
    [[ "$MULTIMODAL" == 0 || "$MULTIMODAL" == 1 ]] || fail 'TREEBEARD_INSTALL_MULTIMODAL must be 0 or 1'
    [[ "$ALLOW_LOW_MEMORY" == 0 || "$ALLOW_LOW_MEMORY" == 1 ]] || fail 'TREEBEARD_ALLOW_LOW_MEMORY must be 0 or 1'
    [[ "$DRY_RUN" == 0 || "$DRY_RUN" == 1 ]] || fail 'TREEBEARD_INSTALL_DRY_RUN must be 0 or 1'

    arch=$(uname -m)
    BACKEND=$(select_backend "$BACKEND")
    case "$BACKEND" in
        cpu)
            runtime_path=runtime/cpu-linux-x86_64/treebeard-0.2.0-rc.1-c7091b65b-pkg1-cpu-ubuntu22.04-linux-x86_64.tar.gz
            runtime_size=11186288
            runtime_sha=e91174c51f547344e35e5569542346fce35052b3dc213cf152abbfd45a777df5
            ;;
        sycl)
            runtime_path=runtime/sycl-linux-x86_64/treebeard-0.2.0-rc.1-c7091b65b-pkg1-sycl-oneapi2026-linux-x86_64.tar.gz
            runtime_size=50310098
            runtime_sha=d844ff9a21a60f7f3283d396bf4a83ef092eaf4ffec781a40d830a17e27e3358
            ;;
        cuda)
            runtime_path=runtime/cuda-linux-aarch64/treebeard-0.2.0-rc.1-c7091b65b-pkg1-cuda13.3-linux-aarch64.tar.gz
            runtime_size=49426845
            runtime_sha=e7221ed3e1e61d0158fb58d6c9152cd1217d0eecb6ad0779c81f3bc5b1f3fdc0
            ;;
    esac

    memory=$(memory_bytes)
    if (( memory < MIN_MEMORY_BYTES )) && [[ "$ALLOW_LOW_MEMORY" != 1 ]]; then
        if [[ "$DRY_RUN" == 1 ]]; then
            printf 'backend=%s\n' "$BACKEND"
            printf 'memory=blocked\n'
            printf 'error: MemTotal is %s; this package expects at least %s. Pass --allow-low-memory to continue.\n' \
                "$(format_gib "$memory")" "$(format_gib "$MIN_MEMORY_BYTES")" >&2
            exit 1
        fi
        fail "MemTotal is $(format_gib "$memory"); this package expects at least $(format_gib "$MIN_MEMORY_BYTES"). Pass --allow-low-memory to continue."
    fi
    if [[ "$DRY_RUN" == 1 ]]; then
        printf 'backend=%s\n' "$BACKEND"
        printf 'memory=ok\n'
        exit 0
    fi

    mkdir -p "$INSTALL_ROOT" "$INSTALL_ROOT/$(dirname -- "$runtime_path")" "$BIN_DIR"
    required=0
    if [[ -z "${TREEBEARD_MODEL_FILE:-}" ]]; then
        required=$((required + $(bytes_if_size_differs "$INSTALL_ROOT/$MODEL" "$MODEL_SIZE")))
    fi
    required=$((required + $(bytes_if_size_differs "$INSTALL_ROOT/$runtime_path" "$runtime_size")))
    required=$((required + $(bytes_if_size_differs "$INSTALL_ROOT/run.sh" "$RUN_SIZE")))
    required=$((required + $(bytes_if_size_differs "$INSTALL_ROOT/treebeard" "$CLI_SIZE")))
    if [[ "$MULTIMODAL" == 1 && -z "${TREEBEARD_MMPROJ_FILE:-}" ]]; then
        required=$((required + $(bytes_if_size_differs "$INSTALL_ROOT/$MMPROJ" "$MMPROJ_SIZE")))
    fi
    if (( required > 0 )); then
        required=$((required + DISK_SLACK_BYTES))
        available=$(filesystem_free_bytes "$INSTALL_ROOT")
        if (( available < required )); then
            fail "not enough free disk space in $INSTALL_ROOT (have $(format_gib "$available"), need $(format_gib "$required"))"
        fi
    fi

    printf 'Installing Treebeard %s %s for %s (%s)\n' "$VERSION" "$REVISION" "$BACKEND" "$arch"
    printf 'Destination: %s\n' "$INSTALL_ROOT"

    if [[ -n "${TREEBEARD_MODEL_FILE:-}" ]]; then
        install_local_file "$TREEBEARD_MODEL_FILE" "$MODEL" "$MODEL_SIZE" "$MODEL_SHA"
    else
        download_from "$ASSET_BASE/$MODEL" "$MODEL" "$MODEL_SIZE" "$MODEL_SHA"
    fi
    download_from "$ASSET_BASE/$runtime_path" "$runtime_path" "$runtime_size" "$runtime_sha"
    install_launcher run.sh "$RUN_SIZE" "$RUN_SHA"
    install_launcher treebeard "$CLI_SIZE" "$CLI_SHA"

    if [[ "$MULTIMODAL" == 1 ]]; then
        if [[ -n "${TREEBEARD_MMPROJ_FILE:-}" ]]; then
            install_local_file "$TREEBEARD_MMPROJ_FILE" "$MMPROJ" "$MMPROJ_SIZE" "$MMPROJ_SHA"
        else
            download_from "$ASSET_BASE/$MMPROJ" "$MMPROJ" "$MMPROJ_SIZE" "$MMPROJ_SHA"
        fi
    fi

    chmod 0755 "$INSTALL_ROOT/run.sh" "$INSTALL_ROOT/treebeard"
    printf '%s  %s\n' "$runtime_sha" "$runtime_path" > "$INSTALL_ROOT/runtime/SHA256SUMS"
    {
        printf '%s  %s\n' "$MODEL_SHA" "$MODEL"
        printf '%s  %s\n' "$runtime_sha" "$runtime_path"
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
}

# A piped `curl | bash` has an empty BASH_SOURCE. Sourcing for tests does not.
if [[ "${BASH_SOURCE[0]:-}" == "$0" || -z "${BASH_SOURCE[0]:-}" ]]; then
    main "$@"
fi
