--------------------------- MODULE ParslPbsproMissingStatus ---------------------------
EXTENDS Naturals

(***************************************************************************
 * PBS Pro status polling with a successful response that omits an active job.
 *
 * PBSProProvider currently treats every locally known job absent from a
 * successful qstat response as COMPLETED.  The fixed branch keeps the
 * resource non-terminal (represented here as UNKNOWN) until qstat reports an
 * explicit terminal state.
 ***************************************************************************)

CONSTANT USE_FIXED, RESPONSE_HAS_JOB

VARIABLES resourceState, pollAlive, explicitTerminal
vars == <<resourceState, pollAlive, explicitTerminal>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ RESPONSE_HAS_JOB \in BOOLEAN
    /\ resourceState = "running"
    /\ pollAlive = TRUE
    /\ explicitTerminal = FALSE

Poll ==
    /\ pollAlive
    /\ IF RESPONSE_HAS_JOB
          THEN /\ resourceState' = "completed"
               /\ explicitTerminal' = TRUE
          ELSE IF USE_FIXED
               THEN /\ resourceState' = "unknown"
                    /\ explicitTerminal' = FALSE
               ELSE /\ resourceState' = "completed"
                    /\ explicitTerminal' = FALSE
    /\ UNCHANGED pollAlive

Next == Poll \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ RESPONSE_HAS_JOB \in BOOLEAN
    /\ resourceState \in {"running", "completed", "unknown"}
    /\ pollAlive \in BOOLEAN
    /\ explicitTerminal \in BOOLEAN

MissingObservationSafety ==
    ~RESPONSE_HAS_JOB => resourceState # "completed"

ExplicitTerminalSafety ==
    resourceState = "completed" => explicitTerminal

=============================================================================
