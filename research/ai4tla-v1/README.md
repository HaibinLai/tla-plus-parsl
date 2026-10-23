# AI4TLA+ study v1: frozen task inventory, candidate gold evidence

This directory turns the Parsl audit into a testable research design. It is not
yet a paper result. The task IDs, target source revision, positive evidence
links, and abstention controls are fixed here; prompt packets, independent gold
review, and multi-model runs are still required before making comparative
claims.

## Primary research question

> On bounded communication and asynchronous-failure tasks from a real Python
> runtime, does an explicit source-to-model evidence gate reduce unsupported
> defect claims and increase reproducible verification episodes compared with
> an agent given the same task, tools, and budget without the gate?

The primary outcome is the proportion of tasks ending in an independently
accepted evidence episode. An accepted positive episode requires a source
transition, a relevant finite TLA+ action/invariant, the expected TLC outcome,
a corroborating runtime probe, and a claim no stronger than those observations.
An accepted control episode says `UNKNOWN` and names the missing transition;
it must not infer a defect from an incomplete excerpt.

Secondary outcomes are unsupported-claim rate, source/model mismatch rate,
attempts to repair the model, tool calls, elapsed time, and token cost. Code
lines, commit counts, and word-frequency charts are descriptive process data,
not the primary outcome.

## Design

- **System and revision:** Parsl at `139caab94a7f2eb306512f9107b992c825974de8`.
- **Task unit:** one source-bounded failure question. The 15 positive tasks are
  drawn from the existing communication/async bug ledger; the five controls
  provide excerpts that deliberately omit the decisive transition.
- **Conditions:** (A) free-form agent workflow; (B) the same model and tools
  with a mandatory source → state/action → invariant → TLC → probe → claim
  evidence form. Both conditions get the same source packet and budget.
- **Assignment:** randomize condition order within task/model, run repeated
  seeds, isolate worktrees, and never let a model see `positive-cases.json`,
  `controls.json`, the bug ledger, or prior answers during generation.
- **Evaluation:** blind the reviewer to model and condition. Record first-pass
  and repaired outcomes separately. Two human reviewers must approve or
  dispute each candidate gold source claim before it is used for scoring.
- **Stopping rule:** do not add tasks after the first comparative run begins.
  Corrections require a versioned v2 and a documented reason.

## Twenty task slots

The positive manifest contains exact source paths/symbols, model/config paths,
named invariant, probe, and bug-ledger ID. The control manifest contains exact
visible source-line ranges and the missing evidence that makes abstention the
correct answer. The short table below is an index, not a replacement for
those machine-readable records.

| Task | Gold target | Failure or question |
|---|---|---|
| P01 / BUG-214 | named Current counterexample + probe | CommandClient send failure and later socket reuse |
| P02 / BUG-238 | named Current counterexample + probe | CommandClient receive/decode failure |
| P03 / BUG-239 | named Current counterexample + probe | concurrent CommandClient close/run |
| P04 / BUG-019 | named Current counterexample + probe | HTEX version-mismatch admission |
| P05 / BUG-020 | named Current counterexample + probe | corrupt HTEX result leaves pending Future |
| P06 / BUG-040 | named Current counterexample + probe | duplicate HTEX result frame |
| P07 / BUG-225 | named Current counterexample + probe | result-forwarding send loses ownership |
| P08 / BUG-255 | named Current counterexample + probe | unknown HTEX result type stops collector |
| P09 / BUG-098 | named Current counterexample + probe | malformed task message stops ingress |
| P10 / BUG-099 | named Current counterexample + probe | corrupt manager result frame |
| P11 / BUG-087 | named Current counterexample + probe | expired command deadline produces negative poll timeout |
| P12 / BUG-091 | named Current counterexample + probe | ResultsIncoming get after close |
| P13 / BUG-089 | named Current counterexample + probe | heartbeat expiry under clock rollback |
| P14 / BUG-218 | named Current counterexample + probe | contact timeout starved by result traffic |
| P15 / BUG-011 | named Current counterexample + probe | cancelled inner join Future |
| C01 | `UNKNOWN` | send handling is absent from excerpt |
| C02 | `UNKNOWN` | close/run interleaving is absent from excerpt |
| C03 | `UNKNOWN` | result pop/decode ordering is absent from excerpt |
| C04 | `UNKNOWN` | forwarding ownership/send ordering is absent from excerpt |
| C05 | `UNKNOWN` | join exception/cancellation path is absent from excerpt |

## Candidate gold status

All 15 positive evidence links pass structural validation. On 2026-10-23,
each Current configuration produced its named invariant violation, each Fixed
configuration completed without error, and each corresponding Python probe
passed against the pinned source checkout. This is a **machine-checked
candidate gold set**, not expert-adjudicated gold. The source excerpts have
not yet been frozen as standalone task packets, and no comparison model has
been run. The five controls pass line-range and decisive-token omission checks,
but also need human review for ambiguity and fairness.

Validate the inventory:

```sh
python3 research/ai4tla-v1/validate_study.py --parsl-source /path/to/pinned/parsl
```

Rerun all positive evidence cases with the same runner used for the pilot:

```sh
python3 infra/verify_cases.py \
  --manifest research/ai4tla-v1/positive-cases.json \
  --parsl-source /path/to/pinned/parsl \
  --java /path/to/java \
  --tla-jar /path/to/tla2tools.jar \
  --python /path/to/parsl-venv/bin/python \
  --output /path/to/local-positive-results.json
```

## What this study can and cannot claim

The 15 positive cases were selected from findings already documented in this
repository. They can evaluate *reproduction, evidence discipline, and claim
quality*; they cannot estimate how often an AI discovers novel bugs in an
unseen system. The five controls are constructed missing-evidence cases, not
naturally bug-free production scenarios. The Fixed TLA+ variants are candidate
protocols and do not imply Parsl was patched. A deterministic probe is not a
production failure-rate estimate. These limits must be prominent in any paper.

Publication readiness additionally requires: frozen source packets and prompts;
independent gold adjudication; at least two models and repeated runs under both
conditions; blind scoring; uncertainty intervals; and a clean-checkout
reproduction of representative cases. Until then, this is an experiment design
and pilot corpus, not a demonstrated treatment effect.
