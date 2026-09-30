# Categorized Parsl bug ledger

This directory is the split, component-oriented view of the complete [Parsl bug ledger](../bug-ledger.md). Each category file preserves the full original table rows, including evidence, safety conditions, and status. The flat ledger remains the compatibility/canonical index for existing links.

| Category | Entries | Full records |
| --- | ---: | --- |
| Executors and worker lifecycle | 30 | [executors/README.md](executors/README.md) |
| Serialization and ZMQ transport | 40 | [serialization/README.md](serialization/README.md) |
| Providers and scheduler adapters | 53 | [providers/README.md](providers/README.md) |
| Monitoring and database | 19 | [monitoring/README.md](monitoring/README.md) |
| File staging and transfer | 15 | [staging/README.md](staging/README.md) |
| join_app and memoization | 7 | [join/README.md](join/README.md) |
| Clock, heartbeat, and timeout | 18 | [clock/README.md](clock/README.md) |
| Core dataflow and Future lifecycle | 1 | [dataflow/README.md](dataflow/README.md) |

Every BUG ID in the flat ledger appears exactly once in these category files. Cross-component findings are assigned to the primary implementation or safety property; the original component text is preserved in each row.
