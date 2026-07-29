# Treebeard

Linux package for **Qwen3.6-35B-A3B**: Q5_K_XL GGUF, platform runtimes (Intel SYCL /
NVIDIA CUDA / portable CPU), installer, and a local **OpenAI-compatible**
`llama-server` (HTTP `/v1/chat/completions` on loopback by default).

Not a new foundation model. Not “94-verified software” — 94/100 is a **named
Agent Bench freeze** with result JSONs, not a property of every install.

**Claims rule:** [docs/CLAIMS.md](docs/CLAIMS.md) — no bare datapoints.

**[Site / report](https://newjordan.github.io/treebeard/)** ·
**[MoE notes](https://newjordan.github.io/treebeard/moe-routing.html)** ·
**[HF model](https://huggingface.co/Frosty40/Treebeard-Qwen3.6-35B-A3B-GGUF)** ·
**[GitHub](https://github.com/newjordan/treebeard)**

![Treebeard Agent Bench report](docs/report-preview.png)

## Install

Installer downloads are SHA-256 checked (file integrity, not agent quality):

```bash
curl -fsSL https://raw.githubusercontent.com/newjordan/treebeard/main/install.sh | bash
~/.local/bin/treebeard doctor
~/.local/bin/treebeard serve
```

The text install downloads about 26.7 GB and needs roughly 32 GB of system or
unified memory. Downloads resume after interruption, and every installed file
is verified by SHA-256. Add the optional 0.9 GB vision projector with:

```bash
curl -fsSL https://raw.githubusercontent.com/newjordan/treebeard/main/install.sh | \
  bash -s -- --multimodal
```

The installed server exposes an OpenAI-compatible local API:

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

## Validated platforms

| Backend | Platform | Validated hardware | Host requirement |
| --- | --- | --- | --- |
| Portable CPU | Linux x86_64 | AMD Ryzen 9 5950X | glibc 2.35+ |
| Intel SYCL | Linux x86_64 | Intel Arc Pro B70 | oneAPI 2026 and Level Zero |
| NVIDIA CUDA | Linux ARM64 | NVIDIA GB10 | CUDA 13 runtime, cuBLAS, compatible driver |

The NVIDIA-accelerated package is the ARM64 GB10 path validated for this
release. NVIDIA x86_64 hosts automatically receive the portable CPU runtime;
GPU acceleration for that platform is not included in RC3. Hardware outside
this table is unverified even when it starts successfully.

The model weights are one 26.6 GB GGUF file. Running that file still requires
architecture-specific software, so Treebeard installs the matching runtime
beside it rather than presenting a universal binary as a platform guarantee.

## Named Agent Bench freeze (not every install)

| Field | Value |
| --- | --- |
| Test | tool-eval-bench 2.1.0 public 69 |
| Score | **94/100** (130/138) · 63 pass / 4 partial / 2 fail · 0 request errors |
| Shape | np=1 · c=262144 · temp 0 · thinking off · seed 42 |
| Hardware | Intel Arc Pro B70 + NVIDIA GB10 (independent replica) |
| Artifacts | [results/agent/single-slot-94/](results/agent/single-slot-94/) (`result.json`, `nvidia-result.json`) |

Matched **stock Q5** control A/B on 2026-07-28 scored **91 on both arms** (below) — different pin/quant context from the freeze.

## Control A/B ledger (2026-07-28, stock Q5, B70)

| Test | Shape | Control | Treebeard | Artifact |
| --- | --- | ---: | ---: | --- |
| tool-eval-bench 69 | np=1 · c=262144 · seed 42 | 91/100 | 91/100 | [agent-bench-ab-…/REPORT.md](results/private-verification-20260728/agent-bench-ab-20260728T220230Z/REPORT.md) |
| ho-pack-v1.1 | np=1 · seed 42 | 42/46 | 42/46 | same · `heldout/` |
| sequential tg_p50 | np=1 · c=32768 · 5×2 prompts | 77.1 t/s | 88.9 t/s | [single-agent-ab-…](results/private-verification-20260728/single-agent-ab-20260728T213156Z/) |
| 12-agent ABA p50/agent | np=12 · n_predict=96 | 6.88 | 26.33 | [base-vs-package-aba-…](results/private-verification-20260728/base-vs-package-aba-20260728T204515Z/) |

Multi-slot is concurrent capacity, not single-user chat. Charts: [docs/assets/release-20260728/](docs/assets/release-20260728/).  
Notes: [docs/RELEASE-20260728.md](docs/RELEASE-20260728.md) · [docs/CLAIMS.md](docs/CLAIMS.md).

## Other measurements (each has an artifact)

| Test | Result | Artifact |
| --- | ---: | --- |
| llama-bench pp4096 (GB10) | 2,026.9 tok/s | [results/nvidia/native-bench/](results/nvidia/native-bench/) |
| llama-bench tg128 (GB10) | 52.5 tok/s | same |
| Q8_0 12-col latency (Blackwell) | 33.0% lower | [results/nvidia/attribution-q8/](results/nvidia/attribution-q8/) |
| Q8_0 MoE-down latency (Blackwell) | 3.4% lower | same |
| Installed-package chat smoke (5950X) | 9.30 tok/s + exact tool call | [results/cpu-linux-x86_64/smoke/](results/cpu-linux-x86_64/smoke/) |
| 12-slot aggregate (B70 ship profile) | 194.023 tok/s | [results/sycl/](results/sycl/) · package BENCHMARKS |

## CLI

```text
treebeard serve       Start the OpenAI-compatible API
treebeard doctor      Check platform selection and print the launch command
treebeard verify      Verify installed model, runtime, and launch files
treebeard status      Query the local health endpoint
treebeard report      Print the agent benchmark URL
treebeard help
```

Quality mode is the default. Use environment variables to tune it:

```bash
TREEBEARD_CONTEXT=8192 TREEBEARD_PORT=8080 treebeard serve
TREEBEARD_PROFILE=throughput treebeard serve
TREEBEARD_BACKEND=cpu treebeard doctor
TREEBEARD_REASONING=bounded treebeard serve
TREEBEARD_SPECULATION=ngram treebeard serve
```

The validated GPU quality profile uses one slot and 262,144 total context
tokens. The portable CPU default is one slot and 32,768 context tokens. The
GPU throughput profile uses 12 slots and is separate from the single-slot
evaluation above.

On Intel Arc Pro B70 (SYCL), `treebeard serve` can pin package env knobs used in
the control A/B ledger (GDN out-flat, MoE-down rows-per-sg=4, Q8 multi-col
subgroups=32, expert-grouped on; graph/pipeline/grouped off). See
[docs/RELEASE-20260728.md](docs/RELEASE-20260728.md) and the private-verification
reports for measured outcomes — do not treat env names as scores.

Reasoning is **off by default** (same shape as the named Agent Bench freeze and
the 2026-07-28 control A/B). `TREEBEARD_REASONING=bounded` enables a small
thinking allowance (64 tokens GPU / 16 CPU, overridable via
`TREEBEARD_REASONING_BUDGET`). `unrestricted` removes the budget and can raise
latency and token cost. Per-request chat-template controls still apply.

Experimental built-in tools / MCP: set `TREEBEARD_TOOLS_ROOT` to a sandbox
allowlist when enabling; production ship may keep `--tools` off until opt-in.

For selective thinking on the default-off server, enable and bound the exact
OpenAI-compatible request:

```bash
curl -s http://127.0.0.1:8093/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "treebeard",
    "messages": [{"role": "user", "content": "Check this plan for a subtle race."}],
    "max_tokens": 256,
    "chat_template_kwargs": {"enable_thinking": true},
    "thinking_budget_tokens": 64
  }'
```

`max_tokens` covers the reasoning tokens and final answer together. Agentic
tool loops issue another completion after each tool result, so each model turn
receives a fresh thinking budget; budget the full loop, not just one request.
The packaged runtime honors the selective example because the default-off
launcher leaves the global budget unrestricted for explicit requests. A
globally bounded server works, but a smaller per-request override of that
global budget requires a rebuilt runtime with the newer request-precedence
fix. Newer Anthropic thinking-control translations likewise are not present in
the packaged runtime; the example above is the supported selective path.

Speculative decoding is also opt-in through
`TREEBEARD_SPECULATION=off|ngram|mtp|hybrid`. The `ngram` mode uses a
conservative prompt-reuse configuration. `mtp` uses Qwen3.6's native one-layer
MTP head, and `hybrid` tries n-gram reuse before MTP. These modes use features
present in the packaged runtime, but they have not been validated as a
Treebeard speedup. Acceptance rate, latency, memory use, and quality must be
measured on the intended workload.

## Repository map

- `install.sh` - public resumable, verified Linux installer;
- `package/` - launcher, CLI, profiles, package contract, and benchmark docs;
- `docs/` - static agent benchmark report and MoE routing explainer;
- `results/` - checksum-pinned performance and evaluation evidence;
- `source/` - the exact NVIDIA Blackwell CUDA patch used for validation;
- [Hugging Face model package](https://huggingface.co/Frosty40/Treebeard-Qwen3.6-35B-A3B-GGUF)
  - model, projector, standard Qwen metadata, runtimes, and manifests.

## Integrity and provenance

- Treebeard integration commit: `c7091b65be49a3208e110b303433992c390a088f`;
- model SHA-256: `25233af7642e3a91bd52cc4aeefdbd4a117479088e06cf1aea5b6bedb443c506`;
- NVIDIA patch SHA-256: `c1e0780c96432059ea7a517f6ab2db935f1083da065ed0a9009a00d944c3415f`;
- base model: `Qwen/Qwen3.6-35B-A3B`;
- GGUF source: `unsloth/Qwen3.6-35B-A3B-GGUF`.

The published evidence remains checksum-pinned so the reported results can be
verified independently. Product, package, installer, and report surfaces use
the Treebeard name consistently.

## Security and license

The server binds to loopback by default. Do not expose it publicly without an
authenticated TLS proxy and firewall rules. The benchmark tool implementations
are deterministic mocks; production integrations still need authorization,
argument validation, side-effect confirmation, sandboxing, and audit logs.

Model and tokenizer assets are Apache-2.0. llama.cpp-derived runtimes are MIT.
See `LICENSE`, `LICENSE-RUNTIME`, and `NOTICE.md`. Treebeard is not an official
Qwen, Unsloth, NVIDIA, Intel, Hugging Face, or llama.cpp release.
