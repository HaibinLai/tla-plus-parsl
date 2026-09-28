--------------------------- MODULE ParslFutureCancellation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Bounded model of Parsl's public Future cancellation boundary.
 *
 * AppFuture.cancel and DataFuture.cancel are intentionally unsupported in
 * the current source and raise NotImplementedError.  The underlying
 * concurrent.futures object returned by a ThreadPoolExecutor can still cancel
 * work that has not started.  These are distinct contracts and must not be
 * conflated by a workflow model.
 ***************************************************************************)

CONSTANT FUTURE_KIND

Kinds == {"app", "data", "underlying"}
States == {"pending", "running", "finished", "cancelled", "error"}

VARIABLES state, cancelResult
vars == <<state, cancelResult>>

Init ==
    /\ FUTURE_KIND \in Kinds
    /\ state = "pending"
    /\ cancelResult = "none"

PublicCancel ==
    /\ state = "pending"
    /\ IF FUTURE_KIND \in {"app", "data"} THEN
           /\ state' = "error"
           /\ cancelResult' = "not-implemented"
       ELSE
           /\ state' = "cancelled"
           /\ cancelResult' = "true"

Run ==
    /\ state = "pending"
    /\ state' = "running"
    /\ UNCHANGED cancelResult

Finish ==
    /\ state = "running"
    /\ state' = "finished"
    /\ UNCHANGED cancelResult

Next ==
    \/ PublicCancel
    \/ Run
    \/ Finish
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ cancelResult \in {"none", "true", "not-implemented"}

CancellationContract ==
    /\ FUTURE_KIND \in {"app", "data"} => cancelResult # "true"
    /\ cancelResult = "not-implemented" => state = "error"
    /\ cancelResult = "true" => state = "cancelled"

=============================================================================
