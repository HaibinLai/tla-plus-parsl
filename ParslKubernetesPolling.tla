--------------------------- MODULE ParslKubernetesPolling ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Kubernetes provider status polling.
 *
 * KubernetesProvider._status translates pod phases.  When the API read
 * raises an exception, the source attempts to expose UNKNOWN for a running
 * job.  USE_FIXED selects the intended state update; FALSE reproduces the
 * current source branch whose Python ``is JobStatus(...)`` identity test does
 * not match the stored status object.
 ***************************************************************************)

CONSTANT USE_FIXED
MAX_POLLS == 3
PodPhases == {"Pending", "Running", "Succeeded", "Failed", "Unknown"}
JobStates == {"PENDING", "RUNNING", "COMPLETED", "FAILED", "UNKNOWN", "CANCELLED"}
TerminalStates == {"COMPLETED", "FAILED", "CANCELLED"}

Translate(phase) ==
    IF phase = "Pending" THEN "PENDING"
    ELSE IF phase = "Running" THEN "RUNNING"
    ELSE IF phase = "Succeeded" THEN "COMPLETED"
    ELSE IF phase = "Failed" THEN "FAILED"
    ELSE "UNKNOWN"

VARIABLES jobState, podPhase, pollCount, lastPollError, terminalSnapshot
vars == <<jobState, podPhase, pollCount, lastPollError, terminalSnapshot>>

Init ==
    /\ jobState = "RUNNING"
    /\ podPhase = "Running"
    /\ pollCount = 0
    /\ lastPollError = FALSE
    /\ terminalSnapshot = "none"

PollSuccess(phase) ==
    /\ jobState \notin TerminalStates
    /\ pollCount < MAX_POLLS
    /\ phase \in PodPhases
    /\ jobState' = Translate(phase)
    /\ podPhase' = phase
    /\ pollCount' = pollCount + 1
    /\ lastPollError' = FALSE
    /\ terminalSnapshot' = IF Translate(phase) \in TerminalStates
                              THEN Translate(phase) ELSE terminalSnapshot

PollError ==
    /\ jobState = "RUNNING"
    /\ pollCount < MAX_POLLS
    /\ podPhase' = "Unknown"
    /\ jobState' = IF USE_FIXED THEN "UNKNOWN" ELSE jobState
    /\ pollCount' = pollCount + 1
    /\ lastPollError' = TRUE
    /\ UNCHANGED terminalSnapshot

Cancel ==
    /\ jobState \notin TerminalStates
    /\ jobState' = "CANCELLED"
    /\ podPhase' = "Unknown"
    /\ terminalSnapshot' = "CANCELLED"
    /\ lastPollError' = FALSE
    /\ UNCHANGED pollCount

Next ==
    \/ \E phase \in PodPhases : PollSuccess(phase)
    \/ PollError
    \/ Cancel
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ jobState \in JobStates
    /\ podPhase \in PodPhases
    /\ pollCount \in 0..MAX_POLLS
    /\ lastPollError \in BOOLEAN
    /\ terminalSnapshot \in (JobStates \cup {"none"})

TerminalStability ==
    terminalSnapshot # "none" => jobState = terminalSnapshot

ErrorVisibility ==
    lastPollError => jobState = "UNKNOWN"

=============================================================================
