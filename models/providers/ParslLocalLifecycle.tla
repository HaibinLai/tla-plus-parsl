--------------------------- MODULE ParslLocalLifecycle ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Compact composition model for LocalProvider.
 *
 * A logical local job has a process, an exit-marker file, and a provider-side
 * resource record.  The model deliberately keeps the marker contents finite,
 * but preserves the important ordering: submit creates the process record,
 * status interprets the marker, and cancellation must tolerate a stale local
 * record after the process has already disappeared.
 ***************************************************************************)

CONSTANT USE_FIXED

Phases == {"absent", "submitted", "running", "terminal", "failed"}
Markers == {"-", "0", "1", "bad"}
Statuses == {"none", "running", "completed", "failed", "cancelled", "unknown"}

VARIABLES phase, processAlive, marker, resourceKnown, cancelRequested, status
vars == <<phase, processAlive, marker, resourceKnown, cancelRequested, status>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "absent"
    /\ processAlive = FALSE
    /\ marker = "-"
    /\ resourceKnown = FALSE
    /\ cancelRequested = FALSE
    /\ status = "none"

Submit ==
    /\ phase = "absent"
    /\ phase' = "submitted"
    /\ processAlive' = TRUE
    /\ marker' = "-"
    /\ resourceKnown' = TRUE
    /\ cancelRequested' = FALSE
    /\ status' = "running"

ProcessStarts ==
    /\ phase = "submitted"
    /\ phase' = "running"
    /\ UNCHANGED <<processAlive, marker, resourceKnown, cancelRequested, status>>

WriteExit(code) ==
    /\ phase \in {"submitted", "running"}
    /\ code \in {"0", "1"}
    /\ processAlive' = FALSE
    /\ marker' = code
    /\ phase' = "terminal"
    /\ UNCHANGED <<resourceKnown, cancelRequested, status>>

WriteMalformed ==
    /\ phase \in {"submitted", "running"}
    /\ processAlive' = FALSE
    /\ marker' = "bad"
    /\ phase' = "failed"
    /\ UNCHANGED <<resourceKnown, cancelRequested, status>>

LoseLocalRecord ==
    /\ phase \in {"submitted", "running", "terminal", "failed"}
    /\ resourceKnown
    /\ resourceKnown' = FALSE
    /\ UNCHANGED <<phase, processAlive, marker, cancelRequested, status>>

Poll ==
    /\ resourceKnown
    /\ status = "running"
    /\ status' =
        IF marker = "-" THEN IF processAlive THEN "running" ELSE "cancelled"
        ELSE IF marker = "0" THEN "completed"
        ELSE IF marker = "1" THEN "failed"
        ELSE "unknown"
    /\ UNCHANGED <<phase, processAlive, marker, resourceKnown, cancelRequested>>

Cancel ==
    /\ phase \in {"submitted", "running"}
    /\ cancelRequested' = TRUE
    /\ processAlive' = FALSE
    /\ phase' = "terminal"
    /\ marker' = "-"
    /\ status' = "cancelled"
    /\ UNCHANGED resourceKnown

StaleCancel ==
    /\ phase \in {"submitted", "running"}
    /\ ~resourceKnown
    /\ cancelRequested
    /\ IF USE_FIXED THEN
           /\ phase' = "terminal"
           /\ status' = "cancelled"
       ELSE
           /\ phase' = "failed"
           /\ status' = "unknown"
    /\ UNCHANGED <<processAlive, marker, resourceKnown, cancelRequested>>

Next ==
    \/ Submit
    \/ ProcessStarts
    \/ \E code \in {"0", "1"} : WriteExit(code)
    \/ WriteMalformed
    \/ LoseLocalRecord
    \/ Poll
    \/ Cancel
    \/ StaleCancel
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ processAlive \in BOOLEAN
    /\ marker \in Markers
    /\ resourceKnown \in BOOLEAN
    /\ cancelRequested \in BOOLEAN
    /\ status \in Statuses

NoAbort == phase # "failed"
TerminalStateStable ==
    status \in {"completed", "failed", "cancelled"} => ~processAlive
CancelSafety == cancelRequested => status # "completed"
StatusEvidence ==
    /\ (status = "completed" => marker = "0")
    /\ (status = "failed" => marker \in {"1", "bad"})

=============================================================================
