#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE=/home/frosty40/turbo/worktrees/treebeard-nvidia-rc3
ROOT=/home/frosty40/turbo/results/treebeard-0.1.0-rc.3/20260711-release/linux/cpu-x86_64
VERSION=0.1.0-rc.3
ARCHIVE_NAME=treebeard-0.1.0-rc.3-b9624-pkg3-cpu-ubuntu22.04-linux-x86_64.tar.gz

mkdir -p "$ROOT"

docker run --rm \
    -e HOST_UID="$(id -u)" \
    -e HOST_GID="$(id -g)" \
    -e VERSION="$VERSION" \
    -e ARCHIVE_NAME="$ARCHIVE_NAME" \
    -v "$SOURCE:/src:ro" \
    -v "$ROOT:/work" \
    ubuntu:22.04 bash -lc '
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    build-essential ca-certificates cmake gzip jq libssl-dev ninja-build pkg-config

BUILD=/work/build
STAGE=/work/stage
INSTALL="$STAGE/root/opt/treebeard-$VERSION"
ARCHIVE=/work/$ARCHIVE_NAME

rm -rf "$BUILD" "$STAGE" "$ARCHIVE" "$ARCHIVE.tmp1" "$ARCHIVE.tmp2"
cmake -S /src -B "$BUILD" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DGGML_NATIVE=OFF \
    -DGGML_BACKEND_DL=ON \
    -DGGML_CPU_ALL_VARIANTS=ON \
    -DLLAMA_BUILD_NUMBER=9624 \
    -DLLAMA_BUILD_COMMIT=6a6dc2def-cpu \
    -DLLAMA_BUILD_UI=OFF \
    -DLLAMA_USE_PREBUILT_UI=OFF \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=OFF \
    -DLLAMA_BUILD_APP=OFF \
    -DLLAMA_CURL=OFF
cmake --build "$BUILD" --target llama-server llama-bench llama-mtmd-cli -j "$(nproc)"

mkdir -p "$STAGE/root"
install_tree() {
    local script="$1"
    shift
    env DESTDIR="$STAGE/root" cmake \
        -DCMAKE_INSTALL_PREFIX="/opt/treebeard-$VERSION" \
        -DCMAKE_INSTALL_CONFIG_NAME=Release \
        -DCMAKE_INSTALL_DO_STRIP=1 \
        "$@" \
        -P "$script"
}

install_tree "$BUILD/ggml/cmake_install.cmake"
install_tree "$BUILD/cmake_install.cmake" -DCMAKE_INSTALL_LOCAL_ONLY=1
install_tree "$BUILD/tools/mtmd/cmake_install.cmake"
install_tree "$BUILD/tools/server/cmake_install.cmake"
install_tree "$BUILD/tools/llama-bench/cmake_install.cmake"
install -m 0644 /src/LICENSE "$INSTALL/LICENSE"

grep -E "^(BUILD_SHARED_LIBS|CMAKE_BUILD_TYPE|CMAKE_CXX_COMPILER|GGML_BACKEND_DL|GGML_CPU_ALL_VARIANTS|GGML_NATIVE|LLAMA_BUILD_COMMIT|LLAMA_BUILD_NUMBER|LLAMA_BUILD_UI|LLAMA_CURL):" \
    "$BUILD/CMakeCache.txt" > "$INSTALL/BUILD-CONFIG.txt"
LD_LIBRARY_PATH="$INSTALL/lib" "$INSTALL/bin/llama-server" --version \
    > "$INSTALL/BUILD-IDENTITY.txt" 2>&1
LD_LIBRARY_PATH="$INSTALL/lib" "$INSTALL/bin/llama-bench" --list-devices \
    > "$INSTALL/DEVICES.txt" 2>&1
ldd --version | head -n 1 > "$INSTALL/GLIBC-BUILD.txt"
gcc --version | head -n 1 > "$INSTALL/COMPILER.txt"
LD_LIBRARY_PATH="$INSTALL/lib" ldd "$INSTALL/bin/llama-server" \
    > "$INSTALL/DEPENDENCIES-llama-server.txt"
