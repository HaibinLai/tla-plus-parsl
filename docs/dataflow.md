# Dataflow, Future, Join, retry, and memoization models

These models cover DataFuture propagation and cancellation, dependency traversal, Future
projection and timeout, Join semantics, callback races, nested joins, retry budgets, memoization,
resource admission, and result races.

Files live in [`models/dataflow/`](../models/dataflow/).

`ParslDependencyTraversal.tla` has explicit dictionary-value and dictionary-key configurations.
The deep resolver configurations pass with 10 distinct states each; the shallow dictionary
configuration exposes `NoNestedFutureLeak` because the nested Future reaches the worker.
The runtime dependency probe now checks both dictionary positions with the real resolver.

`ParslJoinComplete.tla` combines the main `join_app` cases in one bounded model: a single
Future, duplicate-preserving Future lists, empty lists, invalid returns, `None`-valued inner
results, and inner cancellation/failure. The current configuration exposes a
`JoinResultSafety` counterexample by collapsing duplicate list positions; the fixed configuration
preserves the sequence and checks 5,694 states with all six invariants passing.
