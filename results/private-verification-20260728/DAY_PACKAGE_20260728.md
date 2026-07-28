# Treebeard day package — 2026-07-28 (honest)

## What this is

A **llama.cpp specialization + package** for Qwen3.6-35B-A3B on Arc B70.  
Not a new model. Not a 12-agent product story.

## What we can stand on

### 1. Single-agent quality A/B (the confidence gate — done)

Shape: **np=1**, c=262144, **same stock Q5**, B70, tool-eval-bench 2.1.0 @ `8b3259b`, seed 42.

| | Original Qwen control | Treebeard |
|--|----------------------:|----------:|
| Public Agent Bench 69 | **91**/100 (125/138) | **91**/100 (126/138) |
| Held-out ho-pack-v1.1 | **91.3%** (42/46) | **91.3%** (42/46) |
| Median turn | 1874 ms | 1794 ms |
| Status vector diffs | — | **1/69** (TC-50 partial→pass) |

Source: `results/agent-bench-ab-20260728T220230Z/`  
**Verdict: quality-neutral.** Runtime package does not hurt (or meaningfully help) agent quality vs clean upstream on the same weights.

Note: published website **94** was a package-champion freeze (different pin/quant history). Matched stock-Q5 control A/B today is **91 vs 91**.

### 2. Single-agent speed (what a user feels)

Shape: **np=1**, c=32768, same stock Q5, tiny task suite.

| | Original Qwen control | Treebeard |
|--|----------------------:|----------:|
| Decode tg_p50 | **77.1** tok/s | **88.9** tok/s (**+15.4%**) |
| Wall p50 | 1.74 s | 1.56 s |
| Tiny task checks | 8/10 | **10/10** |

Source: `results/single-agent-ab-20260728T213156Z/`  
**Limit:** 5 toy prompts × 2 reps — speed signal only, not quality.

### 3. Real-world smoke (Treebeard only — not A/B)

| Gate | Result |
|------|--------|
| Broadway multi-page HTML | **6/6** structure |
| Long-ctx needles | **3/3** |
| Long-ctx dossier QA | **14/14** |

### 4. Multi-slot fleet (appendix only — not the product headline)

| | Original Qwen control | Treebeard |
|--|----------------------:|----------:|
| 12-agent p50 | 6.88 | 26.33 (**+283%**) |

Useful for packing concurrent sessions. **Not** how to sell a solo-user product.

---

## What we did *not* earn today

- A smarter model (same weights)
- A quality win over Original Qwen (neutral on Agent Bench + held-out)
- Multi-slot as a user-facing metric (correctly demoted)

## What was useful

1. **True control** (Original Qwen = clean upstream, not knobs-off on our binary)
2. **Matched single-slot quality A/B** — Agent Bench 69 + held-out on both arms
3. **Single-agent sequential speed** (~+15% tg on tiny suite)
4. Packaging / release path + methodology correction
5. Runtime specialization exists (multi-slot capacity + modest single-agent tg; quality preserved)

## Identity (keep)

> Treebeard = measured agent **runtime package** on open Qwen weights (llama.cpp contribution shape).

## Paths

| Item | Path |
|------|------|
| Agent Bench + held-out A/B | `results/agent-bench-ab-20260728T220230Z/` |
| Single-agent speed A/B | `results/single-agent-ab-20260728T213156Z/` |
| Control vs Treebeard scorecard | `SCORECARD_CONTROL_VS_TREEBEARD.md` |
| GitHub PR | https://github.com/newjordan/treebeard/pull/1 |
| Release notes | `docs/RELEASE-20260728.md` on PR branch |

## Confidence check (straight)

| Question | Answer |
|----------|--------|
| Did we ship a useful model upgrade? | **No** — same Qwen weights |
| Is agent quality preserved vs Original Qwen? | **Yes** — 91=91 public, 91.3=91.3 held-out |
| Did we improve solo decode a bit on B70? | **Small yes** — ~+15% tg on tiny suite; median turn slightly lower on Agent Bench |
| Is 94 still the historical freeze? | **Yes** — website champion; matched stock A/B today is 91 both arms |
| Was the day mostly fleet ABA theater? | **Until corrected** — quality A/B now banked |
| Worth packaging? | **Yes as honest runtime package** — capacity + modest speed, quality neutral |
