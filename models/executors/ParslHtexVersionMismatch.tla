--------------------------- MODULE ParslHtexVersionMismatch ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * HTEX registration version-mismatch race.
 *
 * Interchange rejects a manager with incompatible Python/Parsl versions,
 * sets its kill event, and sends a task_id=-1 fatal result.  The executor
 * result thread sets bad state only when that fatal result is consumed.  The
 * actual path checks only bad_state_is_set in submit_payload, so USE_FIXED
 * adds an admission guard for the pending fatal/closed interchange window.
 ***************************************************************************)

CONSTANT USE_FIXED
MAX_TASKS == 2

VARIABLES interchangeAlive, managerReady, executorBad, fatalPending,
          mismatchSeen, outstanding, submitAfterMismatch
vars == <<interchangeAlive, managerReady, executorBad, fatalPending,
           mismatchSeen, outstanding, submitAfterMismatch>>

Init ==
    /\ interchangeAlive = TRUE
    /\ managerReady = FALSE
    /\ executorBad = FALSE
    /\ fatalPending = FALSE
    /\ mismatchSeen = FALSE
    /\ outstanding = 0
    /\ submitAfterMismatch = FALSE

Submit ==
    /\ ~executorBad
    /\ outstanding < MAX_TASKS
    /\ IF USE_FIXED THEN interchangeAlive /\ ~fatalPending ELSE TRUE
    /\ outstanding' = outstanding + 1
    /\ submitAfterMismatch' = IF mismatchSeen THEN TRUE ELSE submitAfterMismatch
    /\ UNCHANGED <<interchangeAlive, managerReady, executorBad,
                    fatalPending, mismatchSeen>>

CompleteTask ==
    /\ outstanding > 0
    /\ outstanding' = outstanding - 1
    /\ UNCHANGED <<interchangeAlive, managerReady, executorBad,
                    fatalPending, mismatchSeen, submitAfterMismatch>>

RegisterCompatible ==
    /\ interchangeAlive
    /\ ~managerReady
    /\ managerReady' = TRUE
    /\ UNCHANGED <<interchangeAlive, executorBad, fatalPending,
                    mismatchSeen, outstanding, submitAfterMismatch>>

RegisterMismatch ==
    /\ interchangeAlive
    /\ ~managerReady
    /\ interchangeAlive' = FALSE
    /\ fatalPending' = TRUE
    /\ mismatchSeen' = TRUE
    /\ UNCHANGED <<managerReady, executorBad, outstanding,
                    submitAfterMismatch>>

HandleFatalResult ==
    /\ fatalPending
    /\ fatalPending' = FALSE
    /\ executorBad' = TRUE
    /\ outstanding' = 0
    /\ UNCHANGED <<interchangeAlive, managerReady, mismatchSeen,
                    submitAfterMismatch>>

Next ==
    \/ Submit
    \/ CompleteTask
    \/ RegisterCompatible
    \/ RegisterMismatch
    \/ HandleFatalResult
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ interchangeAlive \in BOOLEAN
    /\ managerReady \in BOOLEAN
    /\ executorBad \in BOOLEAN
    /\ fatalPending \in BOOLEAN
    /\ mismatchSeen \in BOOLEAN
    /\ outstanding \in 0..MAX_TASKS
    /\ submitAfterMismatch \in BOOLEAN

MismatchAdmissionSafety ==
    mismatchSeen => ~submitAfterMismatch

FatalCleanupSafety ==
    executorBad => outstanding = 0

ManagerReadinessSafety ==
    managerReady => interchangeAlive /\ ~executorBad

FatalOrderingSafety ==
    fatalPending => mismatchSeen /\ ~interchangeAlive /\ ~managerReady

=============================================================================
