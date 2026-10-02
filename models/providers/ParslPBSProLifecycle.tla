--------------------------- MODULE ParslPBSProLifecycle ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Small composition model for PBSProProvider.
 *
 * The model connects qsub admission, qstat observations, local resource
 * ownership, and cancellation.  Scheduler output is deliberately symbolic:
 * the important contract is that a successful submission has a trackable job,
 * a missing qstat record is not proof of completion, and foreign/cancelled
 * identifiers cannot abort the provider loop.
 ***************************************************************************)

CONSTANT USE_FIXED

Phases == {"ready", "submitted", "running", "completed", "failed", "cancelled", "crashed"}
Observations == {"none", "queued", "running", "completed", "failed", "missing", "foreign", "malformed"}

VARIABLES phase, resourceKnown, observation, explicitTerminal, cancelRequested
vars == <<phase, resourceKnown, observation, explicitTerminal, cancelRequested>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "ready"
    /\ resourceKnown = FALSE
    /\ observation = "none"
    /\ explicitTerminal = FALSE
    /\ cancelRequested = FALSE

SubmitGood ==
    /\ phase = "ready"
    /\ phase' = "submitted"
    /\ resourceKnown' = TRUE
    /\ observation' = "none"
    /\ explicitTerminal' = FALSE
    /\ cancelRequested' = FALSE

SubmitEmpty ==
    /\ phase = "ready"
    /\ IF USE_FIXED
          THEN /\ phase' = "failed"
               /\ resourceKnown' = FALSE
          ELSE /\ phase' = "submitted"
               /\ resourceKnown' = FALSE
    /\ UNCHANGED <<observation, explicitTerminal, cancelRequested>>

BeginPoll ==
    /\ phase \in {"submitted", "running"}
    /\ resourceKnown
    /\ phase' = "running"
    /\ UNCHANGED <<resourceKnown, observation, explicitTerminal, cancelRequested>>

Observe(value) ==
    /\ phase \in {"submitted", "running"}
    /\ resourceKnown
    /\ value \in {"queued", "running", "completed", "failed", "missing", "foreign", "malformed"}
    /\ observation' = value
    /\ IF value = "completed" /\ USE_FIXED /\ cancelRequested THEN
           /\ phase' = "cancelled"
           /\ explicitTerminal' = FALSE
       ELSE IF value = "completed" THEN
           /\ phase' = "completed"
           /\ explicitTerminal' = TRUE
       ELSE IF value = "failed" THEN
           /\ phase' = "failed"
           /\ explicitTerminal' = TRUE
       ELSE IF value = "missing" /\ USE_FIXED THEN
           /\ phase' = "running"
           /\ explicitTerminal' = FALSE
       ELSE IF value = "foreign" /\ ~USE_FIXED THEN
           /\ phase' = "crashed"
           /\ explicitTerminal' = FALSE
       ELSE IF value = "malformed" /\ ~USE_FIXED THEN
           /\ phase' = "crashed"
           /\ explicitTerminal' = FALSE
       ELSE
           /\ phase' = "running"
           /\ explicitTerminal' = FALSE
    /\ UNCHANGED <<resourceKnown, cancelRequested>>

LoseResource ==
    /\ phase \in {"submitted", "running"}
    /\ resourceKnown
    /\ resourceKnown' = FALSE
    /\ phase' = "running"
    /\ UNCHANGED <<observation, explicitTerminal, cancelRequested>>

Cancel ==
    /\ phase \in {"submitted", "running"}
    /\ cancelRequested
    /\ resourceKnown
    /\ phase' = "cancelled"
    /\ UNCHANGED <<resourceKnown, observation, explicitTerminal, cancelRequested>>

RequestCancel ==
    /\ phase \in {"submitted", "running"}
    /\ cancelRequested' = TRUE
    /\ UNCHANGED <<phase, resourceKnown, observation, explicitTerminal>>

CancelStale ==
    /\ phase \in {"submitted", "running"}
    /\ cancelRequested
    /\ ~resourceKnown
    /\ IF USE_FIXED THEN phase' = "cancelled" ELSE phase' = "crashed"
    /\ UNCHANGED <<resourceKnown, observation, explicitTerminal, cancelRequested>>

Next ==
    \/ SubmitGood
    \/ SubmitEmpty
    \/ BeginPoll
    \/ \E value \in {"queued", "running", "completed", "failed", "missing", "foreign", "malformed"} : Observe(value)
    \/ LoseResource
    \/ RequestCancel
    \/ Cancel
    \/ CancelStale
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ resourceKnown \in BOOLEAN
    /\ observation \in Observations
    /\ explicitTerminal \in BOOLEAN
    /\ cancelRequested \in BOOLEAN

NoAbort == phase # "crashed"
SubmitContract == phase = "submitted" => resourceKnown
MissingIsNotCompletion == observation = "missing" => phase # "completed"
TerminalEvidence == phase = "completed" => explicitTerminal
CancellationSafety == cancelRequested => phase # "completed"

=============================================================================
