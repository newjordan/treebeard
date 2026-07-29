# Long-context package eval

## llama-bench (standalone, parent vs package env)

- parent file: `bench/parent.json` present=True
- package file: `bench/package.json` present=True

### parent
```
[
  {
    "n_prompt": 512,
    "n_gen": null,
    "avg_ts": 931.490634,
    "test": null
  },
  {
    "n_prompt": 2048,
    "n_gen": null,
    "avg_ts": 1235.290382,
    "test": null
  },
  {
    "n_prompt": 4096,
    "n_gen": null,
    "avg_ts": 1195.37932,
    "test": null
  },
  {
    "n_prompt": 8192,
    "n_gen": null,
    "avg_ts": 1127.628579,
    "test": null
  },
  {
    "n_prompt": 16384,
    "n_gen": null,
    "avg_ts": 1028.270097,
    "test": null
  },
  {
    "n_prompt": null,
    "n_gen": 128,
    "avg_ts": 89.863539,
    "test": null
  }
]
```
### package
```
[
  {
    "n_prompt": 512,
    "n_gen": null,
    "avg_ts": 932.80875,
    "test": null
  },
  {
    "n_prompt": 2048,
    "n_gen": null,
    "avg_ts": 1234.462252,
    "test": null
  },
  {
    "n_prompt": 4096,
    "n_gen": null,
    "avg_ts": 1195.083627,
    "test": null
  },
  {
    "n_prompt": 8192,
    "n_gen": null,
    "avg_ts": 1126.917275,
    "test": null
  },
  {
    "n_prompt": 16384,
    "n_gen": null,
    "avg_ts": 1027.399246,
    "test": null
  },
  {
    "n_prompt": null,
    "n_gen": 128,
    "avg_ts": 89.892656,
    "test": null
  }
]
```

- base: `http://127.0.0.1:8099`
- model: `pospkg-longctx-eval`

## Prefill / short decode ladder

| chars | prompt_n | pp tok/s | tg tok/s | wall_s | ok |
|------:|---------:|---------:|---------:|-------:|:--:|
| 2000 | 360 | 344.4191657785117 | 91.59941742770515 | 1.3 | yes |
| 8000 | 1403 | 1217.1782632609968 | 92.01409655959293 | 1.4 | yes |
| 16000 | 2794 | 1531.4414130479468 | 90.51043359023211 | 2.1 | yes |
| 32000 | 5578 | 1554.861408830431 | 89.1802109111988 | 3.8 | yes |
| 48000 | 8360 | 1553.5651998421904 | 86.47003380978322 | 5.6 | yes |

## Needle-in-haystack

- doc_chars: 64679
- paragraphs: 150
- score: **3/3**

- depth 0.1: PASS — Carousel → 'TB-CAR-1945-X'
- depth 0.5: PASS — Company → 'TB-COM-1970-Q'
- depth 0.9: PASS — Hadestown → 'TB-HAD-2019-Z'

## Broadway long dossier QA

- doc_chars: 61092
- score: **14/14**

- PASS: What year did Oklahoma! open? → '1943'
- PASS: Who were the writers associated with Oklahoma! in this dossier? → 'Rodgers and Hammerstein'
- PASS: In what year did West Side Story premiere on Broadway according to the dossier? → '1957'
- PASS: Who wrote the lyrics for West Side Story per the dossier? → 'Stephen Sondheim'
- PASS: Which 1968 musical is linked to counterculture rock energy in the dossier? → 'Hair'
- PASS: Which 1975 show about dancers is mentioned as a long-running phenomenon? → 'A Chorus Line'
- PASS: Which composer is tied to mega-musicals like Phantom in the dossier? → 'Andrew Lloyd Webber'
- PASS: What year does the dossier give for Phantom on Broadway? → '1988'
- PASS: Who wrote Rent according to the dossier? → 'Jonathan Larson'
- PASS: What year did Rent open per the dossier? → '1996'
- PASS: Which 2003 fantasy blockbuster is named in the dossier? → 'Wicked'
- PASS: What year did Hamilton open on Broadway per the dossier? → '2015'
- PASS: Who is credited with book, music, and lyrics for Hamilton here? → 'Lin-Manuel Miranda'
- PASS: What major disruption to Broadway does the 2020s section mention? → 'Pandemic shutdowns'

## Verdict

**STRONG — long-context speed path + retrieval/comprehension held**

