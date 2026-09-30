--------------------------- MODULE ParslAzureCancelBookkeeping ---------------------------
EXTENDS Naturals

(***************************************************************************
 * AzureProvider.cancel remote deletion and local resource bookkeeping.
 *
 * The current implementation removes the VM name from ``instances`` after
 * a successful delete, but leaves the same VM in ``resources``.  The FIXED
 * branch removes both local records so later status/bye passes cannot reuse
 * a cloud object that no longer exists.
 ***************************************************************************)

CONSTANT FIXED

VARIABLES remoteState, instancePresent, resourcePresent
vars == <<remoteState, instancePresent, resourcePresent>>

Init ==
    /\ FIXED \in BOOLEAN
    /\ remoteState = "present"
    /\ instancePresent = TRUE
    /\ resourcePresent = TRUE

DeleteRemote ==
    /\ remoteState = "present"
    /\ remoteState' = "deleted"
    /\ instancePresent' = FALSE
    /\ resourcePresent' = IF FIXED THEN FALSE ELSE TRUE

Next == DeleteRemote \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ FIXED \in BOOLEAN
    /\ remoteState \in {"present", "deleted"}
    /\ instancePresent \in BOOLEAN
    /\ resourcePresent \in BOOLEAN

NoStaleResource ==
    remoteState = "deleted" => ~resourcePresent

InstanceCleanup ==
    remoteState = "deleted" => ~instancePresent

=============================================================================
