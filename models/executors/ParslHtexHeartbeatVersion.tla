---------------------- MODULE ParslHtexHeartbeatVersion ----------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Combined HTEX registration and heartbeat admission model.
 *
 * A manager can be rejected during registration or can disappear after its
 * heartbeat age reaches the expiry threshold.  Both paths close the
 * interchange and schedule one fatal result.  The fixed submit path blocks
 * admission as soon as failure is observable, rather than waiting for the
 * result thread to set executorBad.
 ***************************************************************************)

CONSTANT USE_FIXED
MAX_TASKS == 2
HEARTBEAT_LIMIT == 2

VARIABLES alive, ready, bad, fatalPending, failureSeen, age, outstanding,
          acceptedAfterFailure
vars == <<alive, ready, bad, fatalPending, failureSeen, age, outstanding,
          acceptedAfterFailure>>

Init ==
    /\ alive = TRUE
    /\ ready = FALSE
    /\ bad = FALSE
    /\ fatalPending = FALSE
    /\ failureSeen = FALSE
    /\ age = 0
    /\ outstanding = 0
    /\ acceptedAfterFailure = FALSE

Submit ==
    /\ outstanding < MAX_TASKS
    /\ IF USE_FIXED
          THEN alive /\ ready /\ ~fatalPending /\ ~bad
          ELSE ~bad
    /\ outstanding' = outstanding + 1
    /\ acceptedAfterFailure' = (acceptedAfterFailure \/ failureSeen)
    /\ UNCHANGED <<alive, ready, bad, fatalPending, failureSeen, age>>

Complete ==
    /\ outstanding > 0
    /\ outstanding' = outstanding - 1
    /\ UNCHANGED <<alive, ready, bad, fatalPending, failureSeen, age,
                    acceptedAfterFailure>>

RegisterCompatible ==
    /\ alive /\ ~ready
    /\ ready' = TRUE
    /\ age' = 0
    /\ UNCHANGED <<alive, bad, fatalPending, failureSeen, outstanding,
                    acceptedAfterFailure>>

RegisterMismatch ==
    /\ alive /\ ~ready
    /\ alive' = FALSE
    /\ fatalPending' = TRUE
    /\ failureSeen' = TRUE
    /\ ready' = ready
    /\ bad' = bad
    /\ age' = age
    /\ outstanding' = outstanding
    /\ acceptedAfterFailure' = acceptedAfterFailure

Heartbeat ==
    /\ alive /\ ready
    /\ age' = 0
    /\ UNCHANGED <<alive, ready, bad, fatalPending, failureSeen,
                    outstanding, acceptedAfterFailure>>

Tick ==
    /\ alive /\ ready
    /\ age < HEARTBEAT_LIMIT - 1
    /\ age' = age + 1
    /\ UNCHANGED <<alive, ready, bad, fatalPending, failureSeen,
                    outstanding, acceptedAfterFailure>>

Expire ==
    /\ alive /\ ready
    /\ age = HEARTBEAT_LIMIT - 1
    /\ alive' = FALSE
    /\ ready' = FALSE
    /\ fatalPending' = TRUE
    /\ failureSeen' = TRUE
    /\ UNCHANGED <<bad, age, outstanding, acceptedAfterFailure>>

HandleFatal ==
    /\ fatalPending
    /\ fatalPending' = FALSE
    /\ bad' = TRUE
    /\ outstanding' = 0
    /\ UNCHANGED <<alive, ready, failureSeen, age, acceptedAfterFailure>>

Next ==
    \/ Submit
    \/ Complete
    \/ RegisterCompatible
    \/ RegisterMismatch
    \/ Heartbeat
    \/ Tick
    \/ Expire
    \/ HandleFatal
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ alive \in BOOLEAN /\ ready \in BOOLEAN /\ bad \in BOOLEAN
    /\ fatalPending \in BOOLEAN /\ failureSeen \in BOOLEAN
    /\ age \in 0..HEARTBEAT_LIMIT
    /\ outstanding \in 0..MAX_TASKS
    /\ acceptedAfterFailure \in BOOLEAN

FailureAdmissionSafety ==
    failureSeen => ~acceptedAfterFailure

HeartbeatExpirySafety ==
    age = HEARTBEAT_LIMIT => ~ready \/ fatalPending \/ ~alive

FatalOrderingSafety ==
    fatalPending => failureSeen /\ ~alive

FatalCleanupSafety ==
    bad => outstanding = 0

=============================================================================
CONSTANT USE_FIXED = TRUE

SPECIFICATION Spec

INVARIANTS
    TypeOK
    FailureAdmissionSafety
    HeartbeatExpirySafety
    FatalOrderingSafety
    FatalCleanupSafety
