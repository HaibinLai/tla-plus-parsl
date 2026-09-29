--------------------------- MODULE ParslLocalExitFileMissing ---------------------------
EXTENDS Naturals

(***************************************************************************
 * LocalProvider status while a live process has no exit-code file yet.
 *
 * LocalProvider.status reads the .ec file outside the later parse guard.  A
 * transient missing file therefore escapes as FileNotFoundError and aborts
 * the polling pass.  USE_FIXED models retaining a non-terminal observation.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES processState, exitFile, pollState, status
vars == <<processState, exitFile, pollState, status>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ processState = "alive"
    /\ exitFile = "missing"
    /\ pollState = "ready"
    /\ status = "running"

ReadExitFile ==
    /\ pollState = "ready"
    /\ exitFile = "missing"
    /\ pollState' = IF USE_FIXED THEN "observed" ELSE "crashed"
    /\ status' = IF USE_FIXED THEN "unknown" ELSE status
    /\ UNCHANGED <<processState, exitFile>>

Next == ReadExitFile \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ processState = "alive"
    /\ exitFile = "missing"
    /\ pollState \in {"ready", "observed", "crashed"}
    /\ status \in {"running", "unknown"}

PollDoesNotCrash == pollState # "crashed"
MissingFileVisibility == pollState = "observed" => status = "unknown"

=============================================================================
