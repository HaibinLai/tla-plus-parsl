-------------------- MODULE ParslAzureCancelDuplicates --------------------
EXTENDS Naturals

(***************************************************************************
 * Azure provider duplicate cancellation.
 *
 * AzureProvider.cancel sends each requested VM ID to the remote API and then
 * removes it from the local instances list.  Repeating an ID can therefore
 * produce a remote-success/local-failure result on the second iteration.
 * The fixed branch treats duplicate local cleanup as idempotent.
 *************************************************************************** *)

CONSTANT USE_FIXED

States == {"configured", "first_deleted", "done"}
Results == {"none", "success", "partial"}

VARIABLES state, localPresent, remoteDeleted, result
vars == <<state, localPresent, remoteDeleted, result>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "configured"
    /\ localPresent = TRUE
    /\ remoteDeleted = FALSE
    /\ result = "none"

DeleteFirst ==
    /\ state = "configured"
    /\ state' = "first_deleted"
    /\ localPresent' = FALSE
    /\ remoteDeleted' = TRUE
    /\ UNCHANGED result

DeleteDuplicate ==
    /\ state = "first_deleted"
    /\ state' = "done"
    /\ remoteDeleted' = TRUE
    /\ IF USE_FIXED
          THEN result' = "success"
          ELSE result' = "partial"
    /\ UNCHANGED localPresent

Next == DeleteFirst \/ DeleteDuplicate \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in States
    /\ localPresent \in BOOLEAN
    /\ remoteDeleted \in BOOLEAN
    /\ result \in Results

RemoteSuccessSafety == (remoteDeleted /\ result # "none") => result # "partial"
DuplicateCleanupIdempotent == state = "done" => result = "success"

=============================================================================
