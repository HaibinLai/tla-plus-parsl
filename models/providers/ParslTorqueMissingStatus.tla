--------------------------- MODULE ParslTorqueMissingStatus ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Torque status polling with a successful response that omits an active job.
 *
 * TorqueProvider._status fills every locally known job absent from qstat with
 * COMPLETED.  The fixed branch preserves a non-terminal UNKNOWN observation
 * until the scheduler reports an explicit record.
 ***************************************************************************)

CONSTANT USE_FIXED, RESPONSE_HAS_JOB

VARIABLES resourceState, explicitTerminal
vars == <<resourceState, explicitTerminal>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ RESPONSE_HAS_JOB \in BOOLEAN
    /\ resourceState = "running"
    /\ explicitTerminal = FALSE

Poll ==
    /\ IF RESPONSE_HAS_JOB
          THEN /\ resourceState' = "completed"
               /\ explicitTerminal' = TRUE
          ELSE IF USE_FIXED
               THEN /\ resourceState' = "unknown"
                    /\ explicitTerminal' = FALSE
               ELSE /\ resourceState' = "completed"
                    /\ explicitTerminal' = FALSE

Next == Poll \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ RESPONSE_HAS_JOB \in BOOLEAN
    /\ resourceState \in {"running", "completed", "unknown"}
    /\ explicitTerminal \in BOOLEAN

MissingObservationSafety ==
    ~RESPONSE_HAS_JOB => resourceState # "completed"

ExplicitTerminalSafety ==
    resourceState = "completed" => explicitTerminal

=============================================================================
