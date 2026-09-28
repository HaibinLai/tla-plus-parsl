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

Runtime probes are under [`tests/`](tests/). The complete runtime baseline is 311 passing tests.
TLC commands and measured state-space results are maintained in [`docs/overview.md`](docs/overview.md).

## Quick start

```bash
/tmp/parsl-venv/bin/python -m unittest discover -s tests -p 'test_*runtime.py' -q
```

For TLC, install Java 17 and `tla2tools.jar`, then use the commands in the full overview.
