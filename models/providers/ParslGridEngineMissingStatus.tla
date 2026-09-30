--------------------------- MODULE ParslGridEngineMissingStatus ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Grid Engine status polling with a successful response that omits an active
 * job.  The current provider fills all missing local jobs as COMPLETED; the
 * fixed branch preserves an UNKNOWN observation until explicit scheduler data
 * is received.
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
