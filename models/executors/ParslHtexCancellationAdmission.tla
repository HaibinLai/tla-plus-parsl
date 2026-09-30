--------------------------- MODULE ParslHtexCancellationAdmission ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX cancellation before dispatch.
 *
 * HTEXFuture inherits concurrent.futures.Future.cancel().  The executor does
 * not retract a successfully queued task when that call returns true.  The
 * current branch therefore dispatches a task whose logical Future is already
 * cancelled; its result reaches set_result and can terminate the result
 * worker.  The fixed branch discards the queued task and ignores a late
 * result without killing the worker.
 *************************************************************************** *)

CONSTANT USE_FIXED

FutureStates == {"pending", "cancelled", "done"}
WireStates == {"queued", "discarded", "dispatched", "result", "consumed"}
WorkerStates == {"idle", "running", "done"}

VARIABLES future, wire, worker, resultConsumed, workerAlive
vars == <<future, wire, worker, resultConsumed, workerAlive>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ future = "pending"
    /\ wire = "queued"
    /\ worker = "idle"
    /\ resultConsumed = FALSE
    /\ workerAlive = TRUE

Cancel ==
    /\ future = "pending"
    /\ future' = "cancelled"
    /\ UNCHANGED <<wire, worker, resultConsumed, workerAlive>>

Dispatch ==
    /\ future = "cancelled"
    /\ wire = "queued"
    /\ worker = "idle"
    /\ IF USE_FIXED
          THEN /\ wire' = "discarded"
               /\ worker' = "idle"
          ELSE /\ wire' = "dispatched"
               /\ worker' = "running"
    /\ UNCHANGED <<future, resultConsumed, workerAlive>>

Complete ==
    /\ worker = "running"
    /\ worker' = "done"
    /\ wire' = "result"
    /\ UNCHANGED <<future, resultConsumed, workerAlive>>

DeliverLateResult ==
    /\ wire = "result"
    /\ wire' = "consumed"
    /\ resultConsumed' = TRUE
    /\ IF USE_FIXED
          THEN workerAlive' = TRUE
          ELSE workerAlive' = FALSE
    /\ UNCHANGED <<future, worker>>

Next ==
    \/ Cancel
    \/ Dispatch
    \/ Complete
    \/ DeliverLateResult
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ future \in FutureStates
    /\ wire \in WireStates
    /\ worker \in WorkerStates
    /\ resultConsumed \in BOOLEAN
    /\ workerAlive \in BOOLEAN

CancellationAdmissionSafety ==
    future = "cancelled" =>
        /\ worker \in {"idle", "done"}
        /\ wire \in {"queued", "discarded", "consumed"}

CancelledResultWorkerSafety ==
    future = "cancelled" => workerAlive

=============================================================================
