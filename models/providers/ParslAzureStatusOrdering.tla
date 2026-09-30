--------------------------- MODULE ParslAzureStatusOrdering ---------------------------
EXTENDS Naturals

(***************************************************************************
 * AzureProvider.status reads statuses[1] rather than selecting a status by
 * code.  If Azure changes the list order, a running VM can be reported as
 * pending.  USE_FIXED models selecting the running observation by meaning.
 ***************************************************************************)

CONSTANT STATUS_ORDER, USE_FIXED
VARIABLES phase, observed, outcome
vars == <<phase, observed, outcome>>

Init ==
    /\ STATUS_ORDER \in {"normal", "swapped"}
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "query"
    /\ observed = "none"
    /\ outcome = "waiting"

ReadStatus ==
    /\ phase = "query"
    /\ phase' = "complete"
    /\ observed' = IF USE_FIXED \/ STATUS_ORDER = "normal"
                       THEN "running" ELSE "pending"
    /\ outcome' = IF observed' = "running" THEN "admitted" ELSE "underreported"

Next == ReadStatus \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"query", "complete"}
    /\ observed \in {"none", "running", "pending"}
    /\ outcome \in {"waiting", "admitted", "underreported"}

RunningStatusSafety == phase = "complete" => observed = "running"
=============================================================================
