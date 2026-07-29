# Claims rule (binding for site, README, release notes)

## Rule

**No flash.** If a number or superlative appears in public copy, it must carry:

1. **What was measured** (suite / instrument name),
2. **Shape** (model quant, slots, context, seed, hardware) when relevant,
3. **Artifact** (path to `result.json` / `REPORT.md` / checksummed evidence).

If you cannot attach those three, **do not publish the claim**.

## Forbidden patterns

| Pattern | Why it fails |
|---------|----------------|
| “94/100-verified server” | 94 is one named Agent Bench freeze, not a property of every `treebeard serve` process |
| “verified OpenAI-compatible” without a test | Compatibility is a protocol fact; “verified” needs a smoke that hit `/v1/chat/completions` |
| Bare “+283% faster” | Must say multi-slot p50/agent vs Original Qwen control, stock Q5, np=12 |
| “quality champion” / “Excellent” as product marketing | Rating string from a tool is fine next to the run; not a brand slogan |
| Pillar slogans (“Better answers…”) with unlinked historical numbers | Numbers without paths are theater |
| Implying every install equals the freeze score | Different pin/quant/build → different score (stock-Q5 control A/B = 91 both arms) |

## Allowed patterns

```
Agent Bench 69 · np=1 · c=262144 · temp 0 · seed 42 · tool-eval-bench 2.1.0
Original Qwen control 91/100 (125/138) · Treebeard 91/100 (126/138)
→ results/private-verification-20260728/agent-bench-ab-20260728T220230Z/
```

```
Historical freeze 94/100 (130/138) · B70 + GB10 · same suite shape · 2026-07-17 revalidation
→ results/agent/single-slot-94/result.json (+ nvidia-result.json)
```

## Scope notes

- **OpenAI-compatible** means the server exposes `/v1/chat/completions` (and related routes). Do not prefix with “94-verified.”
- **Installer SHA-256 verified** is about file integrity, not agent quality.
- **Multi-slot** numbers are concurrent capacity, never single-user chat speed.

## Enforcement

Before merging docs/site changes: grep for bare scores (`94/100`, `+28`, `+283`, `91=91`) and confirm each has a linked artifact in the same section.
