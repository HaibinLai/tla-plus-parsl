--------------------------- MODULE ParslLSFLifecycle ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Compact composition model for LSFProvider.
 *
 * bsub admission, bjobs projection, and bkill cancellation are represented
 * as finite observations.  The model keeps the provider-side resource map
 * separate from scheduler output so missing/duplicate/foreign records cannot
 * silently become valid terminal results.
 ***************************************************************************)

CONSTANT USE_FIXED

Phases == {"ready", "running", "completed", "failed", "cancelled", "crashed"}
Observations == {"none", "running", "completed", "failed", "missing", "foreign", "duplicate", "malformed"}

VARIABLES phase, resourceKnown, observation, explicitTerminal, cancelRequested
vars == <<phase, resourceKnown, observation, explicitTerminal, cancelRequested>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "ready"
    /\ resourceKnown = FALSE
    /\ observation = "none"
    /\ explicitTerminal = FALSE
    /\ cancelRequested = FALSE

Submit(outcome) ==
    /\ phase = "ready"
    /\ outcome \in {"valid", "failed", "empty", "malformed"}
    /\ IF outcome = "valid" THEN
           /\ phase' = "running"
           /\ resourceKnown' = TRUE
       ELSE
           /\ phase' = "failed"
           /\ resourceKnown' = FALSE
    /\ observation' = "none"
    /\ explicitTerminal' = FALSE
    /\ cancelRequested' = FALSE

Observe(value) ==
    /\ phase = "running"
    /\ resourceKnown
    /\ value \in {"running", "completed", "failed", "missing", "foreign", "duplicate", "malformed"}
    /\ ~(USE_FIXED /\ cancelRequested /\ value = "completed")
    /\ observation' = value
    /\ IF value = "completed" THEN
           /\ phase' = "completed"
           /\ explicitTerminal' = TRUE
       ELSE IF value = "failed" THEN
           /\ phase' = "failed"
           /\ explicitTerminal' = TRUE
       ELSE IF value = "missing" /\ ~USE_FIXED THEN
           /\ phase' = "completed"
           /\ explicitTerminal' = FALSE
       ELSE IF value \in {"foreign", "duplicate", "malformed"} /\ ~USE_FIXED THEN
           /\ phase' = "crashed"
           /\ explicitTerminal' = FALSE
       ELSE
           /\ phase' = "running"
           /\ explicitTerminal' = FALSE
    /\ UNCHANGED <<resourceKnown, cancelRequested>>

LoseResource ==
    /\ phase = "running"
    /\ resourceKnown
    /\ resourceKnown' = FALSE
    /\ UNCHANGED <<phase, observation, explicitTerminal, cancelRequested>>

RequestCancel ==
    /\ phase = "running"
    /\ cancelRequested' = TRUE
    /\ UNCHANGED <<phase, resourceKnown, observation, explicitTerminal>>

CancelSuccess ==
    /\ phase = "running"
    /\ cancelRequested
    /\ resourceKnown
    /\ phase' = "cancelled"
    /\ explicitTerminal' = TRUE
    /\ observation' = "none"
    /\ UNCHANGED <<resourceKnown, cancelRequested>>

CancelStale ==
    /\ phase = "running"
    /\ cancelRequested
    /\ ~resourceKnown
    /\ phase' = IF USE_FIXED THEN "cancelled" ELSE "crashed"
    /\ UNCHANGED <<resourceKnown, observation, explicitTerminal, cancelRequested>>

Next ==
    \/ \E outcome \in {"valid", "failed", "empty", "malformed"} : Submit(outcome)
    \/ \E value \in {"running", "completed", "failed", "missing", "foreign", "duplicate", "malformed"} : Observe(value)
    \/ LoseResource
    \/ RequestCancel
    \/ CancelSuccess
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
MissingIsNotCompletion == observation = "missing" => phase # "completed"
TerminalEvidence == phase = "completed" => explicitTerminal
CancellationSafety == cancelRequested => phase # "completed"
ResourceTerminalConsistency == phase = "completed" => resourceKnown

=============================================================================
