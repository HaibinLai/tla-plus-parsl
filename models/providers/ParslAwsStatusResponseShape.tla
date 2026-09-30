--------------------------- MODULE ParslAwsStatusResponseShape ---------------------------
EXTENDS Naturals

(***************************************************************************
 * AWSProvider.status assumes a successful describe_instances response has a
 * Reservations field.  USE_FIXED converts a missing top-level field into an
 * isolated UNKNOWN observation instead of aborting the polling pass.
 ***************************************************************************)

CONSTANT USE_FIXED, RESPONSE_VALID

VARIABLES pollAlive, observation
vars == <<pollAlive, observation>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ RESPONSE_VALID \in BOOLEAN
    /\ pollAlive = TRUE
    /\ observation = "previous"

Poll ==
    /\ IF RESPONSE_VALID \/ USE_FIXED
          THEN /\ pollAlive' = TRUE
               /\ observation' = IF RESPONSE_VALID THEN "running" ELSE "unknown"
          ELSE /\ pollAlive' = FALSE
               /\ UNCHANGED observation

Next == Poll \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ RESPONSE_VALID \in BOOLEAN
    /\ pollAlive \in BOOLEAN
    /\ observation \in {"previous", "running", "unknown"}

ResponseShapeSafety ==
    pollAlive

=============================================================================
