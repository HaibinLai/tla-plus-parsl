--------------------------- MODULE ParslMonitoringBatchThree ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * A three-event monitoring database transaction.
 *
 * The writer snapshots the database, writes events one at a time, and then
 * encounters a failure after the second event.  The current branch leaves
 * those partial rows visible; the fixed branch restores the snapshot before
 * reporting the batch as aborted.
 ***************************************************************************)

CONSTANT USE_FIXED

Events == {"A", "B", "C"}
Statuses == {"none", "queued", "done"}
TxStates == {"idle", "writing", "committed", "aborted"}

VARIABLES db, batch, snapshot, txState, position, failureSeen

vars == <<db, batch, snapshot, txState, position, failureSeen>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ db = [e \in Events |-> "none"]
    /\ batch = [e \in Events |-> "queued"]
    /\ snapshot = [e \in Events |-> "none"]
    /\ txState = "idle"
    /\ position = 0
    /\ failureSeen = FALSE

BeginBatch ==
    /\ txState = "idle"
    /\ snapshot' = db
    /\ txState' = "writing"
    /\ position' = 0
    /\ failureSeen' = FALSE
    /\ UNCHANGED <<db, batch>>

WriteNext ==
    /\ txState = "writing"
    /\ position < 3
    /\ LET event == CHOOSE e \in Events : e = (CASE position = 0 -> "A"
                                                   [] position = 1 -> "B"
                                                   [] OTHER -> "C")
       IN db' = [db EXCEPT ![event] = batch[event]]
    /\ position' = position + 1
    /\ UNCHANGED <<batch, snapshot, txState, failureSeen>>

InjectFailure ==
    /\ txState = "writing"
    /\ position = 2
    /\ txState' = "aborted"
    /\ failureSeen' = TRUE
    /\ db' = IF USE_FIXED THEN snapshot ELSE db
    /\ UNCHANGED <<batch, snapshot, position>>

CommitBatch ==
    /\ txState = "writing"
    /\ position = 3
    /\ txState' = "committed"
    /\ UNCHANGED <<db, batch, snapshot, position, failureSeen>>

Next ==
    \/ BeginBatch
    \/ WriteNext
    \/ InjectFailure
    \/ CommitBatch
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ db \in [Events -> Statuses]
    /\ batch \in [Events -> Statuses]
    /\ snapshot \in [Events -> Statuses]
    /\ txState \in TxStates
    /\ position \in 0..3
    /\ failureSeen \in BOOLEAN

AbortAtomicity ==
    txState = "aborted" => db = snapshot

CommitStability ==
    txState = "committed" => position = 3 /\ ~failureSeen

FailureBookkeeping ==
    failureSeen => txState = "aborted"

=============================================================================
