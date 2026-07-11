# Notices

## Model and tokenizer

The model architecture, configuration, tokenizer, processor metadata, chat
template, and original model weights are derived from
`Qwen/Qwen3.6-35B-A3B` and are licensed under Apache License 2.0. The packaged
GGUF quantization and F16 projector were obtained from the pinned
`unsloth/Qwen3.6-35B-A3B-GGUF` revision recorded in `PACKAGE.json`.

## Runtime

The runtime archives contain software derived from llama.cpp and ggml under
the MIT License. The runtime license is reproduced in `LICENSE-RUNTIME`.

Treebeard changes in RC3 cover SYCL Q8_0 12-column matrix-vector dispatch,
shape-aware fused MoE workgroup packing, and a narrowly gated NVIDIA Blackwell
Q8_0 12-column CUDA dispatch. The exact source patch and checksum are included
under `evidence/nvidia/source`.

Pkg3 also includes a portable Linux x86_64 CPU build. It changes packaging and
host coverage, not model weights or model behavior.

## Trademarks and affiliation

Qwen, NVIDIA, CUDA, Intel, oneAPI, Hugging Face, Unsloth, llama.cpp, and other
names may be trademarks of their respective owners. This package is not an
official release of, or endorsed by, those projects or companies.
