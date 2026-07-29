# Single-agent sequential A/B — Original Qwen control vs Treebeard

Shape: **np=1**, c=32768, stock Q5 both arms, B70 SYCL.
This is what one user feels — not 12-agent fleet.

| arm | task checks | tg_p50 | wall_p50 s | tg_mean |
|-----|------------:|-------:|-----------:|--------:|
| Original Qwen control | 8/10 | 77.09420140540364 | 1.7433799505233765 | 78.9359884212919 |
| Treebeard | 10/10 | 88.93357703536964 | 1.5587867498397827 | 90.92518794718758 |

## Per-task

| task | control ok | treebeard ok | control tg | treebeard tg | control wall | treebeard wall |
|------|:----------:|:------------:|-----------:|-------------:|-------------:|---------------:|
| code_small | 0/2 | 2/2 | 77.09420140540364 | 88.93357703536964 | 1.9090492725372314 | 1.5587867498397827 |
| html_snippet | 2/2 | 2/2 | 76.67064558843133 | 88.51395040195331 | 3.6147189140319824 | 3.0518131256103516 |
| medium_summary | 2/2 | 2/2 | 76.94290440589648 | 88.78917330405466 | 1.7433799505233765 | 1.7854588031768799 |
| reason_short | 2/2 | 2/2 | 84.50228938166688 | 96.75909614856086 | 0.33469605445861816 | 0.19181418418884277 |
| short_fact | 2/2 | 2/2 | 79.46990132506113 | 91.63014284599942 | 0.5228031873703003 | 0.42013823986053467 |

## Honest read

- Single-agent decode speed: Treebeard **faster** tg_p50 88.9 vs control 77.1 (+15.4%).
- Simple task checks: control **8/10**, Treebeard **10/10** (tiny suite, not Agent Bench).
- This does **not** replace public Agent Bench 94; it is a minimal single-user smoke.

