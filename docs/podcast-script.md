# Podcast Script: What Happens When a Distributed Workflow Loses a Message?

**Format:** 30–45 minute technical episode  
**Audience:** engineers and researchers interested in workflows, distributed systems,
Python infrastructure, or formal methods  
**Working title:** *Using TLA+ to Audit Parsl’s Distributed Task Protocols*

## Episode promise

This episode follows one concrete question: if a Parsl task is removed from a queue and
the next message send fails, can a small TLA+ model tell us what state the system is left
in? We will connect source reading, a Current counterexample, a candidate Fixed protocol,
and a runtime probe. We will also be precise about what the project does not prove.

## 0:00–3:00 — Opening hook

**Host:** Imagine submitting a workflow task and watching the worker never start it. No
Python exception reaches you. The process is still alive. The task simply fell between
two asynchronous boundaries: it left one queue, but the next component never accepted
it.

That is the kind of failure we investigated in Parsl using a bounded TLA+ model. This is
not a claim that we formally verified all of Parsl or found hundreds of confirmed
upstream bugs. It is a protocol audit: a way to make ownership, ordering, and terminal
state explicit and testable.

**Optional sound cue:** a queue item being removed, followed by a failed network-send
sound.

## 3:00–8:00 — What Parsl has to coordinate

**Host:** Parsl presents a dataflow interface, but a logical task can cross the dataflow
kernel, an executor or provider, a manager and worker, a ZeroMQ message path, a result
collector, a Future, staging, and monitoring. The user thinks in terms of one task; the
implementation has many ownership boundaries.

The audit asks four questions. Who owns the logical task right now? Which physical
attempt does a result belong to? What happens if the message is malformed, duplicated,
late, or cannot be sent? And when the execution path fails, do the Future and monitoring
record still become terminal?

These questions are more revealing than a happy-path sequence diagram because the bug is
often not in the computation. It is in the transition between components.

## 8:00–13:00 — The small abstraction

**Host:** The model separates a logical task from its physical attempts. If a task is
retried, Attempt 0 and Attempt 1 are not interchangeable. Messages carry identity across
the transport. The Future and monitoring state expose completion.

```text
logical task -> physical attempt -> message -> Future/monitoring state
```

TLA+ lets us describe this as states and actions. For each source-backed scenario there
is a Current model, which preserves the source-like behavior, and a Fixed model, which
states a candidate safe protocol. TLC explores a deliberately finite state space.

The evidence ladder has four links: source transition, TLC counterexample, runtime probe,
and Fixed safety check. A source observation without a meaningful trace is not enough;
neither is a model that has no relationship to the implementation.

## 13:00–22:00 — Case study: task dispatch send failure

**Host:** Let us walk through the clearest example, HTEX task dispatch.

At the beginning, Task 42 is pending. The interchange takes it out of the pending queue
and tries to send it to a manager over ZeroMQ. Now suppose the socket is closed and the
send raises an exception.

**Read slowly:**

```text
Task 42 is pending.
The interchange pops Task 42.
The manager send fails.
Task 42 is not pending, not assigned, and not terminal.
```

That is the whole counterexample. The Future can remain pending because the system has
lost the only ownership record. The Current TLA+ model violates a no-task-loss
invariant. The Fixed model keeps ownership until send succeeds or publishes an explicit
terminal transport failure.

The project records this as BUG-335. The wording matters: it is a source-backed risk
record in this repository, not a statement that Parsl maintainers have confirmed an
upstream defect. A controlled Python probe uses a failing socket to exercise the same
boundary. The probe is useful evidence, but it is not a claim about every cluster or
network.

**Suggested on-screen diagram:**

```text
pending queue --pop--> [send] --failure--> nowhere
                       \--safe protocol--> requeue or terminal error
```

## 22:00–27:00 — Case study: retries and stale results

**Host:** Now consider a task that times out. Attempt 0 is replaced by Attempt 1, and
Attempt 1 succeeds. A delayed result from Attempt 0 arrives after the Future is already
terminal.

If the receiver checks only the logical task ID, the old result can be accepted as a
second completion or overwrite the current value. The model therefore checks both task
identity and attempt generation. The stale result is ignored without changing the
terminal Future.

This is why “retry count” is not enough as an abstraction. A retry changes which physical
attempt is authorized to resolve the logical task.

## 27:00–31:00 — Case study: callback mutation

**Host:** A third example is less obviously a network bug. During failure fan-out, a
collector iterates a live task dictionary and calls `Future.set_exception`. A callback
can synchronously remove an entry while iteration is in progress. The collector may
raise and stop, leaving unrelated Futures pending.

The candidate safe protocol snapshots the entries before invoking callbacks. This makes
an ordinary Python container mutation part of the asynchronous protocol contract.

## 31:00–36:00 — What was modeled and measured

**Host:** The repository currently contains 318 ledger records representing approximately
317 unique numeric identifiers; refinements mean this is not 318 independent confirmed
bugs. The categories include providers and scheduler adapters, executor and worker
lifecycle, serialization and ZMQ, monitoring, staging, clock/heartbeat/timeout,
`join_app` and memoization, and core Future lifecycle.

The project’s foundational regression contains 754 TLC configurations and 486 named
Python runtime entries, alongside 761 recorded unittest methods. The models cover DAG
dependencies, Future propagation, retry and stale-result handling, worker and provider
failure, staging readiness, scaling, memoization, monitoring, and communication faults.
Communication is the primary focus; asynchronous terminal-state behavior is secondary.

The complete regression passed 754 out of 754 foundational TLC configurations and 486 out
of 486 runtime entries. The normal smoke suite checks the Fixed/safe configurations. A
recent-model suite also checks that intentional Current configurations still produce
their expected counterexamples, so the demonstrations do not silently regress.

## 36:00–41:00 — What the evidence means

**Host:** A passing TLC run proves an invariant only for the finite constants and actions
in that configuration. A Current counterexample shows a reachable source-like behavior
under the model; it does not mean every production deployment fails. A runtime probe is
controlled evidence, not an exhaustive production experiment.

The model abstracts away unbounded Python heaps, arbitrary object graphs, operating-system
scheduling, real network timing, and backend-specific details. The bug ledger is not an
upstream issue tracker. These boundaries are documented because trustworthy formal
engineering depends on proportional claims.

## 41:00–45:00 — Closing lessons

**Host:** The lesson is broader than Parsl. In a distributed workflow, correctness often
means preserving ownership and terminality when communication fails. A task must remain
owned, a result must remain tied to the right attempt, and independent work must remain
isolated from malformed input or callback failure.

TLA+ did not replace reading the source code. It forced us to say who owns a task, which
attempt a result belongs to, and what must remain true after a failed send.

The code, models, probes, and reproduction commands are available in the repository.
Listeners can start with the task-dispatch model, then compare its Current and Fixed
configurations and inspect the corresponding runtime probe.

## Producer notes

- Keep the phrase “source-backed protocol risk” when discussing ledger entries.
- Do not say “318 confirmed Parsl bugs,” “TLA+ proved Parsl correct,” or “the model
  simulates every paper component.”
- Show one short TLC trace rather than a long inventory of modules.
- If demonstrating commands, use the paths in `docs/project-report.md` and state that
  the full run uses a pinned source tree and local environment.
- The article plan in `docs/article-podcast-plan.md` contains Mermaid diagrams and the
  repository activity timeline for supplementary show notes.
