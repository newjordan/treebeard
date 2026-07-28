# Scorecard — Original Qwen control vs Treebeard

**Date:** 2026-07-28  
**Rule:** Only two names for the product comparison.

| Name | Meaning |
|------|---------|
| **Original Qwen control** | Stock Qwen3.6-35B-A3B Q5_K_XL + **clean upstream llama.cpp SYCL** (no Treebeard package code) + stock server flags |
| **Treebeard** | Same stock Q5 weights + **Treebeard package binary** + Treebeard package env (GDN on, rps4, ncols32, expert-grouped on, …) |

Same shape when speed-compared: **c=262144 · np=12 · fa on · f16 KV · B70**.

Do **not** call anything “parent.”  
(The old env-off arm on the Treebeard binary is **Treebeard knobs-off** — intermediate only, not the control.)

---

## 1. Names for every arm we ever used

| Old bad name | Correct name | What it actually was |
|--------------|--------------|----------------------|
| parent (ablation) | **Treebeard knobs-off** | Treebeard binary, package envs forced off |
| base | **Original Qwen control** | Clean upstream + stock Q5 |
| package | **Treebeard** | Package binary + package env |
| ship / Arm B historical | **Treebeard ship stack** | Often + q8down quant — not pure engine A/B |

---

## 2. Head-to-head: Original Qwen control vs Treebeard

### 2.1 Multi-slot decode (THE matched A/B)

**Instrument:** 12 concurrent agents, n_predict=96, temp 0, same stock Q5, pin `7e1e28cae` host.  
**Source:** `results/base-vs-package-aba-20260728T204515Z/`

| Metric | Original Qwen control | Treebeard | Delta |
|--------|----------------------:|----------:|------:|
| p50 tok/s/**agent** | **6.88** | **26.33** | **+282.8%** |
| aggregate tok/s (fleet) | **72.9** | **208.7** | **+186%** |
| rounds p50 | 6.92 / 6.86 / 6.86 | 26.38 / 26.26 / 26.35 | tight both |
| request success | 12/12 × 3 | 12/12 × 3 | both OK |

**Intermediate (not control):** Treebeard knobs-off p50 = **21.81**  
→ most of the multi-slot win is **compiled Treebeard code**, package env adds **+20.7%** on top of knobs-off.

---

### 2.2 What we have on **both** arms vs Treebeard-only

| Metric / gate | Original Qwen control | Treebeard | Notes |
|---------------|----------------------:|----------:|-------|
| Multi-slot ABA p50 (np12) | **6.88** | **26.33** | Matched A/B |
| Multi-slot aggregate | **72.9** | **208.7** | Matched A/B |
| Public Agent Bench 94/100 | **not re-run on clean control this week** | **94** (published package champion) | Control not measured here |
| Held-out 43/46 | **not measured on clean control** | **43/46** (ship stack historical) | Treebeard-era evidence |
| Broadway multi-site HTML | **not run** | **6/6 · 100%** structure | Treebeard only |
| Long-ctx needles | **not run** | **3/3** | Treebeard only |
| Long-ctx dossier QA | **not run** | **14/14** | Treebeard only |
| Long multi-slot stress 262k×12 | **not run** | **120/120** | Treebeard only |
| llama-bench single-stream pp/tg | knobs-off≈package (internal) | ~same as knobs-off | **Not** original-Qwen vs Treebeard; single-stream not the multi-slot story |

---

## 3. Full number dump (everything we banked)

### A. Matched speed A/B (stock Q5, engine only)

| Arm | p50 tok/s/agent | aggregate |
|-----|----------------:|----------:|
| Original Qwen control | 6.878 | 72.87 |
| Treebeard knobs-off | 21.812 | 182.06 |
| Treebeard | 26.329 | 208.68 |

Lifts:

| | |
|--|--|
| Treebeard vs Original Qwen control | **+282.8%** p50 |
| Treebeard knobs-off vs Original Qwen control | **+217.1%** p50 |
| Treebeard vs Treebeard knobs-off | **+20.7%** p50 |

### B. Public quality freeze (Treebeard package champion — not re-run on control)

| | |
|--|--|
| Agent Bench | **94/100** · 130/138 · 63 pass / 4 partial / 2 fail |
| Shape | 1 slot · 69 scenarios · temp 0 · thinking off · seed 42 |
| Platforms claimed | B70 + GB10 reproduction |

### C. Historical ship multi-slot (Treebeard stack; **quant mixed** on B arm)

| | p50 | note |
|--|----:|------|
| Pre-stack mid-A (stock Q5, Treebeard-family knobs soft) | ~22.0 | not original-Qwen control |
| Ship stack B (q8down + full knobs) | ~28.3 | **+28.7%** vs mid-A |
| Sequential single-stream same package | only ~+2.3% | multi-slot story only |

Do not sell +28.7% as pure original-Qwen control.

### D. Real-world / long-context (Treebeard only so far)

| Gate | Result |
|------|--------|
| Broadway 6 pages | 6/6, mean structure 100%, ~281s gen wall |
| Needles 3 depths (~65k chars) | 3/3 |
| Broadway dossier 14 Qs (~61k chars) | 14/14 |
| Long multi-slot stress (prompts ~0.5k–6.3k ×12) | 120/120 success; short tg_p50 ~29; heavy long ~1–7 tg_p50 (prefill-dominated) |

### E. Ablation leave-one-out (Treebeard binary only — ranking members)

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
pin 7e1e28cae                pin host + ship sycl port

MULTI-SLOT p50               6.88  ──────────────►  26.33   (+282.8%)
MULTI-SLOT aggregate         72.9  ──────────────►  208.7

QUALITY 94 AGENT BENCH       not re-measured        94 freeze (package)
HELD-OUT                     not re-measured        43/46 (historical ship)
BROADWAY SITES               not run                6/6
LONG NEEDLES / DOSSIER       not run                3/3 + 14/14
LONG MULTI-SLOT STRESS       not run                120/120
```

### Bottom line in plain English

1. **On multi-slot speed, with a real Original Qwen control, Treebeard wins hard** (~6.9 → ~26.3 tok/s/agent).  
2. **Most of that is the Treebeard engine code**, not just env knobs (~21.8 even knobs-off).  
3. **Quality / real-world / long-ctx numbers we have are Treebeard-side** (or historical ship). We did **not** re-run Agent Bench or Broadway on Original Qwen control this week.  
4. Historical **+28.7%** is ship vs an older soft baseline **and** includes quant on the ship arm — different story from (1).

---

## 5. Paths

| Item | Path |
|------|------|
| True control A/B | `results/base-vs-package-aba-20260728T204515Z/` |
| This scorecard | `SCORECARD_CONTROL_VS_TREEBEARD.md` |
| Broadway | `results/broadway-eval-20260728T184434Z/` |
| Long-ctx | `results/longctx-eval-20260728T193321Z/` |
| Long multi-slot stress | `results/long-multislot-stress-20260728T194913Z/` |
| Dual-axis freeze (older naming) | `…/treebeard-dual-axis-freeze-20260728/` |

---

## 6. Still missing for a complete control vs Treebeard matrix

| Gate | Status |
|------|--------|
| Agent Bench on Original Qwen control | **missing** |
| Broadway / long-ctx on Original Qwen control | **missing** |
| Long multi-slot stress on Original Qwen control | **missing** |
| Matched sequential TG Original vs Treebeard | **missing** (only internal knobs comparison) |

If you want the matrix filled: run the same Broadway + long-ctx + stress scripts against the **Original Qwen control** binary next.
