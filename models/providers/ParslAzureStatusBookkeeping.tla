--------------------------- MODULE ParslAzureStatusBookkeeping ---------------------------
EXTENDS Naturals

(***************************************************************************
 * AzureProvider.status returns a translated status but currently does not
 * update the provider's local resources entry.  Consumers inspecting the
 * provider bookkeeping can therefore see PENDING after the cloud reports
 * RUNNING.  USE_FIXED models recording the translated status locally.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES returned, local, state
vars == <<returned, local, state>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ returned = "pending"
    /\ local = "pending"
    /\ state = "idle"

Poll ==
    /\ state = "idle"
    /\ returned' = "running"
    /\ local' = IF USE_FIXED THEN "running" ELSE local
    /\ state' = "updated"

Next == Poll \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ returned \in {"pending", "running"}
    /\ local \in {"pending", "running"}
    /\ state \in {"idle", "updated"}

BookkeepingConsistency == state = "updated" => local = returned
=============================================================================
