# llama.cpp PR preparation — Treebeard SYCL positives

**Status:** prepared, not opened against `ggml-org/llama.cpp` yet  
**Date:** 2026-07-28  
**Shape:** one symbiotic SYCL package PR (not seven micro-PRs)

---

## 1. Product claim for the PR (upstream-safe)

> SYCL backend improvements for multi-slot MoE decode on Intel GPUs (validated
> on Arc Pro B70 with Qwen3.6-35B-A3B). Same weights: agent quality neutral vs
> clean upstream; multi-slot throughput much higher; modest single-stream decode
> gain.

Do **not** claim a new model, LoRA quality, or “29% faster chat.”

---

## 2. Evidence (attach / link in PR body)

| Gate | Control | Treebeard | Source |
|------|--------:|----------:|--------|
| Public Agent Bench 69 | 91/100 | 91/100 | `agent-bench-ab-20260728T220230Z` |
| Held-out ho-pack-v1.1 | 42/46 | 42/46 | same |
| Solo tg_p50 (tiny) | 77.1 | 88.9 (+15.4%) | `single-agent-ab-20260728T213156Z` |
| Multi-slot p50/agent | 6.88 | 26.33 (+283%) | `base-vs-package-aba-20260728T204515Z` |
| Multi-slot knobs-off | — | 21.81 | intermediate (code residual) |
| Broadway / long-ctx | — | 6/6 · 3/3 · 14/14 | Treebeard-only smokes |

Pins:

- Upstream host pin (control base): `7e1e28cae` (rebase before open)
- Stock Q5 sha256: `25233af7642e3a91bd52cc4aeefdbd4a117479088e06cf1aea5b6bedb443c506`
- tool-eval-bench: 2.1.0 @ `8b3259be7411fe27c7610d0de64ae1d3b622b9ef`
- Package worktree commits on private branch:
  - `8fe9b1072` port positives
  - `4972c4caa` GDN out-flat
  - `bc76ba4cc` full ship ggml-sycl tree (needs cleanup before upstream)

---

## 3. Package members to **include** (ablation-gated)

| ID | Mechanism | Default | Notes |
|----|-----------|---------|-------|
| P1 | Q8 MMVQ multi-col subgroups = 32 | env / code | mild multi-slot help |
| P2 | Q8_0 vec4 loads | code path | historical TG |
| P3 | MoE-down `rows_per_sg=4` | env | multi-row ownership |
| P5 | MoE dual shared-act (Q5) | code default ON | keep |
| P6 | Expert-grouped MoE-down | env ON | keep |
| P7 | Q6_K reorder aligned loads | code path | keep |
| P9 | Top-k MoE router fusion | fusion defaults | keep if stable |
| P10 | GDN out-flat | env / model glue | `TREEBEARD_GDN_OUT_FLAT` → rename for upstream |

### Cut / do not ship as default

| Item | Why |
|------|-----|
| Deferred reduce (P4) | Ablation: slightly **faster when off** → cut candidate |
| All-token weight-once | PARK / regress |
| MoE-down par8 | flat/regress |
| Q8 multi-col K-split / COL_TILE | PARK negatives |
| Dual→LDS→down one-WG, Q8-band multi-WG | PARK TG loss |
| q8down quant | weights, not engine |
| StateTree / LoRA / server product | out of scope |

---

## 4. Code hygiene before opening PR

Current private branch is a **full ship SYCL tree dump** (~10k LOC churn) with
diagnostic `fprintf`s tagged `[treebeard-…]`. Upstream will bounce that as-is.

### Must-do cleanup

1. **Rebase** onto current `ggml-org/llama.cpp` master (branch is ahead/behind).
2. **Split contribution surface** to positives only:
   - Prefer surgical diffs on `mmvq.cpp`, MoE-down paths, fusion, GDN out-flat,
     env knobs — not wholesale file reverts (conv3d/pool deletes need review).
3. **Rename** `TREEBEARD_*` envs to neutral `GGML_SYCL_*` where possible.
   - Keep behavior; drop brand from public API.
4. **Strip** noisy `[treebeard-…]` diagnostic `fprintf`s (or gate behind
   `GGML_SYCL_DEBUG` / existing verbose flags).
5. **Default-off** all PARK paths; ensure no loser is ON by default.
6. **Document** env knobs in `docs/backend/SYCL.md` (or equivalent).
7. **CI**: confirm SYCL build still compiles; CPU/CUDA paths unchanged.
8. **Self-test**: re-run multi-slot ABA + one public Agent Bench smoke on the
   rebased branch before open.

