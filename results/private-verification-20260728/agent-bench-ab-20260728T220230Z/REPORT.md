# Agent Bench A/B — Original Qwen control vs Treebeard

Shape: **np=1**, c=262144, **same stock Q5** (`25233af7…c506`), B70 SYCL,
temp 0, seed 42, no-think, tool-eval-bench **2.1.0** @ `8b3259b`.
Held-out: private ho-pack-v1.1 (measurement-only, firewall intact).

This is the single-agent **quality** confidence gate. Same weights → expect similar scores.

## Public Agent Bench (69)

| arm | score | points | pass | partial | fail | median_turn_ms |
|-----|------:|-------:|-----:|--------:|-----:|---------------:|
| Original Qwen control | 91 | 125/138 | 60 | 5 | 4 | 1874.4 |
| Treebeard | 91 | 126/138 | 61 | 4 | 4 | 1793.5 |

**Delta (Treebeard − control):** +0 score points; +1 raw points (126 vs 125).

### Public outcome diffs (status only)

| scenario | control | treebeard |
|----------|---------|-----------|
| TC-50 | partial | pass |

_Status diffs: 1 of 69 scenarios._

## Held-out (ho-pack-v1.1)

| arm | score | points | pass | partial | fail | wall_s |
|-----|------:|-------:|-----:|--------:|-----:|-------:|
| Original Qwen control | 91.3 | 42/46 | 20 | 2 | 1 | 63.1 |
| Treebeard | 91.3 | 42/46 | 20 | 2 | 1 | 56.3 |

**Delta:** +0.0 pp (identical points 42/46).

## Honest read

- Public 69: **quality-neutral** — both **91/100**. Treebeard +1 raw point (126/138 vs 125/138); score rounds the same.
- Held-out: **quality-neutral** — both **91.3%** (42/46).
- Same **stock Q5 weights** on both arms → this is **not** a smarter-model claim. Runtime specialization did not break agent quality.
- Median turn slightly faster on Treebeard (1794 vs 1874 ms) — consistent with modest single-slot speed edge, not a quality lift.
- Published website **94/100** was a package-champion freeze (often with ship quant / older pin). Matched stock-Q5 A/B today lands **91** on both arms — the fair comparison.
- Multi-slot fleet speed remains a separate ops axis.

Artifacts: `/home/frosty40/turbo/treebeard-work/research/treebeard-pr-private/results/agent-bench-ab-20260728T220230Z`

