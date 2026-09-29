--------------------------- MODULE ParslMonitoringTaskInsertBookkeeping ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Monitoring TASK row insertion and in-memory bookkeeping.
 *
 * DatabaseManager adds a task id to inserted_tasks before the SQL INSERT
 * returns.  If that insert fails, a later TASK_INFO message is classified as
 * an UPDATE even though no TASK row exists.  The fixed branch records the id
 * only after a successful insert and retries the INSERT after failure.
 *************************************************************************** *)

CONSTANTS INSERT_SUCCEEDS, USE_FIXED

States == {"new", "inserting", "failed", "updated", "stored", "lost"}

VARIABLES state, bookkeeping, rowPresent
vars == <<state, bookkeeping, rowPresent>>

Init ==
    /\ INSERT_SUCCEEDS \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "new"
    /\ bookkeeping = FALSE
    /\ rowPresent = FALSE

BeginInsert ==
    /\ state = "new"
    /\ state' = "inserting"
    /\ bookkeeping' = IF USE_FIXED THEN bookkeeping ELSE TRUE
    /\ UNCHANGED rowPresent

InsertSuccess ==
    /\ state = "inserting"
    /\ INSERT_SUCCEEDS
    /\ state' = "stored"
    /\ bookkeeping' = TRUE
    /\ rowPresent' = TRUE

InsertFailure ==
    /\ state = "inserting"
    /\ ~INSERT_SUCCEEDS
    /\ state' = "failed"
    /\ bookkeeping' = IF USE_FIXED THEN FALSE ELSE TRUE
    /\ UNCHANGED rowPresent

RetryTaskInfo ==
    /\ state = "failed"
    /\ state' = IF bookkeeping THEN "lost" ELSE "inserting"
    /\ UNCHANGED <<bookkeeping, rowPresent>>

UpdateExisting ==
    /\ state = "failed"
    /\ bookkeeping
    /\ rowPresent
    /\ state' = "updated"
    /\ UNCHANGED <<bookkeeping, rowPresent>>

Next ==
    \/ BeginInsert
    \/ InsertSuccess
    \/ InsertFailure
    \/ RetryTaskInfo
    \/ UpdateExisting
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ INSERT_SUCCEEDS \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state \in States
    /\ bookkeeping \in BOOLEAN
    /\ rowPresent \in BOOLEAN

BookkeepingSafety == bookkeeping => rowPresent
LostTaskSafety == state = "lost" => rowPresent

=============================================================================