! grep -F "not found" "$INSTALL/DEPENDENCIES-llama-server.txt"

jq -n \
    --arg product Treebeard \
    --arg version "$VERSION" \
    --arg source_commit 6a6dc2def952fe5e9b2da81e638968653b6be3db \
    --arg build_identity "9624 (6a6dc2def-cpu)" \
    --arg target "Linux x86_64" \
    --arg build_container "ubuntu:22.04" \
    --arg backend "CPU dynamic multi-variant" \
    "{
        product: \$product,
        version: \$version,
        packaging_revision: \"pkg3\",
        source_commit: \$source_commit,
        build_identity: \$build_identity,
        target: \$target,
        build_container: \$build_container,
        backend: \$backend,
        cpu_variants: true,
        native_cpu: false,
        minimum_tested_memory_gib: 32,
        runtime_requirements: [
            \"glibc 2.35 or newer\",
            \"Linux x86_64\",
            \"32 GiB RAM minimum, 40 GiB recommended\"
        ]
    }" > "$INSTALL/PROVENANCE.json"

printf "%s\n" \
    "Treebeard 0.1.0-rc.3 pkg3 portable CPU runtime" \
    "Target: glibc Linux x86_64" \
    "Build container: Ubuntu 22.04" \
    "Build: 9624 (6a6dc2def-cpu)" \
    "Source: 6a6dc2def952fe5e9b2da81e638968653b6be3db" \
    "Backend: dynamically selected CPU variants; GGML_NATIVE=OFF" \
    "Memory: 32 GiB minimum, 40 GiB recommended" \
    > "$INSTALL/PROVENANCE.txt"

(
    cd "$INSTALL"
    find . -type l -printf "%P -> %l\n" | LC_ALL=C sort > SYMLINKS.txt
    while IFS= read -r link; do
        [[ -e "$link" ]]
    done < <(find . -type l -print)
    find bin -maxdepth 1 -type f -name "libggml-cpu*.so*" -print \
        | LC_ALL=C sort > CPU-BACKENDS.txt
    test "$(wc -l < CPU-BACKENDS.txt)" -ge 3
    sha256sum \
        bin/llama-server \
        bin/llama-bench \
        bin/libggml-cpu-x64.so \
        lib/libllama-server-impl.so \
        lib/libllama.so.0.0.9624 \
        > COMPONENTS.sha256
    find . -type f ! -name FILES.sha256 -print0 \
        | LC_ALL=C sort -z \
        | xargs -0 sha256sum \
        > FILES.sha256
    sha256sum --check FILES.sha256 >/dev/null
)

for tmp in "$ARCHIVE.tmp1" "$ARCHIVE.tmp2"; do
    tar --sort=name \
        --format=posix \
        --pax-option=delete=atime,delete=ctime \
        --mtime="2026-07-11 00:00:00Z" \
        --owner=0 --group=0 --numeric-owner \
        -C "$STAGE/root" -cf - opt \
        | gzip -n -9 > "$tmp"
done
cmp "$ARCHIVE.tmp1" "$ARCHIVE.tmp2"
mv "$ARCHIVE.tmp1" "$ARCHIVE"
rm -f "$ARCHIVE.tmp2"
tar -xOf "$ARCHIVE" "opt/treebeard-$VERSION/PROVENANCE.json" \
    | jq -e ".product == \"Treebeard\" and .backend == \"CPU dynamic multi-variant\"" >/dev/null
(cd /work && sha256sum "$ARCHIVE_NAME" > ARCHIVE.sha256)
chown -R "$HOST_UID:$HOST_GID" /work
'

(
    cd "$ROOT"
    sha256sum --check ARCHIVE.sha256
)
printf 'TREEBEARD_CPU_RUNTIME_OK\n'
