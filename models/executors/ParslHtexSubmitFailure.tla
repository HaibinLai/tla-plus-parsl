--------------------------- MODULE ParslHtexSubmitFailure ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX submit-side queue failure.
 *
 * submit_payload allocates a Future and records it in tasks before putting the
 * wire message on outgoing_q.  A queue exception must roll back that record
 * and fail the Future; the current path leaves an orphaned pending entry.
 ***************************************************************************)

CONSTANT SUBMIT_SUCCEEDS, USE_FIXED

States == {"new", "queued", "failed"}
FutureStates == {"none", "pending", "failed"}

VARIABLES state, taskPresent, futureState, taskCounter
vars == <<state, taskPresent, futureState, taskCounter>>

Init ==
    /\ SUBMIT_SUCCEEDS \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "new"
    /\ taskPresent = FALSE
    /\ futureState = "none"
    /\ taskCounter = 0

SubmitPayload ==
    /\ state = "new"
    /\ taskCounter' = taskCounter + 1
    /\ IF SUBMIT_SUCCEEDS
          THEN /\ state' = "queued"
               /\ taskPresent' = TRUE
               /\ futureState' = "pending"
          ELSE /\ state' = "failed"
               /\ taskPresent' = IF USE_FIXED THEN FALSE ELSE TRUE
               /\ futureState' = IF USE_FIXED THEN "failed" ELSE "pending"

Next ==
    \/ SubmitPayload
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ taskPresent \in BOOLEAN
    /\ futureState \in FutureStates
    /\ taskCounter \in Nat

FailureRollback ==
    state = "failed" =>
        /\ ~taskPresent
        /\ futureState = "failed"

SuccessMapping ==
    state = "queued" =>
        /\ taskPresent
        /\ futureState = "pending"

=============================================================================
