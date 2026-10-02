# Modeling goal and stopping rule

## Objective

Build a small, executable TLA+ abstraction of Parsl that is useful for finding
high-probability protocol errors. The model is deliberately bounded: it is not
intended to reproduce every Python implementation detail or every scheduler
backend.

The primary focus is communication. The secondary focus is asynchronous
interleaving and terminal-state handling. Other Parsl behavior is modeled only
when it is needed to make those two areas meaningful.

## Priority order

### 1. Communication (primary)

The communication audit covers the source paths that carry task and result
state across process or thread boundaries:

- HTEX/ZeroMQ task, result, command, ACK, retry, duplicate, and late-message paths;
- `TasksOutgoing`, `ResultsIncoming`, and `CommandClient` send/receive and close races;
- manager/worker registration, heartbeat, loss, and reconnect behavior;
- malformed frame, frame-count, task-ID, serializer, and route validation;
- ownership of a result when a send fails (requeue, explicit failure, or loss);
- correlation among logical task, physical attempt, message, Future, and monitoring row.

Each high-confidence boundary should have a bounded Current/Fixed TLA+ model and,
when the behavior is concrete, a runtime probe using the installed Parsl code and
in-process ZMQ.

### 2. Asynchronous behavior (secondary)

The async audit covers only interleavings that can change observable correctness:

- callback execution while a live dictionary, list, or Future registry is mutated;
- cancellation and timeout racing with completion, retry, or late delivery;
- shutdown/close racing with queued work, callbacks, or monitoring finalization;
- executor/provider failure fan-out and preservation of independent Futures;
- ordering between Future terminal state, result publication, and monitoring state.

The model should separate logical tasks from physical attempts and should make
terminal-state stability and stale-result handling explicit.

### 3. Supporting abstractions

Serialization, Python object contents, staging/file bytes, heartbeat clocks,
providers, and `join_app` are included only to the extent that they affect the
communication or asynchronous contracts above. Existing models remain valid;
new work should prefer cross-layer refinements over duplicate single-component
models.

## Required evidence for a new finding

Do not add a model merely because an implementation looks unusual. A new finding
must have all of the following:

1. a precise source location and an identified state transition;
2. a small runtime reproduction when the boundary is executable;
3. a Current configuration with a meaningful invariant violation or counterexample;
4. a Fixed configuration that expresses the candidate safe protocol;
5. documentation and a bug-ledger entry when the behavior is a concrete risk.

Duplicate coverage and speculative findings are out of scope.

## Completion criteria

This project is considered complete when:

- the primary task/result/command/ACK/heartbeat communication paths have been
  source-audited at the protocol boundaries listed above;
- the important asynchronous races in those paths have bounded models;
- logical task, physical attempt, message correlation, Future state, and
  monitoring terminality are represented where relevant;
- every new model has a targeted runtime/TLC check, and the full smoke suites pass;
- the repository contains a final coverage matrix, bug ledger, and reproduction guide.

After these criteria are met, no additional model is added unless the project
scope is explicitly changed. The goal is a useful finite audit, not exhaustive
modeling of all Parsl source files.

## Explicit non-goals

- exhaustive line-by-line modeling of all Parsl backends;
- unbounded Python heap, network scheduling, or OS thread behavior;
- claiming that a passing bounded TLC run proves the entire Parsl implementation;
- continuing to expand the model solely to increase file or case counts.
