# Package contract

Model package: <https://huggingface.co/Frosty40/Treebeard-Qwen3.6-35B-A3B-GGUF>

GitHub repository: <https://github.com/newjordan/treebeard>

MoE algorithm explainer: <https://newjordan.github.io/treebeard/moe-routing.html>

Treebeard pkg3 follows a standard Hugging Face GGUF layout. The complete GGUF
model and official Qwen configuration and tokenizer files live at repository
root. Runtimes, launch tools, and evidence are additive directories.

## User paths

There are two supported ways to use the package:

1. `install.sh` downloads the one model file and the single runtime selected
   for the host. This is the smallest and easiest installation path.
2. A full repository download includes every runtime, the optional projector,
   all standard model metadata, and all evidence. It is self-contained after
   download and does not fetch weights at launch time.

The installed `treebeard` command provides `serve`, `doctor`, `verify`,
`status`, `report`, and `version` commands. `run.sh` remains the direct launcher
and accepts additional llama-server arguments.

The CLI invokes packaged shell components through `bash`, so full-package
downloads remain usable when an archive client does not preserve executable
permission bits. `bash ./treebeard serve` is always a valid entry point.

## Required root files

- `Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf`;
- `mmproj-F16.gguf` for the full multimodal package;
- `config.json`, `generation_config.json`, and `configuration.json`;
- `tokenizer.json`, `tokenizer_config.json`, `vocab.json`, and `merges.txt`;
- `chat_template.jinja`;
- `preprocessor_config.json` and `video_preprocessor_config.json`;
- `install.sh`, `treebeard`, `run.sh`, and `verify.sh`;
- `PACKAGE.json`, `SHA256SUMS`, and `runtime/SHA256SUMS`.

## Runtime selection

`run.sh` and `install.sh` use the same ordered selection:

1. CUDA on Linux ARM64 when a working NVIDIA device is present;
2. SYCL on Linux x86_64 when a Level Zero GPU is present;
3. the portable CPU runtime on Linux x86_64.

Explicit selection uses `TREEBEARD_BACKEND=cpu|sycl|cuda`. The CPU runtime was
built on Ubuntu 22.04 with GCC 11, glibc 2.35, `GGML_NATIVE=OFF`, dynamic backend
loading, and 14 x86_64 CPU variants. The runtime selects the best compatible
variant on the destination host.

The selected archive is SHA-256 verified and extracted under the user cache.
Its internal manifest is checked on first extraction. The launcher never
silently selects an unsupported architecture.

## Verification

`verify.sh` checks the complete repository against `SHA256SUMS`. The installer
creates `INSTALL-SHA256SUMS` for the selected subset, and `treebeard verify`
checks the appropriate manifest automatically.

`run.sh` checks exact model size at each launch and verifies its hash once per
stable device/inode/size/mtime fingerprint by default. Set
`TREEBEARD_VERIFY=always` to rehash it on every launch. Runtime archives are
always hashed before extraction.

## Compatibility

| Directory | Target | External requirement |
| --- | --- | --- |
| `runtime/cpu-linux-x86_64` | Linux x86_64 | glibc 2.35+ |
| `runtime/sycl-linux-x86_64` | Linux x86_64 | Intel oneAPI 2026 and Level Zero |
| `runtime/cuda-linux-aarch64` | Linux ARM64 | CUDA 13 runtime, cuBLAS, and compatible NVIDIA driver |

The CUDA and SYCL archives use vendor libraries installed on the host. GPU
toolkits are not redistributed. NVIDIA x86_64 acceleration is not included in
RC3; those systems select the portable CPU runtime.

Adding another target requires a runtime directory, an entry in
`runtime/SHA256SUMS`, build provenance, internal file hashes, CPU-oracle
correctness where applicable, and a real server/API package smoke test.

## Resource contract

- text install download: about 26.7 GB;
- multimodal add-on: about 0.9 GB;
- minimum memory check: 32 GB, with an explicit low-memory override;
- default CPU profile: 32,768 context tokens and one slot;
- default validated GPU profile: 262,144 context tokens and one slot.

The model supports up to 262,144 context tokens, but actual usable context is
bounded by available device or system memory. The launcher exposes overrides
instead of claiming every host can sustain the maximum profile.

## Reasoning and speculative decoding

The validated profiles retain their existing context, slot, batch, and KV
settings. Reasoning and speculation are independent, explicit controls layered
on those resource profiles:

| Setting | Behavior |
| --- | --- |
| `TREEBEARD_REASONING=off` | Default. Disables thinking in the server template while preserving explicit per-request overrides. |
| `TREEBEARD_REASONING=bounded` | Enables thinking with a default 64-token GPU or 16-token CPU budget. |
| `TREEBEARD_REASONING=unrestricted` | Enables thinking without a token budget. |
| `TREEBEARD_SPECULATION=off` | Default. Leaves the runtime's no-speculation default unchanged. |
| `TREEBEARD_SPECULATION=ngram` | Conservative `ngram-map-k` prompt-reuse drafting. |
| `TREEBEARD_SPECULATION=mtp` | Conservative two-token drafting with the model's native MTP head. |
| `TREEBEARD_SPECULATION=hybrid` | Tries n-gram drafting first, then native MTP. |

Set `TREEBEARD_REASONING_BUDGET` to a positive integer to override the bounded
default. The off setting is the server default; API clients can still opt an
individual request into thinking with request-level chat-template and budget
controls. Qwen3.6's native one-layer MTP head is carried by the GGUF, so `mtp`
and `hybrid` do not require another model. Additional `llama-server` arguments
may still be appended after `treebeard serve` for controlled experiments.

On the packaged runtime, selective OpenAI-compatible thinking must set both
`chat_template_kwargs.enable_thinking=true` and `thinking_budget_tokens=N` on
the request while the launcher remains in its default `off` mode. The request's
`max_tokens` limit includes both thought and answer tokens, and every model
turn after a tool result starts with a fresh budget. Global bounded reasoning
works here, but overriding that global budget with a smaller request budget
requires the newer request-precedence fix. The packaged runtime also
predates newer Anthropic thinking-control translations; they are not claimed
for this release.

The package makes no default speculative speed claim. N-gram hit rate, MTP
acceptance, verification cost, memory pressure, and reasoning quality are
workload-dependent and need matched evaluation before deployment.
