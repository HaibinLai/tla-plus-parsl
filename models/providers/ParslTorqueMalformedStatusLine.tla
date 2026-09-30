--------------------------- MODULE ParslTorqueMalformedStatusLine ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Torque qstat status parsing.
 *
 * The current parser indexes the state column before validating record
 * length.  A truncated scheduler line crashes the whole poll; USE_FIXED
 * skips malformed records and preserves the polling pass.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES pollState, validJobUpdated
vars == <<pollState, validJobUpdated>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ pollState = "polling"
    /\ validJobUpdated = FALSE

MalformedLine ==
    /\ pollState = "polling"
    /\ pollState' = IF USE_FIXED THEN "polling" ELSE "crashed"
    /\ UNCHANGED validJobUpdated

ValidLine ==
    /\ pollState = "polling"
    /\ pollState' = "updated"
    /\ validJobUpdated' = TRUE

Next == MalformedLine \/ ValidLine \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ pollState \in {"polling", "updated", "crashed"}
    /\ validJobUpdated \in BOOLEAN

MalformedIsolation ==
    pollState # "crashed"

=============================================================================
