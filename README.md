# Treebeard

Linux package for **Qwen3.6-35B-A3B**: Q5_K_XL GGUF, platform runtimes (Intel SYCL,
NVIDIA CUDA, portable CPU), installer, and local `llama-server` with
`/v1/chat/completions` on loopback by default.

[Site](https://newjordan.github.io/treebeard/) ·
[MoE notes](https://newjordan.github.io/treebeard/moe-routing.html) ·
[HF model](https://huggingface.co/Frosty40/Treebeard-Qwen3.6-35B-A3B-GGUF) ·
[Claims rule](docs/CLAIMS.md)

![Agent Bench freeze report](docs/report-preview.png)

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/newjordan/treebeard/main/install.sh | bash
~/.local/bin/treebeard doctor
~/.local/bin/treebeard serve
```

About 26.7 GB download, resumable. Installer checks file SHA-256 (integrity of
bytes on disk). Roughly 32 GB system or unified memory. Optional vision projector:

```bash
curl -fsSL https://raw.githubusercontent.com/newjordan/treebeard/main/install.sh | \
  bash -s -- --multimodal
```

Example request:

```bash
curl http://127.0.0.1:8093/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "treebeard",
    "messages": [{"role": "user", "content": "Hello from the forest."}],
    "max_tokens": 96,
    "chat_template_kwargs": {"enable_thinking": false}
  }'
```

## Platforms

| Backend | Platform | Hardware used in validation | Host requirement |
| --- | --- | --- | --- |
| Portable CPU | Linux x86_64 | AMD Ryzen 9 5950X | glibc 2.35+ |
| Intel SYCL | Linux x86_64 | Intel Arc Pro B70 | oneAPI 2026, Level Zero |
| NVIDIA CUDA | Linux ARM64 | NVIDIA GB10 | CUDA 13, cuBLAS, driver |

NVIDIA x86_64 installs get the portable CPU runtime in this package line. Hardware
outside this table has no validation row here.

## Agent Bench freeze (named run)

| Field | Value |
| --- | --- |
| Test | tool-eval-bench 2.1.0 public 69 |
| Score | 94/100 (130/138); 63 pass, 4 partial, 2 fail; 0 request errors |
| Shape | np=1, c=262144, temp 0, thinking off, seed 42 |
| Hardware | Arc Pro B70 and NVIDIA GB10 |
| Artifacts | [results/agent/single-slot-94/](results/agent/single-slot-94/) |

## Control A/B (2026-07-28, stock Q5, B70)

Clean upstream SYCL versus Treebeard package binary + package env. Same weights
(`25233af7…c506`).

| Test | Shape | Control | Treebeard | Artifact |
| --- | --- | ---: | ---: | --- |
| tool-eval-bench 69 | np=1, c=262144, seed 42 | 91/100 | 91/100 | [agent-bench-ab REPORT](results/private-verification-20260728/agent-bench-ab-20260728T220230Z/REPORT.md) |
| ho-pack-v1.1 | np=1, seed 42 | 42/46 | 42/46 | same dir `heldout/` |
| sequential tg_p50 | np=1, c=32768, 5×2 prompts | 77.1 t/s | 88.9 t/s | [single-agent-ab](results/private-verification-20260728/single-agent-ab-20260728T213156Z/) |
| 12-agent ABA p50/agent | np=12, n_predict=96 | 6.88 | 26.33 | [base-vs-package-aba](results/private-verification-20260728/base-vs-package-aba-20260728T204515Z/) |

Multi-slot p50 is concurrent capacity. Sequential tg is the single-stream row.
Charts: [docs/assets/release-20260728/](docs/assets/release-20260728/).
Notes: [docs/RELEASE-20260728.md](docs/RELEASE-20260728.md).

## Other measurements

| Test | Result | Artifact |
| --- | ---: | --- |
| llama-bench pp4096 (GB10) | 2,026.9 tok/s | [native-bench](results/nvidia/native-bench/) |
| llama-bench tg128 (GB10) | 52.5 tok/s | same |
| Q8_0 12-col latency (Blackwell) | 33.0% lower | [attribution-q8](results/nvidia/attribution-q8/) |
| Q8_0 MoE-down latency (Blackwell) | 3.4% lower | same |
| Installed-package chat smoke (5950X) | 9.30 tok/s + exact tool call | [cpu smoke](results/cpu-linux-x86_64/smoke/) |
| 12-slot aggregate (B70 ship profile) | 194.023 tok/s | [sycl](results/sycl/) |

## CLI

```text
treebeard serve       Start the local API
treebeard doctor      Platform selection and launch command
treebeard verify      Check installed model, runtime, launch files
treebeard status      Health endpoint
treebeard report      Agent Bench report URL
treebeard help
```

```bash
TREEBEARD_CONTEXT=8192 TREEBEARD_PORT=8080 treebeard serve
TREEBEARD_PROFILE=throughput treebeard serve
TREEBEARD_BACKEND=cpu treebeard doctor
TREEBEARD_REASONING=bounded treebeard serve
TREEBEARD_SPECULATION=ngram treebeard serve
```

Default GPU quality profile: 1 slot, 262144 context. Portable CPU default: 1 slot,
32768 context. Throughput profile: 12 slots.

On Arc Pro B70, package env knobs used in the control A/B ledger include GDN
out-flat, MoE-down rows-per-sg=4, Q8 multi-col subgroups=32, expert-grouped on.
Reasoning defaults off (same shape as the freeze and control A/B).
`TREEBEARD_REASONING=bounded` allows a small budget (64 tokens GPU / 16 CPU;
override with `TREEBEARD_REASONING_BUDGET`). For experimental tools or MCP, set
`TREEBEARD_TOOLS_ROOT` to a sandbox path.

## Repository layout

- `install.sh` - Linux installer
- `package/` - package metadata and docs
- `docs/` - site and release notes
- `results/` - result files
- `source/` - NVIDIA Blackwell CUDA patch used in validation

## Integrity

- NVIDIA patch SHA-256: `c1e0780c96432059ea7a517f6ab2db935f1083da065ed0a9009a00d944c3415f`
- Installer and package files ship with `SHA256SUMS` where listed

## License

Model and tokenizer assets: Apache-2.0. llama.cpp-derived runtimes: MIT.
Unofficial packaging; not an official Qwen, Intel, NVIDIA, Hugging Face, or
llama.cpp product.
