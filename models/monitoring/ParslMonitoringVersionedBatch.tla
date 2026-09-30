-------------------- MODULE ParslMonitoringVersionedBatch --------------------
EXTENDS Naturals, Sequences

(***************************************************************************
 * Versioned monitoring batches.
 *
 * A database writer stages two events in one transaction.  A duplicate event
 * may fail the second write after the first event has been applied, while a
 * late older event may arrive after a newer status.  The fixed protocol rolls
 * back the whole batch and preserves a per-task version high-water mark.
 ***************************************************************************)

CONSTANT USE_FIXED

E(task, version, status) == [task |-> task, version |-> version, status |-> status]
NormalBatch == <<E("A", 1, "running"), E("A", 2, "done")>>
DuplicateBatch == <<E("A", 1, "running"), E("A", 1, "running")>>

VARIABLES dbVersion, dbStatus, batch, snapshot, txState, firstWritten,
          staleApplied
vars == <<dbVersion, dbStatus, batch, snapshot, txState, firstWritten,
          staleApplied>>

Init ==
    /\ dbVersion = [A |-> 0]
    /\ dbStatus = [A |-> "none"]
    /\ batch = <<>>
    /\ snapshot = [A |-> 0]
    /\ txState = "idle"
    /\ firstWritten = FALSE
    /\ staleApplied = FALSE

PrepareNormal ==
    /\ txState = "idle"
    /\ batch' = NormalBatch
    /\ snapshot' = dbVersion
    /\ txState' = "prepared"
    /\ UNCHANGED <<dbVersion, dbStatus, firstWritten, staleApplied>>

PrepareDuplicate ==
    /\ txState = "idle"
    /\ batch' = DuplicateBatch
    /\ snapshot' = dbVersion
    /\ txState' = "prepared"
    /\ UNCHANGED <<dbVersion, dbStatus, firstWritten, staleApplied>>

WriteFirst ==
    /\ txState = "prepared"
    /\ dbVersion[batch[1].task] < batch[1].version
    /\ dbVersion' = [dbVersion EXCEPT ![batch[1].task] = batch[1].version]
    /\ dbStatus' = [dbStatus EXCEPT ![batch[1].task] = batch[1].status]
    /\ txState' = "writing"
    /\ firstWritten' = TRUE
    /\ UNCHANGED <<batch, snapshot, staleApplied>>

WriteSecond ==
    /\ txState = "writing"
    /\ batch[2].version <= dbVersion[batch[2].task]
    /\ IF USE_FIXED
          THEN /\ dbVersion' = snapshot
               /\ dbStatus' = [A |-> "none"]
          ELSE /\ dbVersion' = dbVersion
               /\ dbStatus' = dbStatus
    /\ txState' = "rolled-back"
    /\ UNCHANGED <<batch, snapshot, firstWritten, staleApplied>>

CommitSecond ==
    /\ txState = "writing"
    /\ batch[2].version > dbVersion[batch[2].task]
    /\ dbVersion' = [dbVersion EXCEPT ![batch[2].task] = batch[2].version]
    /\ dbStatus' = [dbStatus EXCEPT ![batch[2].task] = batch[2].status]
    /\ txState' = "committed"
    /\ UNCHANGED <<batch, snapshot, firstWritten, staleApplied>>

DeliverStale ==
    /\ txState = "committed"
    /\ dbVersion["A"] = 2
    /\ IF USE_FIXED
          THEN /\ dbVersion' = dbVersion
               /\ dbStatus' = dbStatus
          ELSE /\ dbVersion' = [dbVersion EXCEPT !["A"] = 1]
               /\ dbStatus' = [dbStatus EXCEPT !["A"] = "running"]
    /\ staleApplied' = TRUE
    /\ UNCHANGED <<batch, snapshot, txState, firstWritten>>

Next ==
    \/ PrepareNormal
    \/ PrepareDuplicate
    \/ WriteFirst
    \/ WriteSecond
    \/ CommitSecond
    \/ DeliverStale
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ dbVersion \in [{"A"} -> 0..2]
    /\ dbStatus \in [{"A"} -> {"none", "running", "done"}]
    /\ batch \in Seq([task : {"A"}, version : 1..2, status : {"running", "done"}])
    /\ Len(batch) \in 0..2
    /\ snapshot \in [{"A"} -> 0..2]
    /\ txState \in {"idle", "prepared", "writing", "committed", "rolled-back"}
    /\ firstWritten \in BOOLEAN
    /\ staleApplied \in BOOLEAN

AtomicBatchSafety ==
    txState = "rolled-back" => dbVersion = snapshot

HighWaterSafety ==
    staleApplied => dbVersion["A"] = 2

StatusVersionSafety ==
    dbStatus["A"] = "done" => dbVersion["A"] = 2

=============================================================================
CONSTANT USE_FIXED = TRUE

SPECIFICATION Spec

INVARIANTS
    TypeOK
    AtomicBatchSafety
    HighWaterSafety
    StatusVersionSafety
