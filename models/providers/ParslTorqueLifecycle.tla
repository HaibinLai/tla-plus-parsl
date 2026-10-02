--------------------------- MODULE ParslTorqueLifecycle ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Compact composition model for TorqueProvider.
 *
 * The scheduler surface is reduced to qsub/qstat/qdel observations, while
 * preserving the provider contracts: a successful submission must register a
 * resource, a missing qstat row is not terminal evidence, foreign/malformed
 * rows must not abort polling, and a successful qdel is cancellation.
 ***************************************************************************)

CONSTANT USE_FIXED

Phases == {"ready", "running", "completed", "failed", "cancelled", "crashed"}
Observations == {"none", "running", "completed", "failed", "missing", "foreign", "malformed"}

VARIABLES phase, resourceKnown, observation, explicitTerminal, cancelRequested
vars == <<phase, resourceKnown, observation, explicitTerminal, cancelRequested>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "ready"
    /\ resourceKnown = FALSE
    /\ observation = "none"
    /\ explicitTerminal = FALSE
    /\ cancelRequested = FALSE

Submit(kind) ==
    /\ phase = "ready"
    /\ kind \in {"success-id", "empty-output", "failure"}
    /\ IF kind = "success-id" THEN
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
    /\ value \in {"running", "completed", "failed", "missing", "foreign", "malformed"}
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
       ELSE IF value \in {"foreign", "malformed"} /\ ~USE_FIXED THEN
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
    /\ phase' = IF USE_FIXED THEN "cancelled" ELSE "completed"
    /\ explicitTerminal' = USE_FIXED
    /\ observation' = "none"
    /\ UNCHANGED <<resourceKnown, cancelRequested>>

CancelStale ==
    /\ phase = "running"
    /\ cancelRequested
    /\ ~resourceKnown
    /\ phase' = IF USE_FIXED THEN "cancelled" ELSE "crashed"
    /\ UNCHANGED <<resourceKnown, observation, explicitTerminal, cancelRequested>>

Next ==
    \/ \E kind \in {"success-id", "empty-output", "failure"} : Submit(kind)
    \/ \E value \in {"running", "completed", "failed", "missing", "foreign", "malformed"} : Observe(value)
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
StrictCancellation == cancelRequested => phase # "completed"
ResourceTerminalConsistency == phase = "completed" => resourceKnown

=============================================================================
