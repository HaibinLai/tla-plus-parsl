--------------------------- MODULE ParslKubernetesLifecycle ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Small Kubernetes provider lifecycle model.
 *
 * A logical block is submitted as a pod, observed through pod phases, and
 * cancelled through local bookkeeping.  Poll responses may arrive after a
 * cancellation, so the model keeps a terminal snapshot and makes the
 * Current/Fixed distinction explicit.
 ***************************************************************************)

CONSTANT USE_FIXED

PodPhases == {"Pending", "Running", "Succeeded", "Failed", "Unknown"}
States == {"absent", "pending", "running", "completed", "failed", "unknown", "cancelled"}
TerminalStates == {"completed", "failed", "cancelled"}

Translate(phase) ==
    IF phase = "Pending" THEN "pending"
    ELSE IF phase = "Running" THEN "running"
    ELSE IF phase = "Succeeded" THEN "completed"
    ELSE IF phase = "Failed" THEN "failed"
    ELSE "unknown"

VARIABLES state, podPhase, podPresent, pollError, cancelRequested,
          terminalSnapshot
vars == <<state, podPhase, podPresent, pollError, cancelRequested,
          terminalSnapshot>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "absent"
    /\ podPhase = "Pending"
    /\ podPresent = FALSE
    /\ pollError = FALSE
    /\ cancelRequested = FALSE
    /\ terminalSnapshot = "none"

Submit ==
    /\ state = "absent"
    /\ state' = "pending"
    /\ podPresent' = TRUE
    /\ podPhase' = "Pending"
    /\ pollError' = FALSE
    /\ cancelRequested' = FALSE
    /\ UNCHANGED terminalSnapshot

PollSuccess(phase) ==
    /\ podPresent
    /\ phase \in PodPhases
    /\ state' = IF USE_FIXED /\ state \in TerminalStates
                   THEN state ELSE Translate(phase)
    /\ podPhase' = phase
    /\ pollError' = FALSE
    /\ terminalSnapshot' =
          IF terminalSnapshot = "none" /\ Translate(phase) \in TerminalStates
          THEN Translate(phase) ELSE terminalSnapshot
    /\ UNCHANGED <<podPresent, cancelRequested>>

PollError ==
    /\ podPresent
    /\ state \in {"pending", "running"}
    /\ state' = IF USE_FIXED THEN "unknown" ELSE state
    /\ podPhase' = "Unknown"
    /\ pollError' = TRUE
    /\ UNCHANGED <<podPresent, cancelRequested, terminalSnapshot>>

Cancel ==
    /\ podPresent
    /\ state \in {"pending", "running"}
    /\ state' = "cancelled"
    /\ podPresent' = FALSE
    /\ podPhase' = "Unknown"
    /\ pollError' = FALSE
    /\ cancelRequested' = TRUE
    /\ terminalSnapshot' = "cancelled"

LatePoll(phase) ==
    /\ ~podPresent
    /\ state = "cancelled"
    /\ phase \in PodPhases
    /\ state' = IF USE_FIXED THEN state ELSE Translate(phase)
    /\ podPhase' = phase
    /\ pollError' = FALSE
    /\ UNCHANGED <<podPresent, cancelRequested, terminalSnapshot>>

Next ==
    \/ Submit
    \/ \E phase \in PodPhases : PollSuccess(phase)
    \/ PollError
    \/ Cancel
    \/ \E phase \in PodPhases : LatePoll(phase)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ podPhase \in PodPhases
    /\ podPresent \in BOOLEAN
    /\ pollError \in BOOLEAN
    /\ cancelRequested \in BOOLEAN
    /\ terminalSnapshot \in (States \cup {"none"})

TerminalSnapshotSafety ==
    terminalSnapshot # "none" => state = terminalSnapshot

ErrorVisibility ==
    pollError => state = "unknown"

CancellationSafety ==
    cancelRequested => state = "cancelled"

=============================================================================
