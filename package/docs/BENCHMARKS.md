# Benchmarks

Model package: <https://huggingface.co/Frosty40/Treebeard-Qwen3.6-35B-A3B-GGUF>

GitHub repository: <https://github.com/newjordan/treebeard>

MoE algorithm explainer: <https://newjordan.github.io/treebeard/moe-routing.html>

Public report: <https://newjordan.github.io/treebeard/>

Public result bundle: <https://github.com/newjordan/treebeard/tree/main/results>

## Tool-use evaluation

The release quality headline is 94/100 and 130/138 points:

- 69/69 scenarios completed;
- 63 pass, 4 partial, 2 fail;
- zero request errors;
- one server slot and one evaluation worker;
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
- single-slot tool-use evaluation: 94/100, 130/138, zero request errors;
- packaged tool call: complete `get_weather({"city":"Chicago"})` call;
- packaged vision: bundled projector read the report score as `94`;
- final kernel-health scans: no matching Xid, fault, reset, hang, or OOM.

See `NVIDIA.md` and `evidence/nvidia` for commands, hashes, raw logs, the source
patch, package smoke, and GPU-health records.
