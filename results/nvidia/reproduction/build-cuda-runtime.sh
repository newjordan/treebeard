#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=/home/frosty40/treebeard-nvidia-rc3-0424f677f
SRC="$ROOT/src-candidate"
BUILD="$ROOT/build-candidate"
VERSION=0.1.0-rc.3
PACKAGE_REVISION=pkg2
PATCH_SHA256=c1e0780c96432059ea7a517f6ab2db935f1083da065ed0a9009a00d944c3415f
STAGE="$ROOT/runtime-build/cuda"
INSTALL="$STAGE/root/opt/treebeard-$VERSION"
ARCHIVE_NAME=treebeard-0.1.0-rc.3-b9624-pkg2-cuda13.3-linux-aarch64.tar.gz
ARCHIVE_DIR="$ROOT/runtime"
ARCHIVE="$ARCHIVE_DIR/$ARCHIVE_NAME"

cmake --build "$BUILD" --target llama-server llama-bench llama-mtmd-cli -j 12
rm -rf "$STAGE"
mkdir -p "$STAGE/root" "$ARCHIVE_DIR"

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

install -m 0644 "$SRC/LICENSE" "$INSTALL/LICENSE"

grep -E '^(CMAKE_BUILD_TYPE|CMAKE_CUDA_ARCHITECTURES|CMAKE_CUDA_COMPILER|CMAKE_CXX_COMPILER|GGML_CUDA|GGML_NATIVE|LLAMA_BUILD_NUMBER|LLAMA_BUILD_COMMIT|LLAMA_CURL|BUILD_SHARED_LIBS):' \
    "$BUILD/CMakeCache.txt" > "$INSTALL/BUILD-CONFIG.txt"
"$BUILD/bin/llama-server" --version > "$INSTALL/BUILD-IDENTITY.txt" 2>&1
/usr/local/cuda/bin/nvcc --version > "$INSTALL/CUDA-COMPILER.txt"
nvidia-smi -q > "$INSTALL/NVIDIA-BUILD-HOST.txt"

LD_LIBRARY_PATH="$INSTALL/lib" ldd "$INSTALL/bin/llama-server" \
    > "$INSTALL/DEPENDENCIES-llama-server.txt"
LD_LIBRARY_PATH="$INSTALL/lib" ldd "$INSTALL/bin/llama-bench" \
    > "$INSTALL/DEPENDENCIES-llama-bench.txt"
! grep -F 'not found' "$INSTALL"/DEPENDENCIES-*.txt

jq -n \
    --arg product Treebeard \
    --arg version "$VERSION" \
    --arg package_revision "$PACKAGE_REVISION" \
    --arg source_commit 0424f677fbcba1a001fcc115bb405e40e917de85 \
    --arg source_baseline 3799687213eddbdc1389994f110fac0fa01f3e36 \
    --arg source_patch_sha256 "$PATCH_SHA256" \
    --arg build_identity '9624 (0424f677f-cuda12)' \
    --arg target 'Linux aarch64' \
    --arg backend 'CUDA 13.3' \
    --arg gpu 'NVIDIA GB10, compute capability 12.1' \
    --arg driver '580.159.03' \
    '{
        product: $product,
        version: $version,
        package_revision: $package_revision,
        source_commit: $source_commit,
        source_baseline: $source_baseline,
        source_patch_sha256: $source_patch_sha256,
        build_identity: $build_identity,
        target: $target,
        backend: $backend,
        gpu: $gpu,
        driver: $driver,
        cmake: {
            build_type: "Release",
            cuda_architectures: "121",
            shared_libraries: true,
            native_cpu: true,
            curl: false
        },
        runtime_requirements: [
            "NVIDIA driver compatible with CUDA 13",
            "CUDA 13 libcudart and cuBLAS shared libraries",
            "glibc-compatible Linux ARM64"
        ]
    }' > "$INSTALL/PROVENANCE.json"

printf '%s\n' \
    'Treebeard 0.1.0-rc.3 pkg2 NVIDIA runtime' \
    'Target: Linux aarch64, NVIDIA GB10, compute capability 12.1' \
    'Backend: CUDA 13.3, driver 580.159.03' \
    'Build: 9624 (0424f677f-cuda12)' \
    'Source: 0424f677fbcba1a001fcc115bb405e40e917de85' \
    "Source patch SHA-256: $PATCH_SHA256" \
    'Correctness: MUL_MAT 1104/1104; MUL_MAT_ID 796/796' \
    'Validated model: Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf' \
    > "$INSTALL/PROVENANCE.txt"

(
    cd "$INSTALL"
    find . -type l -printf '%P -> %l\n' | LC_ALL=C sort > SYMLINKS.txt
    while IFS= read -r link; do
        [[ -e "$link" ]]
    done < <(find . -type l -print)
    sha256sum \
        bin/llama-server \
        bin/llama-bench \
        lib/libggml-cuda.so.0.14.0 \
        lib/libllama-server-impl.so \
        lib/libllama-bench-impl.so \
        lib/libllama.so.0.0.9624 \
        lib/libmtmd.so.0.0.9624 \
        > COMPONENTS.sha256
    find . -type f ! -name FILES.sha256 -print0 \
        | LC_ALL=C sort -z \
        | xargs -0 sha256sum \
        > FILES.sha256
    sha256sum --check FILES.sha256 >/dev/null
    LD_LIBRARY_PATH="$INSTALL/lib" "$INSTALL/bin/llama-server" --version \
        > /dev/null
)

rm -f "$ARCHIVE.tmp1" "$ARCHIVE.tmp2" "$ARCHIVE"
for tmp in "$ARCHIVE.tmp1" "$ARCHIVE.tmp2"; do
    tar --sort=name \
        --format=posix \
        --pax-option=delete=atime,delete=ctime \
        --mtime='2026-07-11 00:00:00Z' \
        --owner=0 --group=0 --numeric-owner \
        -C "$STAGE/root" -cf - opt \
        | gzip -n -9 > "$tmp"
done
cmp "$ARCHIVE.tmp1" "$ARCHIVE.tmp2"
mv "$ARCHIVE.tmp1" "$ARCHIVE"
rm -f "$ARCHIVE.tmp2"

tar -xOf "$ARCHIVE" "opt/treebeard-$VERSION/PROVENANCE.json" \
    | jq -e '.product == "Treebeard" and .backend == "CUDA 13.3"' >/dev/null
sha256sum "$ARCHIVE"
printf 'TREEBEARD_CUDA_RUNTIME_OK\n'
