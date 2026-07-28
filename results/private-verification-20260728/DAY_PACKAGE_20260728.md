# Treebeard day package — 2026-07-28 (honest)

## What this is

A **llama.cpp specialization + package** for Qwen3.6-35B-A3B on Arc B70.  
Not a new model. Not a 12-agent product story.

## What we can stand on

### 1. Single-agent (what a user feels) — measured today

Shape: **np=1**, c=32768, **same stock Q5**, B70.

| | Original Qwen control | Treebeard |
|--|----------------------:|----------:|
| Decode tg_p50 | **77.1** tok/s | **88.9** tok/s (**+15.4%**) |
| Wall p50 | 1.74 s | 1.56 s |
| Tiny task checks | 8/10 | **10/10** |

Source: `results/single-agent-ab-20260728T213156Z/`  
**Limit:** 5 toy prompts × 2 reps. **Not** Agent Bench. Control failed `code_small` format twice; Treebeard passed.

### 2. Public quality freeze (existing champion — not re-run today)

| | |
|--|--|
| Agent Bench | **94/100** (package publish) |
| Note | We did **not** re-run 69 scenarios on control vs Treebeard today |

### 3. Real-world smoke (Treebeard only)

| Gate | Result |
|------|--------|
| Broadway multi-page HTML | **6/6** structure |
| Long-ctx needles | **3/3** |
| Long-ctx dossier QA | **14/14** |

**Limit:** not A/B’d against Original Qwen control.

### 4. Multi-slot fleet (appendix only — not the product headline)

| | Original Qwen control | Treebeard |
|--|----------------------:|----------:|
| 12-agent p50 | 6.88 | 26.33 |

Useful for packing concurrent sessions. **Not** how to sell a model.

---

## What we did *not* earn today

- A serious single-agent quality suite A/B (Agent Bench / held-out on both arms)
- Confidence that Treebeard is “smarter” — same weights; tiny checks only
- Multi-slot as a user-facing metric (correctly demoted)

## What was still useful

1. **True control** (Original Qwen = clean upstream, not knobs-off on our binary)
2. **Single-agent sequential** numbers (honest solo-user speed)
3. **Packaging / release path** + methodology correction
4. Runtime specialization exists (multi-slot + modest single-agent tg)

## Identity (keep)

> Treebeard = measured agent **runtime package** on open Qwen weights (llama.cpp contribution shape).

## Paths

| Item | Path |
|------|------|
| Single-agent A/B | `results/single-agent-ab-20260728T213156Z/` |
| Control vs Treebeard scorecard | `SCORECARD_CONTROL_VS_TREEBEARD.md` |
| GitHub PR | https://github.com/newjordan/treebeard/pull/1 |
| Release notes | `docs/RELEASE-20260728.md` on PR branch |

## Confidence check (straight)

| Question | Answer |
|----------|--------|
| Did we ship a useful model upgrade? | **No** — same Qwen weights |
| Did we improve solo decode a bit on B70? | **Maybe / small yes** — ~+15% tg on tiny suite |
| Is 94 still the quality card? | **Yes** — not revalidated today |
| Was the day mostly fleet ABA theater? | **Yes, until corrected** |
| Worth packaging? | **Yes as docs + honest metrics**, not as a hype release |
