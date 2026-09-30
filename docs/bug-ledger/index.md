# Categorized Parsl bug ledger

This directory is the split, component-oriented view of the complete [Parsl bug ledger](../bug-ledger.md). Each category file preserves the full original table rows, including evidence, safety conditions, and status. The flat ledger remains the compatibility/canonical index for existing links.

| Category | Entries | Full records |
| --- | ---: | --- |
| Executors and worker lifecycle | 28 | [executors/README.md](executors/README.md) |
| Serialization and ZMQ transport | 38 | [serialization/README.md](serialization/README.md) |
| Providers and scheduler adapters | 50 | [providers/README.md](providers/README.md) |
| Monitoring and database | 18 | [monitoring/README.md](monitoring/README.md) |
| File staging and transfer | 15 | [staging/README.md](staging/README.md) |
| join_app and memoization | 6 | [join/README.md](join/README.md) |
| Clock, heartbeat, and timeout | 17 | [clock/README.md](clock/README.md) |
| Core dataflow and Future lifecycle | 1 | [dataflow/README.md](dataflow/README.md) |

Every BUG ID in the flat ledger appears exactly once in these category files. Cross-component findings are assigned to the primary implementation or safety property; the original component text is preserved in each row.
