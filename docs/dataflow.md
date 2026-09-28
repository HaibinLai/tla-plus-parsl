# Dataflow, Future, Join, retry, and memoization models

These models cover DataFuture propagation and cancellation, dependency traversal, Future
projection and timeout, Join semantics, callback races, nested joins, retry budgets, memoization,
resource admission, and result races.

Files live in [`models/dataflow/`](../models/dataflow/).

`ParslDependencyTraversal.tla` has explicit dictionary-value and dictionary-key configurations.
The deep resolver configurations pass with 10 distinct states each; the shallow dictionary
configuration exposes `NoNestedFutureLeak` because the nested Future reaches the worker.
The runtime dependency probe now checks both dictionary positions with the real resolver.
It also checks recursive tuple and set traversal; each deep-container configuration passes the
same dependency and no-leak invariants.

`ParslJoinComplete.tla` combines the main `join_app` cases in one bounded model: a single
Future, duplicate-preserving Future lists, empty lists, invalid returns, `None`-valued inner
results, and inner cancellation/failure. The current configuration exposes a
`JoinResultSafety` counterexample by collapsing duplicate list positions; the fixed configuration
preserves the sequence and checks 5,694 states with all six invariants passing.

`ParslJoinFailureAggregation.tla` refines the failure side of list-valued joins. Once every
inner Future is terminal, each failed Future contributes one exception entry in the original
join-list order; successful inner results are omitted. The runtime probe uses two real failed
Futures and checks the resulting `JoinError.dependent_exceptions_tids` sequence.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/dataflow/ParslJoinFailureAggregation.cfg models/dataflow/ParslJoinFailureAggregation.tla
```
