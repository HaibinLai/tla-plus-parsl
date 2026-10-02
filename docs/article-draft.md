# What Happens When a Distributed Workflow Loses a Message?

## Using a bounded TLA+ model to audit Parsl task protocols

Distributed workflow systems rarely fail only in the user function. A task can be
computed correctly and still never complete because a message was dropped, a retry
result arrived late, a callback changed a registry while it was being traversed, or a
monitoring record stopped before the corresponding Future became terminal. These are
protocol failures: the system has lost track of ownership, ordering, correlation, or
terminality.

This project asks whether a small executable TLA+ model can expose those risks in
Parsl, a Python workflow system with a dataflow kernel, executors, workers, providers,
file staging, monitoring, and ZeroMQ-based communication. The answer is deliberately
narrow. The model does not formalize every line of Parsl or simulate every detail in
the Parsl paper. It gives us a finite, repeatable way to connect a source-level state
transition to a TLC counterexample, a candidate safety protocol, and (where practical)
a runtime probe against the installed Parsl implementation.

## The question is ownership, not just execution

The central question is: when a task crosses several asynchronous boundaries, who owns
it, and what must remain true if the next boundary fails?

The model distinguishes four related objects:

```text
logical task -> physical attempt -> transport message -> Future/monitoring state
```

A logical task is the user-visible unit in the DAG. A physical attempt is one execution
of that task, including a retry. A message carries a task and attempt identity across a
transport boundary. The Future and monitoring record expose terminal state to the rest
of the system. Keeping these identities separate is essential. Attempt 0 can time out,
Attempt 1 can succeed, and a delayed result from Attempt 0 can still arrive. It must be
classified as stale rather than allowed to overwrite the result of the current attempt.

This is a small abstraction, but it captures the questions that are difficult to answer
by reading a happy-path call graph: can a task disappear between dequeue and send? Can a
malformed command stop independent work? Can a result be accepted for an unknown or old
attempt? Can a failure fan-out leave one Future pending because a callback changed the
collection being traversed?

## Why TLA+ helps

TLA+ describes states and transitions rather than implementation syntax. That makes
failure interleavings explicit. For each concrete source-backed finding, the repository
uses a Current/Fixed discipline. The Current model preserves the source-like transition
and is expected to produce an invariant violation or counterexample. The Fixed model
expresses a candidate safe protocol, such as retaining ownership until a send succeeds,
isolating malformed input, checking the current attempt generation, or snapshotting a
collection before callback fan-out.

TLC then explores the finite state space. A passing Fixed run is evidence for the stated
invariant under the chosen constants; it is not an unbounded proof about Python, a real
network, or every deployment. When a boundary is executable locally, a deterministic
Python probe exercises the corresponding Parsl path or a tightly scoped test double.
This three-part chain is important:

```text
source transition -> Current counterexample -> runtime evidence -> Fixed protocol
```

A suspicious line alone is not treated as a bug. Conversely, a model result is not
presented as an upstream-confirmed defect merely because it has a BUG number in this
repository. The ledger records source-backed protocol risks and their evidence.

## A representative counterexample: task dispatch

Consider the HTEX interchange path that sends queued tasks to a manager. In the source-like
transition, a pending task is removed from the queue and then passed to a ZeroMQ send.
The send can fail because a socket is closed, a peer has disappeared, or the transport
raises an exception. If the queue removal has already happened, the task is no longer
pending, assigned, or terminal. The user-visible Future can remain pending indefinitely.

The reachable trace is short:

```text
1. Task 42 is pending.
2. Interchange pops Task 42.
3. manager_sock.send_multipart fails.
4. No manager owns Task 42 and no terminal error is published.
```

The Current model violates a no-task-loss invariant. The Fixed model retains ownership
until successful transfer or emits an explicit terminal transport failure. The associated
runtime probe uses a controlled failing socket, so the result does not depend on an
unreliable external cluster. This finding is tracked as BUG-335 in the project ledger;
that label means a reproducible project record, not a claim that Parsl maintainers have
accepted it as an upstream bug.

The same reasoning applies to other HTEX boundaries. Recent communication refinements
cover malformed command ingress (BUG-336), command-reply send failure (BUG-337), and
heartbeat ACK send failure (BUG-338). A manager-loss path also has a BUG-004 refinement:
if synthetic loss results are sent while expiring a manager and that transport fails,
the task/Future relationship can remain unresolved. The candidate fixes all share a
principle: a failed transport operation must either preserve ownership for retry or
make failure explicit and terminal. It must not silently remove the only record of work.

