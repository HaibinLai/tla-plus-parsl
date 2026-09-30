--------------------------- MODULE ParslKubernetesEmptyPhase ---------------------------
EXTENDS Naturals

(***************************************************************************
 * KubernetesProvider._status receives a successful pod object but updates
 * local state only when `pod.status.phase` is truthy.  A missing/None phase
 * therefore leaves a RUNNING record unchanged.  FIXED models translating a
 * missing phase into UNKNOWN instead of silently preserving RUNNING.
 ***************************************************************************)

CONSTANTS PHASE_PRESENT, FIXED
VARIABLES phase, localState
vars == <<phase, localState>>

Init ==
    /\ PHASE_PRESENT \in BOOLEAN
    /\ FIXED \in BOOLEAN
    /\ phase = "response"
    /\ localState = "running"

Poll ==
    /\ phase = "response"
    /\ IF PHASE_PRESENT
          THEN /\ phase' = "updated"
               /\ localState' = "terminal-or-known"
          ELSE IF FIXED
               THEN /\ phase' = "updated"
                    /\ localState' = "unknown"
               ELSE /\ phase' = "skipped"
                    /\ localState' = "running"

Next ==
    \/ Poll
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ PHASE_PRESENT \in BOOLEAN
    /\ FIXED \in BOOLEAN
    /\ phase \in {"response", "updated", "skipped"}
    /\ localState \in {"running", "terminal-or-known", "unknown"}

MissingPhaseSafety == phase # "skipped"

=============================================================================
