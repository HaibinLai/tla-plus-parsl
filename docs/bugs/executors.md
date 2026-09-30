# Executors and worker lifecycle

Entries in this category are indexed here; the [root bug ledger](../bug-ledger.md) is the canonical source for full descriptions and evidence.

| ID | Finding | Full record |
| --- | --- | --- |
| BUG-001 | DFK retry/result delivery | [BUG-001](../bug-ledger.md) |
| BUG-004 | HTEX manager/result path | [BUG-004](../bug-ledger.md) |
| BUG-060 | Work Queue submit orphaned Future | [BUG-060](../bug-ledger.md) |
| BUG-061 | TaskVine submit orphaned Future | [BUG-061](../bug-ledger.md) |
| BUG-062 | Flux cleanup cancellation race | [BUG-062](../bug-ledger.md) |
| BUG-065 | Unhashable PoolExecutor callable cache lookup | [BUG-065](../bug-ledger.md) |
| BUG-081 | Timer re-entrant close joins current thread | [BUG-081](../bug-ledger.md) |
| BUG-092 | Falsey exception marks DataFuture ready | [BUG-092](../bug-ledger.md) |
| BUG-093 | Radical-Pilot missing failure payload passes non-exception to Future | [BUG-093](../bug-ledger.md) |
| BUG-094 | Flux provider empty status response crashes submit path | [BUG-094](../bug-ledger.md) |
| BUG-095 | Work Queue category resource key rejected by schema | [BUG-095](../bug-ledger.md) |
| BUG-109 | CommandClient ignores `max_retries` on send failure | [BUG-109](../bug-ledger.md) |
| BUG-110 | Command deadline excludes lock acquisition | [BUG-110](../bug-ledger.md) |
| BUG-112 | LocalProvider accepts zero tasks per node | [BUG-112](../bug-ledger.md) |
| BUG-113 | HTEX zero `cores_per_worker` reaches division | [BUG-113](../bug-ledger.md) |
| BUG-123 | JobStatusPoller duplicates executor registration | [BUG-123](../bug-ledger.md) |
| BUG-127 | ThreadPoolExecutor defers invalid zero thread count | [BUG-127](../bug-ledger.md) |
| BUG-131 | Thread executor resource-spec type escapes controlled validation | [BUG-131](../bug-ledger.md) |
| BUG-135 | Radical-Pilot late DONE callback crashes cancelled Future | [BUG-135](../bug-ledger.md) |
| BUG-136 | Radical-Pilot bulk shutdown drops queued task | [BUG-136](../bug-ledger.md) |
| BUG-150 | Negative retry-handler cost bypasses retry bound | [BUG-150](../bug-ledger.md) |
| BUG-151 | Non-numeric retry-handler cost leaves Future pending | [BUG-151](../bug-ledger.md) |
| BUG-159 | Empty app executor list exposes raw selection error | [BUG-159](../bug-ledger.md) |
| BUG-160 | Unknown memoization ignore key exposes raw KeyError | [BUG-160](../bug-ledger.md) |
| BUG-161 | Ignored `outputs` key is deleted twice during memo hashing | [BUG-161](../bug-ledger.md) |
| BUG-164 | Equal callable objects collide in serializer cache | [BUG-164](../bug-ledger.md) |
| BUG-166 | MPI backlog retry recurses while resources remain unavailable | [BUG-166](../bug-ledger.md) |
| BUG-167 | MPI result path asserts for tasks without node allocation | [BUG-167](../bug-ledger.md) |
