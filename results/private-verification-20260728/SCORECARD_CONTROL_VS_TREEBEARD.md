# Scorecard — Original Qwen control vs Treebeard

**Date:** 2026-07-28  
**Rule:** Only two names for the product comparison.

| Name | Meaning |
|------|---------|
| **Original Qwen control** | Stock Qwen3.6-35B-A3B Q5_K_XL + **clean upstream llama.cpp SYCL** (no Treebeard package code) + stock server flags |
| **Treebeard** | Same stock Q5 weights + **Treebeard package binary** + Treebeard package env (GDN on, rps4, ncols32, expert-grouped on, …) |

Do **not** call anything “parent.”  
(The old env-off arm on the Treebeard binary is **Treebeard knobs-off** — intermediate only, not the control.)

---

## 1. Head-to-head (matched stock Q5)

### 1.1 Single-agent quality (THE confidence gate)

**Instrument:** np=1 · c=262144 · temp 0 · seed 42 · no-think · tool-eval-bench 2.1.0 @ `8b3259b`  
**Source:** `results/agent-bench-ab-20260728T220230Z/`

| Metric | Original Qwen control | Treebeard | Delta |
|--------|----------------------:|----------:|------:|
| Public Agent Bench 69 | **91**/100 (125/138) | **91**/100 (126/138) | **0 score** (+1 raw pt) |
| pass / partial / fail | 60 / 5 / 4 | 61 / 4 / 4 | TC-50 only status diff |
| median turn ms | 1874 | 1794 | −80 ms |
| Held-out ho-pack-v1.1 | **91.3%** (42/46) | **91.3%** (42/46) | **0** |
| request errors | 0 | 0 | both OK |

**Verdict: quality-neutral.** Package does not regress agent quality on the public suite or frozen held-out pack.

Published website **94/100** remains a historical package-champion freeze (different pin/quant context). Matched stock-Q5 A/B today is **91 vs 91**.

### 1.2 Single-agent sequential speed (solo-user feel)

**Instrument:** np=1 · c=32768 · 5 toy prompts × 2 · stock Q5  
**Source:** `results/single-agent-ab-20260728T213156Z/`

| Metric | Original Qwen control | Treebeard | Delta |
|--------|----------------------:|----------:|------:|
| tg_p50 | 77.1 tok/s | **88.9** | **+15.4%** |
| wall_p50 | 1.74 s | 1.56 s | faster |
| tiny checks | 8/10 | 10/10 | tiny only |

### 1.3 Multi-slot decode (ops appendix)

**Instrument:** 12 concurrent agents, n_predict=96, temp 0, same stock Q5, pin `7e1e28cae` host.  
**Source:** `results/base-vs-package-aba-20260728T204515Z/`

| Metric | Original Qwen control | Treebeard | Delta |
|--------|----------------------:|----------:|------:|
| p50 tok/s/**agent** | **6.88** | **26.33** | **+282.8%** |
| aggregate tok/s (fleet) | **72.9** | **208.7** | **+186%** |

**Intermediate (not control):** Treebeard knobs-off p50 = **21.81**  
→ most of the multi-slot win is **compiled Treebeard code**, package env adds **+20.7%** on top of knobs-off.

---

## 2. What we have on both arms vs Treebeard-only

| Metric / gate | Original Qwen control | Treebeard | Notes |
|---------------|----------------------:|----------:|-------|
| Public Agent Bench 69 | **91** | **91** | Matched A/B today |
| Held-out ho-pack-v1.1 | **91.3%** | **91.3%** | Matched A/B today |
| Single-agent tg_p50 | 77.1 | 88.9 | Tiny suite |
| Multi-slot ABA p50 (np12) | 6.88 | 26.33 | Matched A/B |
| Historical website 94 freeze | n/a | 94 (historical) | Different pin/quant context |
| Broadway multi-site HTML | **not run** | **6/6** | Treebeard only |
| Long-ctx needles | **not run** | **3/3** | Treebeard only |
| Long-ctx dossier QA | **not run** | **14/14** | Treebeard only |
| Long multi-slot stress 262k×12 | **not run** | **120/120** | Treebeard only |

---

## 3. Full number dump

### A. Quality (stock Q5, engine only, 2026-07-28)

| Arm | Public 69 | Held-out |
|-----|----------:|---------:|
| Original Qwen control | 91 (125/138) | 42/46 (91.3%) |
| Treebeard | 91 (126/138) | 42/46 (91.3%) |

### B. Speed

| Arm | Single-agent tg_p50 | Multi-slot p50/agent |
|-----|--------------------:|---------------------:|
| Original Qwen control | 77.1 | 6.88 |
| Treebeard knobs-off | — | 21.81 |
| Treebeard | 88.9 | 26.33 |

### C. Real-world / long-context (Treebeard only so far)

| Gate | Result |
|------|--------|
| Broadway 6 pages | 6/6, mean structure 100% |
| Needles 3 depths | 3/3 |
| Broadway dossier 14 Qs | 14/14 |
| Long multi-slot stress | 120/120 success |

### D. Ablation leave-one-out (Treebeard binary only)

| Mode | p50 |
|------|----:|
| Treebeard full | 26.54 |
| −ncols32 | 26.33 |
| −shared_act | 26.58 |
| −deferred | 26.70 (cut candidate) |
| −expert-grouped | 25.79 |
| −rps4 | 24.87 |
| −GDN | 22.67 |
| knobs-off-like | ~21.9 |

---

## 4. One-page “wtf do we have?”

```
WEIGHTS (same in true A/B):  stock Qwen Q5_K_XL
                             sha256 25233af7…c506

ORIGINAL QWEN CONTROL        TREEBEARD
clean upstream SYCL          package SYCL + package env

QUALITY public 69            91   ═══════════════  91      (neutral)
QUALITY held-out             91.3 ═══════════════  91.3    (neutral)
SINGLE-AGENT tg_p50          77.1 ──────────────►  88.9    (+15.4%)
MULTI-SLOT p50               6.88 ──────────────►  26.33   (+282.8%)

HISTORICAL website freeze                      94 (package-era, not this A/B)
BROADWAY / LONGCTX (Treebeard only)            6/6 · 3/3 · 14/14
```

### Bottom line in plain English

1. **On agent quality, with a real Original Qwen control, Treebeard is neutral** (91=91 public, 91.3=91.3 held-out).  
2. **On solo-user decode speed, Treebeard is modestly faster** (~+15% tg on a tiny suite; lower median turn on Agent Bench).  
3. **On multi-slot packing, Treebeard wins hard** (~6.9 → ~26.3 tok/s/agent) — ops capacity, not the product headline.  
4. **Most multi-slot win is Treebeard engine code**, not just env knobs.  
5. **Not a smarter model** — same weights.

---

## 5. Paths

| Item | Path |
|------|------|
| Quality A/B | `results/agent-bench-ab-20260728T220230Z/` |
| Single-agent speed A/B | `results/single-agent-ab-20260728T213156Z/` |
| Multi-slot A/B | `results/base-vs-package-aba-20260728T204515Z/` |
| This scorecard | `SCORECARD_CONTROL_VS_TREEBEARD.md` |
| Day package | `DAY_PACKAGE_20260728.md` |
| Broadway | `results/broadway-eval-20260728T184434Z/` |
| Long-ctx | `results/longctx-eval-20260728T193321Z/` |

---

## 6. Still missing (optional)

| Gate | Status |
|------|--------|
| Broadway / long-ctx on Original Qwen control | missing (Treebeard-only smokes) |
| Multi-seed quality stability | unmeasured |
| Quality under concurrent load | unmeasured |
