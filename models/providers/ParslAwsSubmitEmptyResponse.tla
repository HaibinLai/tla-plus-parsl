--------------------------- MODULE ParslAwsSubmitEmptyResponse ---------------------------
EXTENDS Naturals

(***************************************************************************
 * AWSProvider.submit and an empty EC2 launch response.
 *
 * The current implementation destructures the response as
 * ``[instance, *rest]`` before checking whether an instance was returned.
 * An empty response therefore raises ValueError instead of returning a
 * failed submission.  USE_FIXED validates the response first.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES state, resourceCreated, returnedFailure
vars == <<state, resourceCreated, returnedFailure>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "empty_response"
    /\ resourceCreated = FALSE
    /\ returnedFailure = FALSE

HandleEmptyResponse ==
    /\ state = "empty_response"
    /\ IF USE_FIXED
          THEN /\ state' = "failed"
               /\ returnedFailure' = TRUE
          ELSE /\ state' = "crashed"
               /\ returnedFailure' = FALSE
    /\ UNCHANGED resourceCreated

Next == HandleEmptyResponse \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"empty_response", "failed", "crashed"}
    /\ resourceCreated \in BOOLEAN
    /\ returnedFailure \in BOOLEAN

EmptySubmitSafety ==
    state = "failed" => returnedFailure

SubmitDoesNotCrash == state # "crashed"

=============================================================================
