--------------------------- MODULE ParslAzureStatus ---------------------------
EXTENDS Naturals

(***************************************************************************
 * AzureProvider.status translates the second instanceView status string.
 * Azure can expose a short status list while a VM is still provisioning;
 * the implementation maps that IndexError to PENDING.  Known terminal VM
 * states map to COMPLETED and unfamiliar strings map to UNKNOWN.
 ***************************************************************************)

CONSTANT STATUS_KIND

StatusKinds == {"pending", "running", "deallocated", "stopping", "stopped",
                "short_view", "unknown"}
ProviderStates == {"idle", "queried", "translated"}
MappedStates == {"none", "pending", "running", "completed", "unknown"}

VARIABLES providerState, mappedState
vars == <<providerState, mappedState>>

Init ==
    /\ STATUS_KIND \in StatusKinds
    /\ providerState = "idle"
    /\ mappedState = "none"

Query ==
    /\ providerState = "idle"
    /\ providerState' = "queried"
    /\ UNCHANGED mappedState

TranslatePending ==
    /\ providerState = "queried"
    /\ STATUS_KIND = "pending"
    /\ mappedState' = "pending"
    /\ providerState' = "translated"

TranslateRunning ==
    /\ providerState = "queried"
    /\ STATUS_KIND = "running"
    /\ mappedState' = "running"
    /\ providerState' = "translated"

TranslateCompleted ==
    /\ providerState = "queried"
    /\ STATUS_KIND \in {"deallocated", "stopping", "stopped"}
    /\ mappedState' = "completed"
    /\ providerState' = "translated"

TranslateShortView ==
    /\ providerState = "queried"
    /\ STATUS_KIND = "short_view"
    /\ mappedState' = "pending"
    /\ providerState' = "translated"

TranslateUnknown ==
    /\ providerState = "queried"
    /\ STATUS_KIND = "unknown"
    /\ mappedState' = "unknown"
    /\ providerState' = "translated"

Next ==
    \/ Query
    \/ TranslatePending
    \/ TranslateRunning
    \/ TranslateCompleted
    \/ TranslateShortView
    \/ TranslateUnknown
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ providerState \in ProviderStates
    /\ mappedState \in MappedStates

StatusSafety ==
    providerState = "translated" => mappedState # "none"

=============================================================================
