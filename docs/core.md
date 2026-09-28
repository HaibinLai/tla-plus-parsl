# Core workflow models

The shared `ParslAbstract` model covers logical task/Future state, physical attempts, dependency
blocking, workers, executors, providers, retries, memoization, data readiness, and stale results.

Files live in [`models/core/`](../models/core/). Start with `ParslAbstract.tla` and its scenario
configurations such as `ParslNoFailures.cfg`, `ParslTime.cfg`, and `ParslProviderFailure.cfg`.

`ParslEndToEnd.tla` is the deliberately small integration model. It connects dependency release,
task serialization, wire delivery, worker execution, result delivery, retry/timeout, and late
results. `ParslEndToEnd.cfg` intentionally permits an old attempt to resolve the Future and TLC
finds a `StaleResultSafety` counterexample. `ParslEndToEndFixed.cfg` rejects that result as stale;
TLC checks 207 states with all invariants passing.

The detailed action-to-Parsl mapping and TLC results are in [the overview](overview.md).
