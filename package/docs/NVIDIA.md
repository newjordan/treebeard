# NVIDIA validation

## Target

- NVIDIA GB10, compute capability 12.1;
- 128 GB unified memory;
- NVIDIA driver 580.159.03;
- CUDA toolkit 13.3;
- Ubuntu 24.04, Linux ARM64;
- runtime base source `0424f677fbcba1a001fcc115bb405e40e917de85`;
- integrated Treebeard source `6a6dc2def952fe5e9b2da81e638968653b6be3db`.

## Build

```bash
cmake -S . -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_CUDA=ON \
  -DCMAKE_CUDA_ARCHITECTURES=121 \
  -DGGML_NATIVE=ON \
  -DBUILD_SHARED_LIBS=ON \
  -DLLAMA_CURL=OFF \
  -DLLAMA_BUILD_NUMBER=9624 \
  -DLLAMA_BUILD_COMMIT=0424f677f
cmake --build build --target llama-server llama-bench test-backend-ops -j 12
```

## Gates

1. Compare CUDA `MUL_MAT` and `MUL_MAT_ID` against the CPU oracle.
2. Run native prompt-processing and token-generation benchmarks on the pinned
   Q5_K_XL model.
3. Start the packaged server with the quality profile.
4. Verify `/health`, `/props`, `/v1/models`, chat completion, and tool calling.
5. Scan the kernel journal and NVIDIA health state for faults, resets, Xids,
   hangs, and OOM events.
6. Build the ARM64 CUDA archive, verify its internal manifest, then exercise
   `run.sh` from the full model package.

## Results

| Gate | Result |
| --- | ---: |
| `MUL_MAT` correctness | 1,104 / 1,104 |
| `MUL_MAT_ID` correctness | 796 / 796 |
| Q8_0 direct 12-column | 31.49% faster median |
| Q8_0 MoE down | 4.01% faster median |
| pp4096 | 2,422.325 tok/s |
| tg128 | 59.614 tok/s |
| Agent quality, one slot | 94 / 100 |
| Request errors | 0 / 69 |
| Packaged vision answer | `94` |

The final seven-wave attribution alternated fallback and candidate order. Set
`GGML_CUDA_DISABLE_MMVQ_12COL=1` to select the fallback. The shipping extension
is restricted to Q8_0 on NVIDIA Blackwell; Q5_K and Q6_K use the existing path.

The CUDA runtime archive SHA-256 is
`0dfadb9ed53c66ab5a23b6731988d833b223af4e51c8f11ad9522a95eb0f04f3`.
It requires system CUDA 13 `libcudart`, cuBLAS, a compatible NVIDIA driver, and
glibc-compatible Linux ARM64.

The 262,144-token text profile passed the complete agent suite. The bundled
projector was validated at 32,768 tokens while another 58 GB GPU service was
resident; this avoided disturbing that unrelated service and completed with a
clean kernel-health scan.

Final counts, timings, hashes, and logs are recorded under `evidence/nvidia`.
The standalone public report is <https://newjordan.github.io/treebeard/>.

RC3's packaged CUDA target is Linux ARM64. It does not claim NVIDIA x86_64 GPU
support; Linux x86_64 hosts use the separately validated portable CPU runtime.