## Two other useful case studies

### Stale results after retry

Suppose Attempt 0 times out and the logical task is retried as Attempt 1. Attempt 1
completes successfully, resolving the Future. A delayed result from Attempt 0 then arrives.
If the receiver correlates only the logical task ID, the old value can overwrite or
duplicate the current result. The model requires both logical task identity and current
physical-attempt generation. The stale message is consumed or rejected without changing
the terminal Future. This case demonstrates why retries are not merely a counter; they
change the identity of valid results.

### Callback mutation during failure fan-out

Several failure paths iterate a live task dictionary and synchronously call
`Future.set_exception`. A callback can remove an entry from that dictionary while the
collector is still iterating. The result can be an iteration exception and a partially
completed failure fan-out: some independent Futures are terminal, while others remain
pending. The candidate safe protocol snapshots the entries before invoking callbacks.
This is a useful reminder that ordinary Python callback behavior is part of the
distributed state machine once callbacks mutate ownership registries.

## What the audit contains

The current ledger contains 318 records representing approximately 317 unique numeric
BUG identifiers. Some entries are refinements, so this is not a count of 318 independent
confirmed defects. The records are grouped by protocol area:

| Category | Records |
| --- | ---: |
| Providers and scheduler adapters | 92 |
| Executors and worker lifecycle | 78 |
| Serialization and ZMQ transport | 53 |
| Monitoring and database | 32 |
| File staging and transfer | 29 |
| Clock, heartbeat, and timeout | 22 |
| `join_app` and memoization | 9 |
| Core dataflow and Future lifecycle | 3 |

The repository contains 754 TLC configurations in the foundational smoke suite and 486
named Python runtime entries. It also records 761 repository unittest methods. The model
families cover DAG dependencies, Futures, retries, cancellation, `join_app`, serializer
and multipart boundaries, HTEX and other executor lifecycles, provider provisioning,
staging readiness, monitoring, heartbeat and timeout behavior, memoization, and scaling.
The emphasis remains communication first and asynchronous terminal-state behavior second;
the additional component models are included when they affect those contracts.

The latest complete regression passed all 754 foundational TLC configurations and all 486
runtime entries. The normal gate runs the safe/Fixed configurations. A separate recent-
model runner checks that intentional Current configurations still produce their expected
counterexamples. This keeps the examples alive instead of silently turning a regression
case into a passing model.

## What this does—and does not—show

The project demonstrates a practical workflow for protocol auditing:

1. Read a bounded, explicit inventory of Parsl source paths.
2. State an ownership, correlation, isolation, or terminal-state invariant.
3. Encode a small Current and Fixed model.
4. Run TLC and, where possible, a Parsl runtime probe.
5. Record the source location, trace, candidate fix, and limits in the ledger.

It does not prove that Parsl is correct. TLC explores only the finite constants and
transitions in each configuration. The abstraction omits unbounded Python heaps,
arbitrary object graphs, operating-system scheduling, real network timing, and many
backend-specific details. A Current counterexample demonstrates a reachable source-like
behavior under the model; it does not predict that every production deployment will
fail. A runtime probe demonstrates behavior in its controlled setup; it is not a
production-scale experiment. Finally, the ledger is not an upstream issue tracker.

Those limits are a feature of the research question, not a hidden weakness. A small
model is useful when its boundary is clear, its traces are reproducible, and its claims
are proportional to the evidence. The project stops expanding when the selected
communication paths and asynchronous races have source-backed models, runtime evidence,
documentation, and passing smoke suites. New model families require an explicit scope
change.

The broader lesson is portable beyond Parsl: in a distributed workflow, correctness is
often the preservation of ownership and terminality across failure, not merely the
correctness of the function that eventually runs. TLA+ did not replace reading the
source code. It forced the audit to state who owns a task, which attempt a result belongs
to, and what must remain true when communication fails.

## Reproduce the results

From the repository root, use the documented source and virtual environment paths:

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

The source-to-model mapping is in `docs/coverage-matrix.md`; component notes, evidence,
and individual traces are linked from the project report and `docs/bug-ledger.md`.
