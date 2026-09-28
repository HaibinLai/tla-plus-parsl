--------------------------- MODULE ParslHtexResultQueue ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * HTEX result-queue worker message handling.
 *
 * The current worker pops a Future from ``tasks`` before validating that a
 * result message contains either a result or exception field.  A malformed
 * message therefore exits the result thread with an orphaned Future.  A
 * duplicate task id can similarly fail at ``tasks.pop``.  USE_FIXED models a
 * defensive path which fails malformed messages without orphaning the Future
 * and ignores duplicates after resolution.
 ***************************************************************************)

CONSTANT USE_FIXED
FutureStates == {"pending", "done", "failed"}

VARIABLES futureState, taskPresent, workerAlive, lastMessage
vars == <<futureState, taskPresent, workerAlive, lastMessage>>

Init ==
    /\ futureState = "pending"
    /\ taskPresent = TRUE
    /\ workerAlive = TRUE
    /\ lastMessage = "none"

DeliverSuccess ==
    /\ workerAlive
    /\ taskPresent
    /\ futureState' = "done"
    /\ taskPresent' = FALSE
    /\ lastMessage' = "result"
    /\ UNCHANGED workerAlive

DeliverException ==
    /\ workerAlive
    /\ taskPresent
    /\ futureState' = "failed"
    /\ taskPresent' = FALSE
    /\ lastMessage' = "exception"
    /\ UNCHANGED workerAlive

DeliverMalformed ==
    /\ workerAlive
    /\ taskPresent
    /\ taskPresent' = FALSE
    /\ lastMessage' = "malformed"
    /\ futureState' = IF USE_FIXED THEN "failed" ELSE "pending"
    /\ workerAlive' = IF USE_FIXED THEN TRUE ELSE FALSE

DeliverDuplicate ==
    /\ workerAlive
    /\ ~taskPresent
    /\ futureState \in {"done", "failed"}
    /\ taskPresent' = FALSE
    /\ lastMessage' = "duplicate"
    /\ futureState' = futureState
    /\ workerAlive' = IF USE_FIXED THEN TRUE ELSE FALSE

InterchangeFailure ==
    /\ workerAlive
    /\ taskPresent
    /\ workerAlive' = FALSE
    /\ taskPresent' = FALSE
    /\ futureState' = "failed"
    /\ lastMessage' = "interchange_failure"

Next ==
    \/ DeliverSuccess
    \/ DeliverException
    \/ DeliverMalformed
    \/ DeliverDuplicate
    \/ InterchangeFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ futureState \in FutureStates
    /\ taskPresent \in BOOLEAN
    /\ workerAlive \in BOOLEAN
    /\ lastMessage \in {"none", "result", "exception", "malformed",
                         "duplicate", "interchange_failure"}

FutureMappingSafety ==
    futureState \in {"done", "failed"} => ~taskPresent

NoOrphanedFuture ==
    ~workerAlive => futureState \in {"done", "failed"}

MalformedMessageSafety ==
    lastMessage = "malformed" => futureState = "failed"

DuplicateSafety ==
    lastMessage = "duplicate" => futureState \in {"done", "failed"}

=============================================================================
