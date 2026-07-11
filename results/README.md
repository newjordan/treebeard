# Treebeard results

Model package: <https://huggingface.co/Frosty40/Treebeard-Qwen3.6-35B-A3B-GGUF>

GitHub repository: <https://github.com/newjordan/treebeard>

MoE algorithm explainer: <https://newjordan.github.io/treebeard/moe-routing.html>

This directory contains the checksum-pinned evidence behind the RC3 claims.
The primary human-readable view is the public dark-mode
[Agent Bench report](https://newjordan.github.io/treebeard/).

## Agent Bench

- [`agent/single-slot-94/result.json`](agent/single-slot-94/result.json): Intel
  Arc Pro B70 primary 69-scenario result, 94/100;
- [`agent/single-slot-94/nvidia-result.json`](agent/single-slot-94/nvidia-result.json):
  NVIDIA GB10 independent replica, 94/100;
- [`nvidia/agent-single-slot-94/result.json`](nvidia/agent-single-slot-94/result.json):
  full NVIDIA result bundle with guard and health evidence.

Both complete runs scored 130/138 with 63 pass, 4 partial, 2 fail, and zero
request errors. The verdict for every scenario matched across backends.

## NVIDIA

- `nvidia/correctness`: 1,104/1,104 `MUL_MAT` and 796/796 `MUL_MAT_ID` CPU-oracle checks;
- `nvidia/attribution-q8`: seven-run Q8_0 kernel attribution;
- `nvidia/native-bench`: pp4096 and tg128 native benchmark JSON;
- `nvidia/package-smoke`: packaged API, tool-call, vision, and GPU-health smoke;
- `nvidia/reproduction`: exact collection and packaging scripts;
- `nvidia/source`: exact source patch and checksum.

## Intel SYCL

- `sycl/llama-bench-pp4096-tg128.json`: native model measurements;
- `sycl/pareto-result.json`: serving concurrency measurements;
- `sycl/package-dry-run.txt`: packaged launch selection.

## Portable CPU

- `cpu-linux-x86_64/build-cpu-runtime.sh`: reproducible Ubuntu 22.04 baseline build;
- `cpu-linux-x86_64/ARCHIVE.sha256`: deterministic runtime archive hash;
- `cpu-linux-x86_64/smoke/summary.json`: installed-package server, chat, and exact tool-call result;
- `cpu-linux-x86_64/smoke/run-smoke.sh`: reproduction script;
- `cpu-linux-x86_64/smoke/SHA256SUMS`: smoke artifact manifest.

Archived evidence retains collection-time paths and identifiers so its
published checksums remain reproducible. Product-facing documentation uses the
Treebeard name.
