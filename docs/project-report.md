# TLA+ Parsl Project Report

## Executive summary

This project develops a small, executable TLA+ abstraction of Parsl for finding
high-probability protocol errors. The model is deliberately bounded. It focuses on
communication across process and thread boundaries, with asynchronous interleavings and
terminal-state handling as the secondary concern.

The result is not a line-by-line formalization of Parsl and does not attempt to simulate every
backend or every detail in the Parsl paper. Instead, it provides a finite, repeatable audit that
connects source-level observations to TLC counterexamples and runtime probes against the installed
Parsl implementation.

## Scope and questions

The audit asks whether a logical task can remain correctly correlated with its physical execution
attempt, message, Future, and monitoring record when normal failures occur. The primary questions
are:

- Can task and result ownership survive a failed send or a closed transport?
- Are malformed, duplicate, stale, or misrouted messages isolated from independent work?
- Can retries resolve only the current physical attempt?
- Can callbacks, cancellation, timeout, shutdown, or provider failure leave a Future pending or
  corrupt a live registry?
- Does monitoring preserve terminality and ordering when the execution path fails?

Supporting abstractions for serialization, staging, providers, clocks, memoization, and
`join_app` are included when they affect those contracts.

## Model architecture

The models are organized by protocol layer:

| Layer | Main concerns |
| --- | --- |
| Core/dataflow | DAG dependencies, logical tasks, Futures, retries, cancellation, `join_app` |
| Serialization/transport | serializer identity, multipart frames, routes, ACKs, duplicates, stale results |
| Executors/workers | HTEX, Thread, Flux, MPI, Work Queue, TaskVine, Radical-Pilot lifecycle |
| Providers | provisioning, scheduler status, cancellation, scale-in/scale-out, cleanup |
| Staging | DataFuture readiness, partial files, retries, atomic publication, transfer cleanup |
| Monitoring | queue delivery, database bookkeeping, shutdown, persistence and terminal status |
| Clock/strategy | heartbeat expiry, timeout/deadline behavior, wall-clock rollback, admission |

Where retries are relevant, the model separates:

```text
logical task -> physical attempt -> transport message -> Future/monitoring state
```

This separation is what allows the model to classify a late result as stale rather than allowing
it to overwrite the result of a newer attempt.

## Source audit

The source review uses a pinned Parsl source tree and concentrates on the finite inventory in
[`modeling-goal.md`](modeling-goal.md). The mandatory communication/async pass covers HTEX and
ZeroMQ task/result/command paths, `TasksOutgoing`, `ResultsIncoming`, `CommandClient`, manager and
worker registration, heartbeat and loss, serializer boundaries, Future correlation, callback
mutation, cancellation/timeout races, shutdown, and monitoring finalization. Provider, staging,
monitoring, and `join_app` paths are reviewed when they affect those contracts.

The final coverage matrix maps source boundaries to TLA+ modules and runtime evidence. The bug
ledger records the source location, observed transition, candidate safe behavior, and the
corresponding model/probe when a concrete finding is worth tracking.

## Findings

The current ledger contains 318 records representing approximately 317 unique numeric BUG
identifiers. Some records are refinements of an earlier finding, so the number is not a claim of
318 independent upstream defects. Findings are source-backed protocol risks reproduced in the
current implementation or in a source-level test double; they are not automatically confirmed by
Parsl maintainers.

Representative findings include:

- HTEX task dispatch can remove a task from the pending queue before a manager send succeeds.
- HTEX result forwarding and worker-pool ferrying can lose ownership when a ZMQ send fails.
- Malformed task, result, command, or serializer frames can escape a processing loop and stop
  later independent work.
- Duplicate registration, duplicate results, stale retries, and unknown task IDs can corrupt
  ownership or terminate a result worker.
- Callback execution can mutate a live task dictionary while failure fan-out is iterating it.
- Cancellation, timeout, late callbacks, or shutdown can leave Futures non-terminal or mask the
  primary application exception.
- Provider and staging failures can suppress fallback, cleanup, monitoring, or dependent-task
  admission.
- Heartbeat and wall-clock races can delay expiry, drain, monitoring, or shutdown decisions.

Recent communication refinements include:

- BUG-335: HTEX task dispatch ownership after manager ZMQ send failure;
- BUG-336: malformed HTEX command ingress isolation;
- BUG-337: HTEX command-reply send failure isolation;
- BUG-338: HTEX heartbeat ACK send failure isolation;
- a BUG-004 refinement for manager-loss synthetic result transport failure.

## Verification

Each concrete new finding follows a Current/Fixed discipline:

1. The Current configuration models the source-like transition and should produce a meaningful
   invariant violation or counterexample.
2. The Fixed configuration expresses the candidate safe ownership, isolation, or terminal-state
   protocol.
3. A focused Python probe exercises the installed Parsl path when the boundary is executable.
4. The model, probe, bug ledger, coverage matrix, and smoke scripts are updated together.

The latest complete regression passed:

```text
TLC foundational smoke:       754/754 configurations passed
Python runtime smoke:         486/486 entries passed
Repository unittest methods:  761
```

The foundational TLC runner executes the Fixed/safe configurations included in the normal gate.
The recent-model runner additionally checks that intentional Current configurations still produce
the expected counterexamples. Runtime probes use deterministic doubles or local resources unless
their name explicitly exercises a real local transfer or executor path.

## Reproduction

From the repository root, the normal gates are:

```bash
PYTHONPATH=/tmp/parsl-source \
  PYTHON_BIN=/tmp/parsl-venv/bin/python \
  PARSL_SOURCE=/tmp/parsl-source \
  bash scripts/runtime_foundational_smoke.sh

JAVA_BIN=/path/to/java \
  TLA_JAR=/path/to/tla2tools.jar \
  TLC_SIMULATE=100 \
  bash scripts/tlc_foundational_smoke.sh
```

For the source-like counterexamples and their Fixed variants:

```bash
JAVA_BIN=/path/to/java \
  TLA_JAR=/path/to/tla2tools.jar \
  bash scripts/tlc_recent_models.sh
```

The detailed model-to-source mapping is in [`coverage-matrix.md`](coverage-matrix.md). Full
component notes are in [`core.md`](core.md), [`serialization.md`](serialization.md),
[`executors.md`](executors.md), [`providers.md`](providers.md), [`staging.md`](staging.md),
[`dataflow.md`](dataflow.md), and [`monitoring.md`](monitoring.md). Concrete findings and their
evidence are indexed by [`bug-ledger.md`](bug-ledger.md).

## Interpretation and limitations

A passing TLC run proves the stated invariant only for the finite constants and transitions in
that configuration. A Current counterexample demonstrates a reachable source-like behavior, not
that every deployment will fail in production. The models abstract away unbounded Python heaps,
arbitrary object graphs, OS scheduling, real network timing, and backend-specific implementation
details. The project therefore provides evidence for protocol review and regression protection,
not an unbounded proof that Parsl is bug-free.

The stopping rule is intentionally finite: after the primary communication paths and the selected
asynchronous races have source-backed models, runtime evidence, documentation, and passing full
smoke suites, new models require an explicit scope change.
