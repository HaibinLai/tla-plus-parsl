# AI Code Output versus Project Growth

This is a preliminary test of the hypothesis that AI-generated code per unit
of work decreases as the project becomes more complex.

## Measurement

The analysis uses Git history from the project session. A code line is an
addition or deletion in non-documentation Python, TLA+, CFG, shell, or config
files; `docs/` and `site/` are excluded. Project size is approximated by
cumulative net additions minus deletions. This is a useful engineering proxy,
not a complete complexity metric.

| UTC day | Commits | Median code additions/commit | Code additions | Classified turns | Code additions/turn | Cumulative net lines |
|---|---:|---:|---:|---:|---:|---:|
| 2026-09-28 | 324 | 103.0 | 32,776 | 345 | 95.0 | 32,552 |
| 2026-09-29 | 338 | 34.5 | 18,569 | 376 | 49.4 | 51,058 |
| 2026-09-30 | 646 | 15.0 | 33,380 | 588 | 56.8 | 84,122 |
| 2026-10-01 | 462 | 0.0 | 5,982 | 241 | 24.8 | 90,097 |
| 2026-10-02 | 195 | 88.0 | 15,814 | 210 | 75.3 | 105,559 |
| 2026-10-03 | 1 | 0.0 | 0 | 1 | 0.0 | 105,559 |
| 2026-10-19 | 6 | 81.5 | 698 | 6 | 116.3 | 106,255 |

## Interpretation

There is evidence for a temporary decline in marginal code output: the median
additions per commit drop from 103 lines to 0 lines between September 28 and
October 1, while the cumulative code/model size grows from roughly 32.6k to
90.1k lines. However, the trend is not monotonic: output rebounds to 88 lines
per commit and 75.3 lines per classified turn on October 2.

The more defensible interpretation is phase-dependent work. September 29–30
contains substantial bug-ledger, verification, and source-audit activity, and
many small corrective/configuration commits. October 2 contains a new batch of
communication and protocol models, producing larger additions again. The data
therefore supports “AI work shifts from construction to audit/refinement as
complexity rises” more strongly than “AI coding output always decreases.”

## Confounders and next measurement

Git commit size is not the same as model output size: commit batching, generated
TLC configurations, retries, and documentation-only turns affect the metric.
The next stronger test should record per-turn patches directly, separate new
models from repairs, and normalize by verified behavior (new TLC states,
invariants, and runtime probes passed). The generated figure is
`site/dist/code-output-trend.svg`.
