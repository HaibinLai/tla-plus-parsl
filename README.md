# TLA+ Models of Parsl

This repository contains small executable TLA+ abstractions of Parsl. The models separate
logical tasks and Futures from physical execution attempts and explore normal execution,
dependencies, retries, provider/executor failures, staging, serialization, and stale results.

## Documentation

- [Full model description and TLC results](docs/overview.md)
- [Core workflow models](docs/core.md)
- [Serialization and transport models](docs/serialization.md)
- [Executor and HTEX models](docs/executors.md)
- [Provider and scheduler models](docs/providers.md)
- [Staging and data-transfer models](docs/staging.md)
- [Dataflow, Future, Join, retry, and memoization models](docs/dataflow.md)
- [Monitoring models](docs/monitoring.md)
- [Clock and strategy models](docs/clock-strategy.md)
- [Coverage matrix](docs/coverage-matrix.md)
- [Modeling goal and stopping rule](docs/modeling-goal.md)
- [v0.1 validation report](docs/v0.1-report.md)
- [Project report](docs/project-report.md)
- [Article and podcast plan](docs/article-podcast-plan.md)
- [Technical article draft](docs/article-draft.md)
- [Podcast script draft](docs/podcast-script.md)
- [Project progress log](docs/progress-log.md)

Runtime probes are under [`tests/`](tests/). The repository currently contains 761 unittest
methods; the foundational smoke runner executes 486 named probe entries and 754 TLC
configurations.
TLC commands and measured state-space results are maintained in [`docs/overview.md`](docs/overview.md).

## Quick start

```bash
/tmp/parsl-venv/bin/python -m unittest discover -s tests -p 'test_*runtime.py' -q
```

For TLC, install Java 17 and `tla2tools.jar`, then use the commands in the full overview.

To rerun the recent cross-layer TLC smoke set (including the intentional current-branch
counterexamples), use:

```bash
JAVA_BIN=/path/to/java TLA_JAR=/path/to/tla2tools.jar ./scripts/tlc_recent_models.sh
```

## Project status and findings

The repository is a bounded protocol audit of Parsl, with communication as the primary focus and
asynchronous interleavings as the secondary focus. It is intentionally an executable abstraction,
not a line-by-line reimplementation of Parsl.

The current audit records **318 bug-ledger entries**, representing approximately **317 unique
numeric BUG identifiers** (some entries are refinements of an existing finding). Findings are
source-backed protocol risks observed in the pinned Parsl source. They are not automatically
confirmed production defects or claims that Parsl maintainers have accepted a fix.

The repository currently contains:

- 676 TLA+ modules and 1,478 configuration files;
- 761 unittest methods and 490 runtime-probe files;
- 486 named runtime entries in the foundational regression;
- 754 TLC configurations in the foundational regression.

The models cover, among other behaviors:

- DAG dependencies, Futures, retries, timeouts, cancellation, and stale results;
- logical tasks separated from physical execution attempts;
- HTEX/ZeroMQ task, result, command, ACK, heartbeat, registration, and manager-loss paths;
- malformed frames, serializer boundaries, duplicate delivery, late delivery, and ownership after
  a failed send;
- executor/worker failure, provider provisioning, scaling, monitoring terminality, and shutdown;
- memoization, `join_app`, nested joins, DataFuture readiness, staging, and atomic publication.

Representative communication findings include task loss after HTEX dispatch-send failure,
interchange termination after malformed command or command-reply failures, manager-loss result
transport failure, and heartbeat-ACK send failure. Each recent concrete finding has a Current TLA+
configuration that preserves the source-like behavior, a Fixed configuration expressing the
candidate safe protocol, and a targeted runtime probe against the installed Parsl code.

The latest complete verification passed:

```text
TLC foundational smoke:       754/754 configurations passed
Python runtime smoke:         486/486 entries passed
```

Current configurations in the recent-model suite intentionally produce counterexamples; the
corresponding Fixed configurations must pass. A passing bounded TLC run proves only the stated
finite model and constants. It does not prove unbounded Parsl correctness, cover every backend,
or simulate every implementation detail in the Parsl paper.
