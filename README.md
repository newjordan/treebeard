# Treebeard

Treebeard is a ready-to-run Linux distribution of Qwen3.6-35B-A3B: one
Q5_K_XL GGUF, platform runtimes, an OpenAI-compatible server, a one-command
installer, and the raw data behind its published benchmarks.

**[View the 94/100 benchmark report](https://newjordan.github.io/treebeard/)**
| **[Explore the MoE routing flow](https://newjordan.github.io/treebeard/moe-routing.html)**
| **[Download the full model package](https://huggingface.co/Frosty40/Treebeard-Qwen3.6-35B-A3B-GGUF)**

![Treebeard agent benchmark report](docs/report-preview.png)

## Install

Linux users can install the model and the best packaged runtime for their host
with one command:

```bash
curl -fsSL https://raw.githubusercontent.com/newjordan/treebeard/main/install.sh | bash
~/.local/bin/treebeard doctor
~/.local/bin/treebeard serve
```

The text install downloads about 26.7 GB and needs roughly 32 GB of system or
unified memory. Downloads resume after interruption and every installed file is
verified by SHA-256. Add the optional 0.9 GB vision projector with:

```bash
curl -fsSL https://raw.githubusercontent.com/newjordan/treebeard/main/install.sh | \
  bash -s -- --multimodal
```

Then call the local API:

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

## What works in RC3

| Backend | Platform | Validated hardware | Host requirement |
| --- | --- | --- | --- |
| Portable CPU | Linux x86_64 | AMD Ryzen 9 5950X | glibc 2.35+ |
| Intel SYCL | Linux x86_64 | Intel Arc Pro B70 | oneAPI 2026 and Level Zero |
| NVIDIA CUDA | Linux ARM64 | NVIDIA GB10 | CUDA 13 runtime, cuBLAS, compatible driver |

The NVIDIA-accelerated package is the ARM64 GB10 path tested for this release.
NVIDIA x86_64 hosts automatically receive the portable CPU runtime; GPU
acceleration for that platform is not claimed yet. Hardware outside this table
is unverified even when it starts.

The model weights themselves are one 26.6 GB GGUF file. Running that file still
requires architecture-specific software, so Treebeard installs the matching
runtime beside it rather than marketing a false universal single binary.

## Result

Treebeard scored **94/100 (Excellent)** and 130/138 points on a complete
69-scenario agent and tool-use suite:

- 63 pass, 4 partial, 2 fail;
- 69/69 completed with zero request errors;
- one server slot, one benchmark worker, 262,144-token context;
- temperature 0, thinking disabled, seed 42;
- exact score and verdict-vector reproduction on Intel Arc Pro B70 and NVIDIA
  GB10.

The warm dark-mode report links directly to both raw result files. This repository also
contains the [complete curated evidence index](results/README.md), including
NVIDIA correctness and performance, Intel serving data, the CPU package smoke,
guard logs, hashes, and reproduction scripts.

Selected measurements:

| Measurement | Result |
| --- | ---: |
| NVIDIA GB10 native pp4096 | 2,422.325 tok/s |
| NVIDIA GB10 native tg128 | 59.614 tok/s |
| NVIDIA Blackwell Q8_0 direct 12-column speedup | 31.49% |
| NVIDIA Blackwell Q8_0 MoE down speedup | 4.01% |
| Intel B70 12-slot aggregate serving | 194.023 tok/s |
| Ryzen 5950X installed-package chat smoke | 9.30 tok/s |

## CLI

```text
treebeard serve       Start the OpenAI-compatible API
treebeard doctor      Check platform selection and print the launch command
treebeard verify      Verify installed model, runtime, and launch files
treebeard status      Query the local health endpoint
treebeard report      Print the benchmark report URL
treebeard help
```

Quality mode is the default. Use environment variables to tune it:

```bash
TREEBEARD_CONTEXT=8192 TREEBEARD_PORT=8080 treebeard serve
TREEBEARD_PROFILE=throughput treebeard serve
TREEBEARD_BACKEND=cpu treebeard doctor
```

The validated GPU quality profile uses one slot and 262,144 total context
tokens. The portable CPU default is one slot and 32,768 context tokens. The GPU
throughput profile uses 12 slots and is not the configuration behind the
single-slot 94.

## Repository map

- `install.sh` - public resumable, verified Linux installer;
- `package/` - launcher, CLI, profiles, package contract, and benchmark docs;
- `docs/` - static dark-mode report and directly linked evidence;
- `results/` - raw agent, CPU, Intel, and NVIDIA results;
- `source/` - the exact NVIDIA Blackwell CUDA patch used for validation;
- [Hugging Face model package](https://huggingface.co/Frosty40/Treebeard-Qwen3.6-35B-A3B-GGUF)
  - model, projector, standard Qwen metadata, all runtimes, and full manifests.

## Integrity and provenance

- Treebeard integration commit: `6a6dc2def952fe5e9b2da81e638968653b6be3db`;
- model SHA-256: `25233af7642e3a91bd52cc4aeefdbd4a117479088e06cf1aea5b6bedb443c506`;
- NVIDIA patch SHA-256: `c1e0780c96432059ea7a517f6ab2db935f1083da065ed0a9009a00d944c3415f`;
- base model: `Qwen/Qwen3.6-35B-A3B`;
- GGUF source: `unsloth/Qwen3.6-35B-A3B-GGUF`.

Historical raw evidence retains its original run aliases so its hashes remain
verifiable. All current product, package, installer, and report surfaces use
the Treebeard name.

## Security and license

The server binds to loopback by default. Do not expose it publicly without an
authenticated TLS proxy and firewall rules. Agent benchmark tools are
deterministic mocks; production tools still need authorization, argument
validation, side-effect confirmation, sandboxing, and audit logs.

Model and tokenizer assets are Apache-2.0. llama.cpp-derived runtimes are MIT.
See `LICENSE`, `LICENSE-RUNTIME`, and `NOTICE.md`. Treebeard is not an official
Qwen, Unsloth, NVIDIA, Intel, Hugging Face, or llama.cpp release.
