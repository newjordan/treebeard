# Treebeard release notes — dual-axis + private verification pack (2026-07-28)

**Status:** release candidate materials · honest claims only  
**Product:** Treebeard = measured llama.cpp agent inference stack on Qwen3.6-35B-A3B  
**Not:** a new foundation model · not LoRA-as-quality-champ

---

## One-sentence product claim

> Same local 35B agent stack: public single-slot quality at **94/100**, and a measured multi-slot serving stack that is faster under concurrent agents — not a bigger model, a better concurrent runtime.

---

## Dual-axis freeze (public-safe)

| Axis | Claim | Number | Scope |
|------|--------|--------|--------|
| **A. Quality** | Public Agent Bench champion | **94/100** (130/138) | 69 scenarios · 1 slot · temp 0 · thinking off · seed 42 · B70 + GB10 |
| **B. Throughput** | Concurrent multi-agent decode | **+28.7%** p50 tok/s/agent | 12-agent ABA · ship stack vs pre-stack mid-A · **not** sequential TG |

![Dual-axis](../docs/assets/release-20260728/chart-dual-axis.png)

**Do not claim:** “29% faster single-user chat.” Sequential single-stream on the same package was only ~+2%.

---

## Private verification pack (2026-07-28) — package positives on latest

Port of symbiotic SYCL ship positives onto current `llama.cpp` master for private gates (stock Q5 weights for engine fairness).

### Multi-slot package vs parent (same binary / same weights)

| Arm | p50 tok/s/agent |
|-----|----------------:|
| Parent (package off) | **21.94** |
| Package (positives ON) | **26.54** |
| **Lift** | **+21.0%** |

![Multi-slot ABA](../docs/assets/release-20260728/chart-multislot-aba.png)

### Leave-one-out (what belongs in the package)

| Mode | p50 | Note |
|------|----:|------|
| package | 26.54 | full set |
| −ncols32 | 26.33 | mild help |
| −shared_act | 26.58 | ~flat |
| −deferred | 26.70 | **cut candidate** (slightly faster without) |
| −expert-grouped | 25.79 | keep |
| −rps4 | 24.87 | keep |
| −GDN | 22.67 | keep (largest multi-slot piece) |
| parent | 21.94 | all off |

![Ablation](../docs/assets/release-20260728/chart-ablation.png)

### Real-world + long-context gates

| Gate | Result |
|------|--------|
| Broadway multi-site HTML (6 pages, multi-era) | **6/6 · 100%** structure |
| Needle-in-haystack (3 depths, ~65k-char doc) | **3/3** |
| Broadway long dossier QA | **14/14** |
| Long multi-slot stress `c=262144` `np=12` | **120/120 · 100%** |

![Quality gates](../docs/assets/release-20260728/chart-quality-gates.png)
![Long multi-slot](../docs/assets/release-20260728/chart-long-multislot.png)

---

## What this is (identity)

| Layer | Treebeard |
|-------|-----------|
| Weights | Qwen3.6-35B-A3B (commodity) |
| Engine | llama.cpp + ggml (MIT), specialized SYCL/CUDA paths |
| Product | Installer · package · Agent Bench proof · concurrent serving pins |
| Contribution shape | Downstream llama.cpp specialization for multi-slot MoE agent serving |

---

## Package members (engine positives)

Default-on / ship-shaped: GDN out-flat · MoE-down rps4 · expert-grouped · Q8 multi-col geometry · dual shared-act · Q8 vec4 / Q6 aligned paths · fusion defaults as shipped.

**Out of engine PR package:** q8down quant (weights) · LoRA · StateTree product · PARK regressions.

---

## Release checklist

- [x] Dual-axis freeze written
- [x] Package ablation on latest (private)
- [x] Broadway real-world sites
- [x] Long-context needles + dossier
- [x] Long multi-slot stress 262k×12
- [x] Charts + hero art generated
- [ ] GitHub: docs PR / tag notes
- [ ] Optional: SYCL runtime rebuild pin for next RC
- [ ] Optional: HF model card refresh (weights unchanged unless quant ship)

---

## Version note

Current public package remains **0.1.0-rc.3** until a new runtime archive is built and checksum-pinned. This release pack updates **documentation, evidence, and charts** for the dual-axis + verification story. Runtime binary bump is a follow-on if you promote the latest package port to ship.

---

## Links

- Report: https://newjordan.github.io/treebeard/
- GitHub: https://github.com/newjordan/treebeard
- HF: https://huggingface.co/Frosty40/Treebeard-Qwen3.6-35B-A3B-GGUF


---

## CORRECTION — true base control (2026-07-28 evening)

Earlier private ablation labeled **package knobs-off** as "parent." That was **wrong**
for product claims. True control is clean upstream llama.cpp + stock Qwen weights.

### True multi-slot ABA (c=262144 np=12 n_predict=96, stock Q5 all arms)

| Arm | Binary | p50 tok/s/agent |
|-----|--------|----------------:|
| **base** (true control) | clean upstream SYCL @ pin `7e1e28cae` | **6.88** |
| knobs_off (old mislabeled "parent") | package binary, package knobs forced off | **21.81** |
| **package** | package binary + package env | **26.33** |

### Lifts (honest)

| Comparison | Lift | Meaning |
|------------|-----:|---------|
| **package vs base** | **+282.8%** | Full package stack vs stock Qwen serving (true claim axis) |
| knobs_off vs base | +217.1% | Most of the win is **compiled package SYCL/code**, not env knobs alone |
| package vs knobs_off | **+20.7%** | Env package pins on top of package code (old internal ablate) |

**Do not** call knobs_off "parent" or "base Qwen."  
**Do not** treat +21% as the full package-vs-stock story.  
Source: `results/private-verification-20260728/base-vs-package-aba-20260728T204515Z/`

