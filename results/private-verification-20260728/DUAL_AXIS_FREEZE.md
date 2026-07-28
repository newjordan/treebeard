# Treebeard dual-axis freeze — single-agent quality × multi-agent throughput

**Date:** 2026-07-28  
**Purpose:** One valid product story in the gap between “agent quality” and “fleet speed.”  
**Rule:** Only frozen, measured claims. No LoRA as quality champ. No speed without multi-slot.

---

## The product claim (what you can stand on)

Treebeard on Arc Pro B70 is **two things at once**:

| Axis | What it means | Frozen number | Where it lives |
|---|---|---|---|
| **A. Single-agent quality** | One user, one slot, full tool-use bench | **94/100 public** (published RC3 / website) | [treebeard report](https://newjordan.github.io/treebeard/) · package README |
| **B. Multi-agent throughput** | 12 concurrent agents, same ship stack | **+28.7% p50 tok/s/agent** vs pre-stack mid-A | `treebeard-private-full-bench-20260727` |

**One sentence for humans:**

> *Same local 35B agent stack: public single-slot quality at 94/100, and ~29% faster per-agent decode when twelve agents run together—not a bigger model, a better concurrent runtime.*

That is the work **between** single output and multi-agent throughput. Neither axis alone is the whole product.

---

## Axis A — Single-agent quality (do not muddy)

### Champion (public / package)

| Item | Value |
|---|---|
| Suite | tool-eval / Agent Bench, **69 scenarios** |
| Score | **94/100** · 130/138 · Excellent |
| Shape | 63 pass / 4 partial / 2 fail · 0 request errors |
| Method | 1 slot, 1 worker, temp 0, thinking **off**, seed 42, B70 + GB10 reproduction claimed on site |
| Artifact | Published Treebeard package + public report |

**This is still the quality north star.** Do not replace it with later re-runs or LoRA.

### Later measurements (context only, not champions)

| Run | Score | Role |
|---|---:|---|
| Stock ship re-run 2026-07-27 (`…161134Z`) | **93** | Same family, one point softer (e.g. TC-62 partial) — instrumentation/build drift, **not** a better product |
| Closure P2 LoRA always-on | **91** | Specialized post-train; **worse** on public suite overall; TC-62 improved; **not** quality champion |
| Hard multi-turn product probes | base ≈ cand **1.0** | Ceiling / parity — no LoRA promote |

**Policy:** Quality claims for outsiders = **94 package**. Experiments stay labeled experiments.

---

## Axis B — Multi-agent throughput (the real stack win)

### Frozen private package (2026-07-27)

| Item | Value |
|---|---|
| Instrument | **12-agent concurrent ABA**, n_predict 96 (primary), temp 0, top_k 1, ctx 262144, np 12, reasoning **off** |
| Arm A (before) | stock Q5_K_XL · GDN off · rps 1 · ncols 16 · expert-grouped off |
| Arm B (ship stack) | q8down-q6k · GDN on · rps 4 · ncols 32 · expert-grouped on · dual shared-act / Q8 vec4 / etc. |
| **A mid p50** | **~21.96 tok/s/agent** |
| **B p50** | **~28.26 tok/s/agent** |
| **Lift** | **+28.7%** vs mid-A · no A/B overlap · A-drift &lt;1% |
| n_predict 192 | +28.4% (confirms not a fluke at 96) |
| Sequential single-stream | only **~+2.3%** |

**Policy:** Throughput claims **must** say multi-slot / concurrent. Do **not** claim ~29% faster single-user chat.

Source: `results/treebeard-private-full-bench-20260727/PRIVATE_REPORT.md` + `summary.json`.

---

## The gap product (what “valid” looks like)

```
                    MULTI-AGENT THROUGHPUT
                    (12-agent ABA p50)
                              ↑
                     +28.7% ship stack
                              │
         ┌────────────────────┼────────────────────┐
         │                    │                    │
    weak quality         Treebeard              fast but
    + fast fleet         dual-axis              dumb fleet
         │               (this freeze)                 │
         └────────────────────┼────────────────────┘
                              │
                     94/100 single-slot
                              │
                              ↓
                    SINGLE-AGENT QUALITY
                    (69-scenario Agent Bench)
```

**Valid middle:** quality held at public 94-class single agent, **plus** concurrent fleet speed for multi-agent / multi-user use.

**Invalid middles (we already learned):**

- LoRA that drops public score to 91 while chasing Hosted reward  
- Speed demos without quality continuity  
- “More evals” with no freeze and no product sentence  

---

## What is in / out of the freeze

### In (ship narrative)

1. Public **94/100** Agent Bench (package + report).  
2. Private **+28.7%** 12-agent ABA on current B70 ship stack.  
3. Held-out ho-pack continuity on ship arm (43/46 class).  
4. Binary + model pins as in private full package and install docs.

### Out (do not sell as the main product)

1. Closure LoRA as default quality upgrade.  
2. Hard multi-turn “YES” (never earned; suite ceilinged).  
3. Hosted train reward as quality proof.  
4. Sequential TG ~2% as the multi-agent story.

### Optional later (not required for validity)

- LoRA **default off**, enable only on long/agent routes (toggle proven; quality cost if always on).  
- Harder unsaturated closure suite if you ever want product YES on multi-turn finish.

---

## How you use this when empty

If someone asks “what did you build?”:

> Local 35B agent: **94** on the public single-agent tool suite, and about **29% higher per-agent throughput** when twelve agents share the GPU—same box, measured before/after stack, quality held on held-out.

If you only have five minutes of tank:

1. Point at this file.  
2. Point at public 94 report.  
3. Point at `PRIVATE_REPORT.md` ABA table.  
4. Stop. No new training today.

---

## Pointers (receipts only)

| Evidence | Path / URL |
|---|---|
| Public quality 94 | https://newjordan.github.io/treebeard/ · package README |
| Stock re-run 93 | `…/receipts/public-agent-bench-69-20260727T161134Z/` |
| LoRA 91 (experiment) | `…/receipts/public-agent-bench-69-closure-lora-20260728T040457Z/` |
| Multi-agent +28.7% | `…/results/treebeard-private-full-bench-20260727/PRIVATE_REPORT.md` |
| Machine summary | `…/treebeard-private-full-bench-20260727/summary.json` |
| LoRA toggle latency | `…/receipts/closure-lora-toggle-bench-20260728T043217Z/` |

---

## Owner commitment for this freeze

- **Quality face** = 94 package path.  
- **Speed face** = concurrent ABA ship stack.  
- **Experiments** (LoRA, Hosted RL, hard-shell residual) stay in the lab folder until they beat 94 *or* earn a separate labeled SKU.

That is a real product position—not pretend rest, not infinite eval churn.
