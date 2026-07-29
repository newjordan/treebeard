# Claims rule

Style: [no-ai-slop](https://github.com/newjordan/no-ai-slop). Facts: this file.

## Evidence

A public number needs:

1. Test name  
2. Shape (model/quant, slots, context, seed, hardware) when it matters  
3. Path to a result file (`result.json`, `REPORT.md`, checksummed evidence)

No path → delete the claim.

## Do not publish

| Claim shape | Problem |
|-------------|---------|
| “94-verified server” | 94 is one freeze run’s `final_score`, not every `serve` process |
| Bare “+283% faster” | Must say multi-slot p50/agent vs control, stock Q5, np=12 |
| Slogan pillars with unlinked history | Theater |
| Scores without pin/quant/build | Different pin/quant → different score (stock Q5 A/B = 91 both arms) |

## Language

- Prefer plain statements over “not X, not Y, Z.”  
- No banned AI-filler words (delve, leverage, robust, cutting-edge, …).  
- Em dashes sparingly.  
- OpenAI-compatible means HTTP routes (`/v1/chat/completions`).  
- Installer SHA-256 is file integrity, not agent quality.  
- Multi-slot numbers are concurrent capacity.

## Check before merge

Search the page for bare scores (`94/100`, `+283`, `91=91`, `194`). Each hit must sit next to test name + artifact in the same section.
