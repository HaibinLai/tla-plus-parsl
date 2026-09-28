--------------------------- MODULE ParslLocalProvider ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Small model of parsl.providers.local.LocalProvider.
 *
 * A submitted local job is represented by a process liveness bit and the
 * contents of its .ec exit-code file.  LocalProvider.status reads the exit
 * marker first: '-' means the process is still running, or CANCELLED when
 * the process is dead and cancel() had marked the job.  A numeric marker is
 * terminal and wins even if cancellation was requested earlier.  This last
 * detail is intentionally exposed as a race that can be checked against a
 * stricter cancellation policy.
 ***************************************************************************)

CONSTANTS EXIT_CODES, STRICT_CANCEL

MarkerValues == {"-", "0", "1", "garbage"}
ProcessStates == {"absent", "alive", "dead"}
ObservedStates == {"none", "running", "completed", "failed", "cancelled"}
TerminalStates == {"completed", "failed", "cancelled"}

VARIABLES process, marker, cancelRequested, observed
vars == <<process, marker, cancelRequested, observed>>

Init ==
    /\ EXIT_CODES # {}
    /\ EXIT_CODES \subseteq {"0", "1"}
    /\ STRICT_CANCEL \in BOOLEAN
    /\ process = "absent"
    /\ marker = "-"
    /\ cancelRequested = FALSE
    /\ observed = "none"

Submit ==
    /\ observed \notin TerminalStates
    /\ process = "absent"
    /\ process' = "alive"
    /\ marker' = "-"
    /\ cancelRequested' = FALSE
    /\ observed' = "running"

WriteExit(code) ==
    /\ observed \notin TerminalStates
    /\ process = "alive"
    /\ code \in EXIT_CODES
    /\ process' = "dead"
    /\ marker' = code
    /\ UNCHANGED <<cancelRequested, observed>>

WriteMalformedExit ==
    /\ observed \notin TerminalStates
    /\ process = "alive"
    /\ process' = "dead"
    /\ marker' = "garbage"
    /\ UNCHANGED <<cancelRequested, observed>>

LateWriteExit(code) ==
    /\ cancelRequested
    /\ process = "dead"
    /\ marker = "-"
    /\ code \in EXIT_CODES
    /\ marker' = code
    /\ UNCHANGED <<process, cancelRequested, observed>>

Cancel ==
    /\ observed \notin TerminalStates
    /\ process = "alive"
    /\ cancelRequested' = TRUE
    /\ process' = "dead"
    /\ UNCHANGED <<marker, observed>>

Poll ==
    /\ observed \notin TerminalStates
    /\ process # "absent"
    /\ observed' =
          IF STRICT_CANCEL /\ cancelRequested THEN "cancelled"
          ELSE IF marker = "-" THEN
              IF process = "alive" THEN "running"
              ELSE "cancelled"
          ELSE IF marker = "0" THEN "completed"
          ELSE IF marker = "1" THEN "failed"
          ELSE "failed"
    /\ UNCHANGED <<process, marker, cancelRequested>>

Next ==
    \/ Submit
    \/ \E code \in EXIT_CODES : WriteExit(code)
    \/ \E code \in EXIT_CODES : LateWriteExit(code)
    \/ WriteMalformedExit
    \/ Cancel
    \/ Poll
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ process \in ProcessStates
    /\ marker \in MarkerValues
    /\ cancelRequested \in BOOLEAN
    /\ observed \in ObservedStates

NoPrematureCompletion ==
    observed = "completed" => (marker = "0" /\ process = "dead")

TerminalStateConsistency ==
    /\ (observed = "completed" => (marker = "0" /\ process = "dead"))
    /\ (observed = "failed" => (marker \in {"1", "garbage"} /\ process = "dead"))
    /\ (observed = "cancelled" => process = "dead")

StrictCancellation ==
    cancelRequested => (observed # "completed")

CancelMarkerSafety ==
    cancelRequested /\ marker = "-" /\ process = "dead"
        => (observed \in {"none", "running", "cancelled"})

=============================================================================