### Suggested commit series (if they want stacked history)

1. `sycl: Q8 MMVQ multi-col subgroups default 32 + env`
2. `sycl: MoE-down rows_per_sg=4 + expert-grouped path`
3. `sycl: dual shared-act MoE path for Q5`
4. `sycl: GDN out-flat layout (env-gated)`
5. `docs: SYCL multi-slot MoE env knobs + B70 notes`

Or **one commit** with a clear body if reviewers prefer a single package.

---

## 5. Draft PR title + body

### Title

```
sycl: multi-slot MoE decode package for Intel GPUs (Qwen3 MoE validated)
```

### Body (paste when ready)

```markdown
## Summary

SYCL backend package focused on multi-slot MoE decode throughput on Intel GPUs,
validated on Arc Pro B70 with Qwen3.6-35B-A3B (stock Q5_K_XL).

This is **not** a model change. Same weights; agent quality is neutral vs clean
upstream.

### Measured (stock Q5, B70, matched control)

| Gate | Clean upstream SYCL | This package |
|------|--------------------:|-------------:|
| Public tool-eval-bench 69 (np=1) | 91/100 | 91/100 |
| Held-out pack | 42/46 | 42/46 |
| Solo tg (tiny suite, np=1) | 77.1 t/s | 88.9 t/s (+15%) |
| Multi-slot p50/agent (np=12, n_predict=96) | 6.88 | 26.33 (+283%) |

Most multi-slot gain is in the compiled kernels; package envs add ~+21% on a
knobs-off intermediate of the same binary.

### Included

- Q8 MMVQ multi-column subgroup geometry (default 32)
- MoE-down rows_per_sg=4
- Expert-grouped MoE-down path
- Dual shared-act MoE path (Q5)
- GDN out-flat layout (env-gated)
- Fusion defaults aligned with ship validation

### Explicitly excluded / default-off

- Deferred reduce (ablation cut candidate)
- PARK losers (all-token weight-once, par8, K-split, COL_TILE, LDS one-WG, …)
- Quant / LoRA / product server features

### Test plan

- [ ] SYCL build on Intel oneAPI
- [ ] `llama-bench` pp/tg sanity vs master
- [ ] Multi-slot concurrent decode smoke (np≥8)
- [ ] Optional: tool-eval-bench subset np=1 quality smoke
- [ ] CUDA/CPU builds still green (no cross-backend regressions)

### Hardware

- Primary: Intel Arc Pro B70, Level Zero, oneAPI SYCL
- Model: Qwen3.6-35B-A3B UD-Q5_K_XL

### Notes for reviewers

- Happy to split into stacked commits if preferred.
- Env names use `GGML_SYCL_*` (no product branding in public API).
- Multi-slot numbers are concurrent capacity, not single-user chat speed.
```

---

## 6. Local artifacts for the PR

| Item | Path |
|------|------|
| Private package worktree | `/home/frosty40/turbo/worktrees/treebeard-pr-private-latest` |
| Clean control worktree | `/home/frosty40/turbo/worktrees/treebeard-base-control-latest` |
| Positive package list | `POSITIVE_PACKAGE.md` |
| Protocol | `PRIVATE_VERIFICATION_PROTOCOL.md` |
| Quality A/B | `results/agent-bench-ab-20260728T220230Z/` |
| Multi-slot A/B | `results/base-vs-package-aba-20260728T204515Z/` |
| Ablation | `results/package-ablation-20260728T155817Z/` |
| Scorecard | `SCORECARD_CONTROL_VS_TREEBEARD.md` |
| Site/docs PR | https://github.com/newjordan/treebeard/pull/1 |

---

## 7. Open checklist

- [ ] Rebase package branch onto latest master
- [ ] Surgical positive-only diff (or justified full SYCL sync)
- [ ] Rename TREEBEARD_* → GGML_SYCL_*
- [ ] Strip treebeard diagnostics
- [ ] Cut deferred-default if still a drag
- [ ] Re-measure multi-slot + quality smoke on rebased tip
- [ ] Fork `ggml-org/llama.cpp` (or use existing) and open PR
- [ ] Link measurement evidence (gist or treebeard results paths)

**Do not open until rebase + hygiene are done.** The private full-tree port is
the measurement vehicle; the upstream PR should be the cleaned positive package.
