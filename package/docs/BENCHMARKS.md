# Benchmarks

Model package: <https://huggingface.co/Frosty40/Treebeard-Qwen3.6-35B-A3B-GGUF>

GitHub repository: <https://github.com/newjordan/treebeard>

MoE algorithm explainer: <https://newjordan.github.io/treebeard/moe-routing.html>

Public report: <https://newjordan.github.io/treebeard/>

Public result bundle: <https://github.com/newjordan/treebeard/tree/main/results>

## Agent Bench

### Historical package champion (website freeze)

The published quality freeze is 94/100 and 130/138 points:

- 69/69 scenarios completed;
- 63 pass, 4 partial, 2 fail;
- zero request errors;
- one server slot and one benchmark worker;
- 262,144 total context tokens;
- temperature 0, thinking disabled, seed 42;
- tool-eval-bench 2.1.0 at `8b3259b`;
- llama.cpp build `b9624-0424f677f`.

The score reproduced exactly on Intel Arc Pro B70 and NVIDIA GB10, including
the complete 69-case outcome vector. Supporting evidence:

- `evidence/agent/single-slot-94/result.json`
- `evidence/agent/single-slot-94/index.html`
- `evidence/agent/single-slot-94/guard.log`
- `evidence/agent/single-slot-94/nvidia-result.json`
- `evidence/nvidia/agent-single-slot-94/result.json`

The published result is checksum-pinned and accompanied by the complete
supporting evidence bundle.

### Matched Original Qwen control A/B (2026-07-28)

Same **stock Q5** weights, np=1, c=262144, temp 0, seed 42, tool-eval-bench
2.1.0 @ `8b3259b`, Arc Pro B70:

| Arm | Public 69 | Held-out ho-pack-v1.1 |
| --- | ---: | ---: |
| Original Qwen control (clean upstream SYCL) | **91**/100 (125/138) | **91.3%** (42/46) |
| Treebeard package | **91**/100 (126/138) | **91.3%** (42/46) |

**Verdict: quality-neutral.** Runtime specialization does not change agent
quality on the public suite or the frozen held-out pack. Same weights → not a
smarter model.

Solo decode (tiny suite, np=1): control tg_p50 **77.1** → Treebeard **88.9**
(+15.4%). Multi-slot capacity (np=12, ops appendix): control p50 **6.88** →
Treebeard **26.33** (+282.8%).

Evidence: `results/private-verification-20260728/agent-bench-ab-20260728T220230Z/`
and `docs/RELEASE-20260728.md`.

## Portable CPU package smoke

Pkg3 was independently installed from its public-install layout, extracted its
Ubuntu 22.04 baseline runtime, started a one-slot OpenAI-compatible server, and
completed both a chat assertion and an exact structured tool call on an AMD
Ryzen 9 5950X:

- build identity: `b9624-6a6dc2def-cpu`;
- context: 4,096 tokens for the bounded smoke;
- chat output: exact `TREEBEARD READY`;
- chat generation: 9.302 tok/s;
- tool call: exact `multiply({"a":17,"b":23})`;
- tool-call generation: 7.400 tok/s;
- loader warnings, request errors, and assertion failures: zero.

The archive is an Ubuntu 22.04/glibc 2.35 baseline with 14 dynamically selected
x86_64 CPU variants. These timings demonstrate a functional fallback, not a
general CPU speed claim. Raw responses, the pruned server properties, server
log, reproduction script, and hashes are under `evidence/cpu-linux-x86_64`.

## SYCL serving

The released 12-slot profile measured 194.023 aggregate tok/s, 5.152% above
released RC2. The 8-slot profile measured 182.005 aggregate tok/s, 1.421% above
released RC2. Single-session aggregate performance was flat at -0.121%.

The matched same-binary kernel attribution was about +1.12% at 8 concurrent
sessions and +1.17% at 12 concurrent sessions. Native `llama-bench` measured
1143.825 tok/s for pp4096
and 80.909 tok/s for tg128.

Supporting evidence is under `evidence/sycl`.

## NVIDIA

NVIDIA results were produced on one GB10, compute capability 12.1, with CUDA
13.3 on Linux ARM64:

- CUDA correctness: 1,104/1,104 `MUL_MAT` and 796/796 `MUL_MAT_ID`;
- Q8_0 direct 12-column latency: 5.22 to 3.97 us median, a 31.49% improvement;
- Q8_0 MoE down latency: 463.06 to 445.20 us median, a 4.01% improvement;
- native pp4096: 2,422.325 tok/s over five samples;
- native tg128: 59.614 tok/s over five samples;
- single-slot agent benchmark: 94/100, 130/138, zero request errors;
- packaged tool call: complete `get_weather({"city":"Chicago"})` call;
- packaged vision: bundled projector read the report score as `94`;
- final kernel-health scans: no matching Xid, fault, reset, hang, or OOM.

See `NVIDIA.md` and `evidence/nvidia` for commands, hashes, raw logs, the source
patch, package smoke, and GPU-health records.
