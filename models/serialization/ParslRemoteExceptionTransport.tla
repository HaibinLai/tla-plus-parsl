--------------------------- MODULE ParslRemoteExceptionTransport ---------------------------
EXTENDS Naturals

(***************************************************************************
 * RemoteExceptionWrapper object contents across executor serialization.
 *
 * A worker-side exception contains a leaf cause.  The wrapper is serialized,
 * decoded by the executor result worker, and reraised into the logical Future.
 * The model keeps the exception object distinct from the Future terminal state
 * so loss of the cause cannot be hidden by merely observing failure.
 ***************************************************************************)

VARIABLES wrapper, wire, decoded, future, observedCause
vars == <<wrapper, wire, decoded, future, observedCause>>

Init ==
    /\ wrapper = "none"
    /\ wire = "none"
    /\ decoded = "none"
    /\ future = "unresolved"
    /\ observedCause = "none"

CaptureFailure ==
    /\ wrapper = "none"
    /\ wrapper' = "root-with-leaf-cause"
    /\ UNCHANGED <<wire, decoded, future, observedCause>>

SerializeWrapper ==
    /\ wrapper = "root-with-leaf-cause"
    /\ wire' = "serialized"
    /\ UNCHANGED <<wrapper, decoded, future, observedCause>>

DecodeWrapper ==
    /\ wire = "serialized"
    /\ decoded' = "root-with-leaf-cause"
    /\ UNCHANGED <<wrapper, wire, future, observedCause>>

ReraiseIntoFuture ==
    /\ decoded = "root-with-leaf-cause"
    /\ future' = "failed"
    /\ observedCause' = "leaf"
    /\ UNCHANGED <<wrapper, wire, decoded>>

Next ==
    \/ CaptureFailure
    \/ SerializeWrapper
    \/ DecodeWrapper
    \/ ReraiseIntoFuture
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ wrapper \in {"none", "root-with-leaf-cause"}
    /\ wire \in {"none", "serialized"}
    /\ decoded \in {"none", "root-with-leaf-cause"}
    /\ future \in {"unresolved", "failed"}
    /\ observedCause \in {"none", "leaf"}

CausePreservation == future = "failed" => observedCause = "leaf"
FutureTerminality == future = "failed" => decoded = "root-with-leaf-cause"

=============================================================================
SPECIFICATION Spec

INVARIANTS
    TypeOK
    CausePreservation
    FutureTerminality
