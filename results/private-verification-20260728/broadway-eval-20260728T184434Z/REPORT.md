# Broadway multi-site real-world eval

- base: `http://127.0.0.1:8099`
- model: `pospkg-broadway-eval`
- tasks ok: 6/6
- mean structure score: 100.0%
- total gen wall: 280.9s

| page | score | bytes | wall_s | notes |
|------|------:|------:|-------:|-------|
| [index.html](sites/index.html) | 25/25 | 23199 | 71.3 | ok |
| [oklahoma.html](sites/oklahoma.html) | 12/12 | 13842 | 44.5 | ok |
| [west-side-story.html](sites/west-side-story.html) | 12/12 | 13526 | 42.1 | ok |
| [phantom.html](sites/phantom.html) | 12/12 | 12103 | 39.5 | ok |
| [rent.html](sites/rent.html) | 12/12 | 13763 | 44.5 | ok |
| [hamilton.html](sites/hamilton.html) | 12/12 | 12171 | 39.0 | ok |

## Verdict guide
- **Strong:** mean score ≥ 85%, all pages valid HTML with styles + footer marker
- **Usable:** mean ≥ 70%, most pages openable
- **Weak:** mean < 70% or multiple generation failures

Open: `/home/frosty40/turbo/treebeard-work/research/treebeard-pr-private/results/broadway-eval-20260728T184434Z/sites/index.html` in a browser.

## Verdict

**STRONG — real-world multi-page HTML generation held**

