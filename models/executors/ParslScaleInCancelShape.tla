--------------------------- MODULE ParslScaleInCancelShape ---------------------------
EXTENDS Naturals

(***************************************************************************
 * BlockProviderExecutor.scale_in expects provider.cancel to return one
 * boolean for every requested job.  The current implementation asserts that
 * shape and aborts the whole scale-in on a short/malformed response.  The
 * fixed branch retains the successful prefix and reports the remainder as
 * not cancelled instead of crashing.
 ***************************************************************************)

CONSTANT USE_FIXED
REQUESTED == 2
RETURNED == 1

VARIABLES state, cancelled, requested
vars == <<state, cancelled, requested>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "requested"
    /\ cancelled = 0
    /\ requested = REQUESTED

FilterCancelResponse ==
    /\ state = "requested"
    /\ IF RETURNED = requested
          THEN /\ state' = "completed"
               /\ cancelled' = RETURNED
          ELSE IF USE_FIXED
               THEN /\ state' = "partial"
                    /\ cancelled' = RETURNED
               ELSE /\ state' = "error"
                    /\ cancelled' = 0
    /\ UNCHANGED requested

Next ==
    \/ FilterCancelResponse
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"requested", "completed", "partial", "error"}
    /\ cancelled \in 0..REQUESTED
    /\ requested = REQUESTED

CancelShapeSafety ==
    state = "error" => USE_FIXED

ProgressSafety ==
    state = "partial" => cancelled = RETURNED

=============================================================================
