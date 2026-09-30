# Categorized Parsl bug ledger

This directory provides a navigable component index for the complete [bug ledger](../bug-ledger.md).
The root ledger remains the canonical record: it contains each finding's current behavior, evidence,
candidate safety condition, and status. The category pages below intentionally contain references
and titles only, so a finding has one authoritative description and cannot drift between copies.

Each category includes every finding assigned to that topic. Some bugs cross component boundaries;
they are assigned to the component where the primary safety property or source implementation lives.
Use the `BUG-*` identifier to locate the full canonical entry in the root ledger.

| Category | Scope |
| --- | --- |
| [Core dataflow and Future lifecycle](core-dataflow.md) | Logical tasks, Futures, retry accounting, and generic task lifecycle. |
| [Serialization and ZMQ transport](serialization-zmq.md) | Callable/object serialization, message envelopes, sockets, and transport races. |
| [File staging and transfer](staging-files.md) | DataFuture publication, stage-in/out, archives, and transfer cleanup. |
| [Clock, heartbeat, and timeout](clock-heartbeat.md) | Wall/monotonic time, heartbeat expiry, deadlines, and timer shutdown. |
| [Monitoring and database](monitoring.md) | Monitoring queues, database transactions, message ordering, and shutdown. |
| [Executors and worker lifecycle](executors.md) | Executor admission, worker processes/threads, and result collection. |
| [Providers and scheduler adapters](providers.md) | Cloud, local, batch, and external scheduler provider behavior. |
| [`join_app` and memoization](join-memoization.md) | Join aggregation, cancellation, list semantics, and memoization keys. |

The original flat ledger is deliberately retained for stable references and review history.
