# Base Qwen control vs package ABA

**True control:** clean upstream llama.cpp SYCL (no Treebeard package code) + stock Q5 + stock flags.

- OUT: `/home/frosty40/turbo/treebeard-work/research/treebeard-pr-private/results/base-vs-package-aba-20260728T204515Z`
- shape: c=262144 np=12 n_predict=96 12-agent concurrent ABA
- weights: stock Q5_K_XL (same file all arms)

| arm | binary | p50 tok/s/agent | aggregate |
|-----|--------|----------------:|----------:|
| **base** (true control) | clean upstream | 6.878384488695842 | 72.87424954682211 |
| **package** | package port + package env | 26.32923996385854 | 208.68184184801936 |
| knobs_off (old mislabeled parent) | package binary, knobs forced off | 21.81226190271184 | 182.05730099193335 |

## Lifts

- **package vs base (the real claim):** +282.78%
- package vs knobs_off (internal ablate only): +20.71%
- knobs_off vs base (package code residual with knobs off): +217.11%

## Naming correction

Earlier private ablation called knobs_off **parent**. That was wrong for product claims.
Only **package vs base** answers: does the package beat stock Qwen serving?

## Verdict

**PACKAGE BEATS BASE by 282.8% multi-slot p50 (true control)**

