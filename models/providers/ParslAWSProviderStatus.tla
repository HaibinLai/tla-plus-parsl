--------------------------- MODULE ParslAWSProviderStatus ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * A focused AWSProvider status model.
 *
 * AWSProvider.status asks EC2 for a set of instance IDs and translates
 * pending/running/terminated-like states.  The current implementation emits
 * statuses only for instances present in the API response.  USE_FIXED models a
 * defensive completion mapping for an instance that was requested but absent
 * from that response.
 ***************************************************************************)

CONSTANTS API_STATE, USE_FIXED

APIStates == {"pending", "running", "terminated", "missing"}
ProviderStates == {"unknown", "pending", "running", "completed"}
PollStates == {"idle", "polling", "replied"}

VARIABLES pollState, providerState, statusReturned
vars == <<pollState, providerState, statusReturned>>

Init ==
    /\ API_STATE \in APIStates
    /\ USE_FIXED \in BOOLEAN
    /\ pollState = "idle"
    /\ providerState = "unknown"
    /\ statusReturned = FALSE

BeginPoll ==
    /\ pollState = "idle"
    /\ pollState' = "polling"
    /\ UNCHANGED <<providerState, statusReturned>>

ReceiveEC2Response ==
    /\ pollState = "polling"
    /\ pollState' = "replied"
    /\ IF API_STATE = "missing"
          THEN IF USE_FIXED
                    THEN /\ providerState' = "completed"
                         /\ statusReturned' = TRUE
                    ELSE /\ providerState' = "unknown"
                         /\ statusReturned' = FALSE
          ELSE /\ providerState' =
                    IF API_STATE = "pending" THEN "pending"
                    ELSE IF API_STATE = "running" THEN "running"
                    ELSE "completed"
               /\ statusReturned' = TRUE

Reset ==
    /\ pollState = "replied"
    /\ pollState' = "idle"
    /\ UNCHANGED <<providerState, statusReturned>>

Next ==
    \/ BeginPoll
    \/ ReceiveEC2Response
    \/ Reset
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ pollState \in PollStates
    /\ providerState \in ProviderStates
    /\ statusReturned \in BOOLEAN

TranslationSafety ==
    API_STATE # "missing" /\ pollState = "replied" => statusReturned

StatusCompleteness ==
    pollState = "replied" =>
        /\ statusReturned
        /\ providerState # "unknown"

=============================================================================
