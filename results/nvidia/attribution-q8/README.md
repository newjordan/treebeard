# Treebeard CUDA Q8_0 attribution

The final NVIDIA Blackwell path passed correctness and improved both shipping
12-column Q8_0 dispatches on the NVIDIA GB10:

| Operation | Fallback median | Candidate median | Improvement |
| --- | ---: | ---: | ---: |
| Direct `MUL_MAT`, 512 x 12 x 256 | 5.22 us | 3.97 us | **31.49%** |
| MoE down `MUL_MAT_ID`, 2048 x 12 x 512 | 463.06 us | 445.20 us | **4.01%** |

Seven waves alternated fallback and candidate order. The fallback was selected
with `GGML_CUDA_DISABLE_MMVQ_12COL=1`; the executable and every other runtime
setting were identical. `summary.json` contains all per-wave values.

The final source deliberately keeps Q5_K and Q6_K on the existing path. A
broader preliminary run found no reliable gain for those types.
