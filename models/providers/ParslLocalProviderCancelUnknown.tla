--------------------------- MODULE ParslLocalProviderCancelUnknown ---------------------------
EXTENDS Naturals

(***************************************************************************
 * LocalProvider cancellation of a stale job id.
 *
 * The current implementation indexes resources[job_id] before attempting
 * cancellation.  A job already removed by polling therefore raises a
 * KeyError; the fixed branch treats the stale cancellation as a harmless
 * unsuccessful result.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLE state, returned
vars == <<state, returned>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "requested"
    /\ returned = "none"

Cancel ==
    /\ state = "requested"
    /\ IF USE_FIXED
          THEN /\ state' = "completed"
               /\ returned' = "false"
          ELSE /\ state' = "crashed"
               /\ returned' = "none"

Next == Cancel \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"requested", "completed", "crashed"}
    /\ returned \in {"none", "false"}

NoStaleCancellationCrash == state # "crashed"
ResultSafety == state = "completed" => returned = "false"

=============================================================================
