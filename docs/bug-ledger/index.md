# Categorized Parsl bug ledger

This directory is the split, component-oriented view of the complete [Parsl bug ledger](../bug-ledger.md). Each category file preserves the full original table rows, including evidence, safety conditions, and status. The flat ledger remains the compatibility/canonical index for existing links.

| Category | Entries | Full records |
| --- | ---: | --- |
| Executors and worker lifecycle | 78 | [executors/README.md](executors/README.md) |
| Serialization and ZMQ transport | 53 | [serialization/README.md](serialization/README.md) |
| Providers and scheduler adapters | 92 | [providers/README.md](providers/README.md) |
| Monitoring and database | 32 | [monitoring/README.md](monitoring/README.md) |
| File staging and transfer | 29 | [staging/README.md](staging/README.md) |
| join_app and memoization | 9 | [join/README.md](join/README.md) |
| Clock, heartbeat, and timeout | 22 | [clock/README.md](clock/README.md) |
| Core dataflow and Future lifecycle | 2 | [dataflow/README.md](dataflow/README.md) |

The category files now cover 317 unique numeric BUG IDs from the canonical flat ledger. The flat
ledger also contains one refinement row reusing `BUG-259`, so it has 318 records in total.
Cross-component findings are assigned to the primary implementation or safety property; the
original component text is preserved in each row.
