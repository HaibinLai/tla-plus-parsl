--------------------------- MODULE ParslHtexSubmitLifecycle ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX submit ordering and failure cleanup.
 *
 * HighThroughputExecutor.submit serializes the callable first. Only after
 * serialization succeeds does submit_payload allocate a task id/Future and
 * put the message on outgoing_q. A queue failure after allocation must fail
 * the Future and remove the task mapping; the current branch leaves an
 * orphaned pending entry.
 **************************************************************************)

CONSTANTS SERIALIZE_OK, QUEUE_OK, USE_FIXED

States == {"new", "serialized", "allocated", "queued", "failed"}
FutureStates == {"none", "pending", "failed"}
FailureKinds == {"none", "serialization", "queue"}

VARIABLES state, taskPresent, futureState, taskCounter, failureKind
vars == <<state, taskPresent, futureState, taskCounter, failureKind>>

Init ==
    /\ SERIALIZE_OK \in BOOLEAN
    /\ QUEUE_OK \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "new"
    /\ taskPresent = FALSE
    /\ futureState = "none"
    /\ taskCounter = 0
    /\ failureKind = "none"

SerializeSuccess ==
    /\ state = "new"
    /\ SERIALIZE_OK
    /\ state' = "serialized"
    /\ UNCHANGED <<taskPresent, futureState, taskCounter, failureKind>>

SerializeFailure ==
    /\ state = "new"
    /\ ~SERIALIZE_OK
    /\ state' = "failed"
    /\ failureKind' = "serialization"
    /\ UNCHANGED <<taskPresent, futureState, taskCounter>>

AllocateFuture ==
    /\ state = "serialized"
    /\ state' = "allocated"
    /\ taskPresent' = TRUE
    /\ futureState' = "pending"
    /\ taskCounter' = taskCounter + 1
    /\ UNCHANGED <<failureKind>>

QueueSuccess ==
    /\ state = "allocated"
    /\ QUEUE_OK
    /\ state' = "queued"
    /\ UNCHANGED <<taskPresent, futureState, taskCounter, failureKind>>

QueueFailureCurrent ==
    /\ state = "allocated"
    /\ ~QUEUE_OK
    /\ ~USE_FIXED
    /\ state' = "failed"
    /\ failureKind' = "queue"
    /\ UNCHANGED <<taskPresent, futureState, taskCounter>>

QueueFailureFixed ==
    /\ state = "allocated"
    /\ ~QUEUE_OK
    /\ USE_FIXED
    /\ state' = "failed"
    /\ failureKind' = "queue"
    /\ taskPresent' = FALSE
    /\ futureState' = "failed"
    /\ UNCHANGED <<taskCounter>>

Next ==
    \/ SerializeSuccess
    \/ SerializeFailure
    \/ AllocateFuture
    \/ QueueSuccess
    \/ QueueFailureCurrent
    \/ QueueFailureFixed
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ taskPresent \in BOOLEAN
    /\ futureState \in FutureStates
    /\ taskCounter \in Nat
    /\ failureKind \in FailureKinds

SerializationFailureSafety ==
    failureKind = "serialization" =>
        /\ state = "failed"
        /\ ~taskPresent
        /\ futureState = "none"
        /\ taskCounter = 0

QueueFailureSafety ==
    failureKind = "queue" =>
        /\ state = "failed"
        /\ ~taskPresent
        /\ futureState = "failed"

QueuedSafety ==
    state = "queued" =>
        /\ taskPresent
        /\ futureState = "pending"
        /\ failureKind = "none"

=============================================================================
