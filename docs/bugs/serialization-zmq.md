# Serialization and ZMQ transport

Entries in this category are indexed here; the [root bug ledger](../bug-ledger.md) is the canonical source for full descriptions and evidence.

| ID | Finding | Full record |
| --- | --- | --- |
| BUG-002 | HTEX result worker | [BUG-002](../bug-ledger.md) |
| BUG-006 | Serialization/object identity | [BUG-006](../bug-ledger.md) |
| BUG-019 | HTEX version-mismatch admission | [BUG-019](../bug-ledger.md) |
| BUG-020 | HTEX result deserialization | [BUG-020](../bug-ledger.md) |
| BUG-021 | Result decode retry correlation | [BUG-021](../bug-ledger.md) |
| BUG-022 | Python callable serialization cache | [BUG-022](../bug-ledger.md) |
| BUG-023 | Python callable deserialization cache | [BUG-023](../bug-ledger.md) |
| BUG-024 | Python closure/function-body memoization | [BUG-024](../bug-ledger.md) |
| BUG-027 | HTEX result-batch isolation | [BUG-027](../bug-ledger.md) |
| BUG-028 | HTEX optional monitoring frame isolation | [BUG-028](../bug-ledger.md) |
| BUG-032 | HTEX executor result-frame isolation | [BUG-032](../bug-ledger.md) |
| BUG-033 | HTEX worker task-frame isolation | [BUG-033](../bug-ledger.md) |
| BUG-034 | HTEX worker task-batch schema isolation | [BUG-034](../bug-ledger.md) |
| BUG-039 | Apply-message arity validation | [BUG-039](../bug-ledger.md) |
| BUG-040 | HTEX duplicate result frame | [BUG-040](../bug-ledger.md) |
| BUG-041 | Unhashable callable serialization | [BUG-041](../bug-ledger.md) |
| BUG-063 | Serializer registry identifier collision | [BUG-063](../bug-ledger.md) |
| BUG-064 | Failed deserializer plugin cache | [BUG-064](../bug-ledger.md) |
| BUG-080 | Empty serializer registry leaks `UnboundLocalError` | [BUG-080](../bug-ledger.md) |
| BUG-091 | ResultsIncoming get after close reaches terminated ZMQ socket | [BUG-091](../bug-ledger.md) |
| BUG-096 | HTEX non-numeric priority escapes task processing | [BUG-096](../bug-ledger.md) |
| BUG-097 | HTEX non-mapping resource specification escapes task processing | [BUG-097](../bug-ledger.md) |
| BUG-098 | HTEX malformed task message escapes task processing | [BUG-098](../bug-ledger.md) |
| BUG-099 | HTEX malformed result frame escapes manager processing | [BUG-099](../bug-ledger.md) |
| BUG-100 | HTEX unknown task result kills result worker | [BUG-100](../bug-ledger.md) |
| BUG-101 | HTEX ambiguous result silently accepts conflicting payloads | [BUG-101](../bug-ledger.md) |
| BUG-102 | Unhashable callable rejected before dill serialization | [BUG-102](../bug-ledger.md) |
| BUG-103 | Callable deserialization cache aliases mutable task state | [BUG-103](../bug-ledger.md) |
| BUG-104 | Failed dynamic deserializer remains cached | [BUG-104](../bug-ledger.md) |
| BUG-139 | HTEX watchdog emits duplicate result after worker publishes success | [BUG-139](../bug-ledger.md) |
| BUG-149 | HTEX duplicate registration drops in-flight task ownership | [BUG-149](../bug-ledger.md) |
| BUG-153 | HTEX concurrent submitters reuse task IDs | [BUG-153](../bug-ledger.md) |
| BUG-154 | CommandClient remains healthy after close | [BUG-154](../bug-ledger.md) |
| BUG-157 | HTEX task ingress accepts non-numeric task IDs | [BUG-157](../bug-ledger.md) |
| BUG-158 | HTEX task ingress accepts non-mapping context | [BUG-158](../bug-ledger.md) |
| BUG-165 | TasksOutgoing sends through a closed socket | [BUG-165](../bug-ledger.md) |
| BUG-327 | HTEX ferry loses result on ZMQ send failure | [BUG-327](../bug-ledger.md) |
| BUG-335 | HTEX task dispatch loses task on ZMQ send failure | [BUG-335](../bug-ledger.md) |
| BUG-336 | HTEX command ingress escapes malformed frame | [BUG-336](../bug-ledger.md) |
