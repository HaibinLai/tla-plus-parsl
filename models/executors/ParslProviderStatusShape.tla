--------------------------- MODULE ParslProviderStatusShape ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Provider status response cardinality.
 *
 * BlockProviderExecutor.status zips block ids with provider.status results
 * through _make_status_dict and raises IndexError when the response is short.
 * USE_FIXED models preserving known statuses and marking missing responses as
 * UNKNOWN instead of aborting the whole poll.
 ***************************************************************************)

CONSTANT USE_FIXED
REQUESTED == 2
RETURNED == 1

VARIABLES state, knownStatuses, requested
vars == <<state, knownStatuses, requested>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "polling"
    /\ knownStatuses = 0
    /\ requested = REQUESTED

ApplyStatusResponse ==
    /\ state = "polling"
    /\ IF RETURNED = requested
          THEN /\ state' = "complete"
               /\ knownStatuses' = RETURNED
          ELSE IF USE_FIXED
               THEN /\ state' = "partial"
                    /\ knownStatuses' = RETURNED
               ELSE /\ state' = "error"
                    /\ knownStatuses' = 0
    /\ UNCHANGED requested

Next ==
    \/ ApplyStatusResponse
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"polling", "complete", "partial", "error"}
    /\ knownStatuses \in 0..REQUESTED
    /\ requested = REQUESTED

StatusShapeSafety ==
    state = "error" => USE_FIXED

PartialStatusProgress ==
    state = "partial" => knownStatuses = RETURNED

=============================================================================
