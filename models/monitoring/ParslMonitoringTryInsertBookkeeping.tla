--------------------------- MODULE ParslMonitoringTryInsertBookkeeping ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Monitoring TRY-row insertion and in-memory bookkeeping.
 *
 * DatabaseManager adds a task.try identifier to inserted_tries before the
 * SQL INSERT returns. If that insert fails, a later TASK_INFO for the same
 * attempt is classified as an UPDATE even though no TRY row exists.
 ***************************************************************************)

CONSTANT USE_FIXED
States == {"new", "inserting", "failed", "updated", "stored", "lost"}

VARIABLES state, bookkeeping, rowPresent
vars == <<state, bookkeeping, rowPresent>>

Init ==
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
    /\ state' = "stored"
    /\ bookkeeping' = TRUE
    /\ rowPresent' = TRUE

InsertFailure ==
    /\ state = "inserting"
    /\ state' = "failed"
    /\ bookkeeping' = IF USE_FIXED THEN FALSE ELSE TRUE
    /\ UNCHANGED rowPresent

RetryTaskInfo ==
    /\ state = "failed"
    /\ state' = IF bookkeeping THEN "lost" ELSE "inserting"
    /\ UNCHANGED <<bookkeeping, rowPresent>>

Next ==
    \/ BeginInsert
    \/ InsertSuccess
    \/ InsertFailure
    \/ RetryTaskInfo
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in States
    /\ bookkeeping \in BOOLEAN
    /\ rowPresent \in BOOLEAN

BookkeepingSafety == bookkeeping => rowPresent
LostTrySafety == state = "lost" => rowPresent

=============================================================================
