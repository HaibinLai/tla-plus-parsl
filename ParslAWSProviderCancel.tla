--------------------------- MODULE ParslAWSProviderCancel ---------------------------
EXTENDS Naturals

(***************************************************************************
 * AWSProvider.cancel terminates instances remotely, then updates local
 * resource and instance maps.  A successful remote termination with a stale
 * local id currently raises while indexing local state; the FIXED branch
 * treats local cleanup as idempotent.
 *************************************************************************** *)

CONSTANTS LINGER, TERMINATE_SUCCEEDS, INSTANCE_PRESENT, USE_FIXED

States == {"ready", "ignored", "terminated", "failed"}
VARIABLES state, localPresent
vars == <<state, localPresent>>

Init ==
    /\ LINGER \in BOOLEAN
    /\ TERMINATE_SUCCEEDS \in BOOLEAN
    /\ INSTANCE_PRESENT \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "ready"
    /\ localPresent = INSTANCE_PRESENT

IgnoreLinger ==
    /\ state = "ready"
    /\ LINGER
    /\ state' = "ignored"
    /\ UNCHANGED localPresent

RemoteFailure ==
    /\ state = "ready"
    /\ ~LINGER
    /\ ~TERMINATE_SUCCEEDS
    /\ state' = "failed"
    /\ UNCHANGED localPresent

RemoteSuccessWithLocalState ==
    /\ state = "ready"
    /\ ~LINGER
    /\ TERMINATE_SUCCEEDS
    /\ INSTANCE_PRESENT
    /\ state' = "terminated"
    /\ localPresent' = FALSE

RemoteSuccessWithoutLocalState ==
    /\ state = "ready"
    /\ ~LINGER
    /\ TERMINATE_SUCCEEDS
    /\ ~INSTANCE_PRESENT
    /\ IF USE_FIXED THEN state' = "terminated" ELSE state' = "failed"
    /\ UNCHANGED localPresent

Next ==
    \/ IgnoreLinger
    \/ RemoteFailure
    \/ RemoteSuccessWithLocalState
    \/ RemoteSuccessWithoutLocalState
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ localPresent \in BOOLEAN

TerminationSafety ==
    state = "terminated" => ~localPresent

=============================================================================
