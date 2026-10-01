--------------------------- MODULE ParslAwsStateFileAtomicity ---------------------------
EXTENDS Naturals

(***************************************************************************
 * AWS provider state-file publication.
 *
 * The provider writes JSON directly to the final state path.  A crash after
 * truncation can leave corrupt state; restart then creates new infrastructure.
 * The Fixed branch writes a temporary file and atomically publishes it, so an
 * interrupted write leaves the previous valid state available.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES file, temp, infrastructure, phase
vars == <<file, temp, infrastructure, phase>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ file = "valid"
    /\ temp = "empty"
    /\ infrastructure = "existing"
    /\ phase = "idle"

BeginWriteFixed ==
    /\ phase = "idle"
    /\ USE_FIXED
    /\ phase' = "writing"
    /\ temp' = "writing"
    /\ UNCHANGED <<file, infrastructure>>

BeginWriteCurrent ==
    /\ phase = "idle"
    /\ ~USE_FIXED
    /\ phase' = "writing"
    /\ file' = "writing"
    /\ UNCHANGED <<temp, infrastructure>>

CrashDuringWriteFixed ==
    /\ phase = "writing"
    /\ USE_FIXED
    /\ phase' = "crashed"
    /\ temp' = "corrupt"
    /\ UNCHANGED <<file, infrastructure>>

CrashDuringWriteCurrent ==
    /\ phase = "writing"
    /\ ~USE_FIXED
    /\ phase' = "crashed"
    /\ file' = "corrupt"
    /\ UNCHANGED <<temp, infrastructure>>

AtomicCommit ==
    /\ phase = "writing"
    /\ USE_FIXED
    /\ temp = "writing"
    /\ temp' = "empty"
    /\ file' = "valid"
    /\ phase' = "committed"
    /\ UNCHANGED infrastructure

Restart ==
    /\ phase = "crashed"
    /\ phase' = "restarted"
    /\ infrastructure' = IF file = "valid" THEN "existing" ELSE "recreated"
    /\ UNCHANGED <<file, temp>>

Next ==
    \/ BeginWriteFixed
    \/ BeginWriteCurrent
    \/ CrashDuringWriteFixed
    \/ CrashDuringWriteCurrent
    \/ AtomicCommit
    \/ Restart
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ file \in {"valid", "writing", "corrupt"}
    /\ temp \in {"empty", "writing", "corrupt"}
    /\ infrastructure \in {"existing", "recreated"}
    /\ phase \in {"idle", "writing", "crashed", "committed", "restarted"}

NoCorruptPublished == file # "corrupt"
NoRecreateAfterCrash == infrastructure = "existing"
=============================================================================
