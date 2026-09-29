--------------------------- MODULE ParslApplyDispatchBoundary ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Cross-layer apply-message boundary.  unpack_apply_message currently
 * returns every framed buffer, while execute_task expects exactly three
 * values (function, args, kwargs).  USE_FIXED models rejecting malformed
 * arity at the facade before it reaches worker invocation.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES frameCount, facadeState, workerState
vars == <<frameCount, facadeState, workerState>>

FacadeStates == {"wire", "unpacked", "rejected"}
WorkerStates == {"idle", "invoked", "rejected"}

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ frameCount = 4
    /\ facadeState = "wire"
    /\ workerState = "idle"

FacadeUnpack ==
    /\ facadeState = "wire"
    /\ facadeState' = IF USE_FIXED THEN "rejected" ELSE "unpacked"
    /\ UNCHANGED <<frameCount, workerState>>

WorkerInvoke ==
    /\ facadeState = "unpacked"
    /\ workerState = "idle"
    /\ workerState' = IF frameCount = 3 THEN "invoked" ELSE "rejected"
    /\ UNCHANGED <<frameCount, facadeState>>

Next ==
    \/ FacadeUnpack
    \/ WorkerInvoke
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ frameCount \in Nat
    /\ facadeState \in FacadeStates
    /\ workerState \in WorkerStates

InvocationAritySafety == workerState = "invoked" => frameCount = 3
FixedRejectsMalformed == USE_FIXED /\ facadeState = "rejected" => workerState = "idle"
MalformedRejectedAtFacade == facadeState # "wire" /\ frameCount # 3 => facadeState = "rejected"

=============================================================================
SPECIFICATION Spec
INVARIANTS TypeOK InvocationAritySafety FixedRejectsMalformed MalformedRejectedAtFacade
