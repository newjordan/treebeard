# Treebeard

Linux package for **Qwen3.6-35B-A3B**. It installs a pinned Q5_K_XL GGUF, one
platform runtime (portable CPU, Intel SYCL, or NVIDIA CUDA), and a local
`llama-server` with `/v1/chat/completions` on `127.0.0.1:8093` by default.

[Site](https://newjordan.github.io/treebeard/) ·
[MoE notes](https://newjordan.github.io/treebeard/moe-routing.html) ·
[HF model](https://huggingface.co/Frosty40/Treebeard-Qwen3.6-35B-A3B-GGUF) ·
[Claims rule](docs/CLAIMS.md)

Version **0.2.0-rc.1** (packaging revision **pkg5**). Model and tokenizer
assets are Apache-2.0. The llama.cpp-derived runtimes are MIT. See `LICENSE`
and `LICENSE-RUNTIME`. This is unofficial packaging, not an official Qwen,
Intel, NVIDIA, Hugging Face, or llama.cpp product.

## Requirements

- Linux
- `bash`, `curl`, GNU `coreutils` (`sha256sum`, `stat`, `df`), `tar`, `awk`, and `flock`
- CPU runtime: Linux x86_64, glibc 2.35 or newer
- SYCL runtime: Linux x86_64, Intel oneAPI 2026, and a Level Zero GPU
- CUDA runtime: Linux ARM64, CUDA 13, cuBLAS, and a working `nvidia-smi`
- `MemTotal` of at least 30000000000 bytes (27.9 GiB), unless you pass
  `--allow-low-memory`

NVIDIA x86_64 machines install the portable CPU runtime. The installer says so
when it detects `nvidia-smi` on x86_64.

## Install

From the current `main` branch:

```bash
curl -fsSL https://raw.githubusercontent.com/newjordan/treebeard/main/install.sh | bash
treebeard doctor
treebeard serve
```

From a git checkout, the installer uses `package/run.sh` and `package/treebeard`
when their bytes match the pins in `install.sh`. Weights and runtime archives
still come from Hugging Face:

```bash
bash install.sh --backend cpu --allow-low-memory
```

See the selected backend without downloading:

```bash
TREEBEARD_INSTALL_DRY_RUN=1 bash install.sh
```

Useful installer options:

| Option | Meaning |
| --- | --- |
| `--backend auto\|cpu\|sycl\|cuda` | Runtime to download. `auto` prefers CUDA on ARM64 with a GPU, then SYCL when `sycl-ls` reports `[level_zero:gpu]`, then CPU on x86_64. |
| `--multimodal` | Also install `mmproj-F16.gguf` (899283680 bytes). |
| `--install-dir PATH` | Package directory. Default: `~/.local/share/treebeard/0.2.0-rc.1-pkg5`. |
| `--bin-dir PATH` | Where the `treebeard` wrapper is written. Default: `~/.local/bin`. |
| `--allow-low-memory` | Continue below the MemTotal gate. |

The model pin is `Qwen3.6-35B-A3B-UD-Q5_K_XL.gguf`, 26592508896 bytes,
SHA-256 `25233af7642e3a91bd52cc4aeefdbd4a117479088e06cf1aea5b6bedb443c506`.
Set `TREEBEARD_MODEL_FILE` to a local copy of that file. The installer checks
free space for every pinned file whose size is not already present, plus
1073741824 bytes of slack.

Example request after `treebeard serve`:

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

The API is unauthenticated. Keep the default loopback bind. Read `SECURITY.md`
before changing `TREEBEARD_HOST`.

## Commands

```text
treebeard serve [llama-server options]
treebeard doctor
treebeard verify
treebeard status
treebeard report
treebeard version
treebeard help
```

`doctor` prints the machine summary and the exact `llama-server` command.
`verify` checks `INSTALL-SHA256SUMS` in an install, or `SHA256SUMS` in this
repository. `status` requests `/health` and prints a single error if the API
is down. Arguments after `serve` are appended to `llama-server`.

## Profiles and settings

| Variable | Default | Values |
| --- | --- | --- |
| `TREEBEARD_BACKEND` | `auto` | `auto`, `cpu`, `sycl`, `cuda` |
| `TREEBEARD_PROFILE` | `quality` | `quality`, `throughput`, `custom` |
| `TREEBEARD_CONTEXT` | 32768 CPU, 262144 GPU | positive token count, at least the slot count |
| `TREEBEARD_PARALLEL` | quality 1; CPU throughput 2; GPU throughput 12 | positive slot count |
| `TREEBEARD_REASONING` | `off` | `off`, `bounded`, `unrestricted` |
| `TREEBEARD_REASONING_BUDGET` | 16 CPU, 64 GPU | used when reasoning is `bounded` |
| `TREEBEARD_SPECULATION` | `off` | `off`, `ngram`, `mtp`, `hybrid` |
| `TREEBEARD_HOST` | `127.0.0.1` | hostname or IP address |
| `TREEBEARD_PORT` | `8093` | 1 through 65535 |
| `TREEBEARD_MULTIMODAL` | `0` | `1` adds `--mmproj` when the projector is installed |
| `TREEBEARD_VERIFY` | `once` | `once`, `always`, `never` |
| `TREEBEARD_NGL` | 0 CPU, 99 GPU | 0 through 999. CPU launches omit `-ngl`. |

CPU threads default to the online processor count, capped at 32. GPU launches
use 15 threads. `package/profiles/quality.env` and
`package/profiles/throughput.env` only set `TREEBEARD_PROFILE`; source one if
you want that as an environment preset.

`TREEBEARD_REASONING=off` passes `--reasoning off --reasoning-budget -1`.
A client can still enable thinking on one request. `ngram` and `mtp` add
conservative draft flags. The package does not claim a speculative speedup.
`TREEBEARD_TOOLS_ROOT` is inherited by the server process if a build reads it.
This launcher does not add a tool sandbox of its own.

On SYCL, the launcher sets the package environment used for the Arc Pro B70
runs: GDN out-flat, MoE-down rows-per-subgroup 4, Q8 multi-column subgroups 32,
and expert-grouped MoE-down. Pipeline and dual-down experiment switches stay
off unless you export them yourself.

## Build and test

There is no compiler toolchain in this repository. The runtime archives are
downloaded as pinned tarballs. From a checkout:

```bash
make check
```

`make lint` runs ShellCheck on the installer, launcher, checksum script, and
tests. `make test` runs `tests/run-tests.sh`. `make checksums` rebuilds
`SHA256SUMS` and `docs/SHA256SUMS`. GitHub Actions runs `make check` on Ubuntu.

The tests cover backend selection, profile defaults, reasoning and speculation
flags, archive path and symlink checks, installer preflight, and checksum
pins. They use a sparse model file and do not download weights.

## Repository layout

| Path | Role |
| --- | --- |
| `install.sh` | Linux installer |
| `package/run.sh` | Runtime selector and `llama-server` launcher |
| `package/treebeard` | `serve`, `doctor`, `verify`, `status`, `report` |
| `package/PACKAGE.json` | Package metadata |
| `source/` | NVIDIA Blackwell CUDA patch used in validation |
| `docs/` | GitHub Pages site |
| `results/` | Recorded runs and reproduction scripts |
| `tests/` | Automated launcher and installer tests |

## Recorded results

These figures are the values stored in the named files. They are not a new
measurement from this checkout.

| Test | Recorded value | File |
| --- | --- | --- |
| tool-eval-bench 2.1.0 public 69, np=1, c=262144, temp 0, thinking off, seed 42 | `final_score` 94, 130/138 points, 63 pass, 4 partial, 2 fail, 69 scenarios | `results/agent/single-slot-94/result.json` and `nvidia-result.json` |
| Same public suite, stock Q5 control vs package, 2026-07-28 | 91 (125/138) and 91 (126/138) | `results/private-verification-20260728/agent-bench-ab-20260728T220230Z/summary.json` |
| Sequential tg p50, np=1, c=32768 | 77.094 and 88.934 tok/s | `results/private-verification-20260728/single-agent-ab-20260728T213156Z/summary.json` |
| 12-agent ABA p50 tok/s per agent | 6.878 and 26.329 | `results/private-verification-20260728/base-vs-package-aba-20260728T204515Z/summary.json` |
| llama-bench pp4096, GB10 | `avg_ts` 2422.325 | `results/nvidia/native-bench/pp4096.json` |
| llama-bench tg128, GB10 | `avg_ts` 59.614 | `results/nvidia/native-bench/tg128.json` |
| Q8_0 direct 12-column and MoE-down median latency change | 31.49% and 4.01% | `results/nvidia/attribution-q8/summary.json` |
| CPU package chat and tool generation | 9.253 and 7.142 tok/s, exact tool call | `results/cpu-linux-x86_64/smoke/summary.json` |
| 12-agent SYCL aggregate wall tok/s, p50 of 5 samples | 194.023 | `results/sycl/pareto-result.json` |

## Integrity

`SHA256SUMS` covers the files in this repository. `docs/SHA256SUMS` covers the
site directory. The NVIDIA patch SHA-256 is
`c1e0780c96432059ea7a517f6ab2db935f1083da065ed0a9009a00d944c3415f`.

The installer checks SHA-256 and size for the model, the selected runtime, and
the launcher scripts. Launcher scripts are taken from `package/` in a checkout
or from `package/run.sh` and `package/treebeard` on GitHub. A piped install
from `main` therefore installs the launcher committed with that `install.sh`.
