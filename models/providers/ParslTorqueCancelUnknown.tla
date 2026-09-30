--------------------------- MODULE ParslTorqueCancelUnknown ---------------------------
EXTENDS Naturals

(***************************************************************************
 * TorqueProvider.cancel treats a successful qdel response as authoritative
 * but indexes local resources for every requested ID.  A stale ID removed by
 * polling causes a KeyError after the remote cancellation already succeeded.
 * USE_FIXED makes local cancellation idempotent for unknown IDs.
 ***************************************************************************)

CONSTANT USE_FIXED, LOCAL_PRESENT

VARIABLES remoteCancelled, localState, returned
vars == <<remoteCancelled, localState, returned>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ LOCAL_PRESENT \in BOOLEAN
    /\ remoteCancelled = FALSE
    /\ localState = IF LOCAL_PRESENT THEN "running" ELSE "absent"
    /\ returned = ""

Cancel ==
    /\ remoteCancelled' = TRUE
    /\ IF USE_FIXED \/ LOCAL_PRESENT
          THEN /\ localState' = "completed"
               /\ returned' = "success"
          ELSE /\ UNCHANGED <<localState, returned>>

Next == Cancel \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ LOCAL_PRESENT \in BOOLEAN
    /\ remoteCancelled \in BOOLEAN
    /\ localState \in {"running", "absent", "completed"}
    /\ returned \in {"", "success"}

StaleCancelSafety ==
    remoteCancelled => returned = "success"

=============================================================================
