--------------------------- MODULE ParslGlobusComputeResourceSpecType ---------------------------
EXTENDS Naturals

(***************************************************************************
 * GlobusComputeExecutor.submit copies the task resource specification and
 * immediately calls ``pop`` on it.  A truthy scalar therefore leaks
 * AttributeError instead of producing a controlled admission failure.
 ***************************************************************************)

CONSTANT USE_FIXED
InputKinds == {"none", "mapping", "non_mapping"}
Outcomes == {"idle", "submitted", "rejected", "attribute_error"}
VARIABLES inputKind, outcome, futureCreated
vars == <<inputKind, outcome, futureCreated>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ inputKind = "none"
    /\ outcome = "idle"
    /\ futureCreated = FALSE

ChooseInput(kind) ==
    /\ outcome = "idle"
    /\ kind \in InputKinds
    /\ inputKind' = kind
    /\ UNCHANGED <<outcome, futureCreated>>

Submit ==
    /\ outcome = "idle"
    /\ inputKind \in {"none", "mapping"}
    /\ outcome' = "submitted"
    /\ futureCreated' = TRUE
    /\ UNCHANGED inputKind

RejectNonMapping ==
    /\ outcome = "idle"
    /\ inputKind = "non_mapping"
    /\ USE_FIXED
    /\ outcome' = "rejected"
    /\ UNCHANGED <<inputKind, futureCreated>>

RaiseAttributeError ==
    /\ outcome = "idle"
    /\ inputKind = "non_mapping"
    /\ ~USE_FIXED
    /\ outcome' = "attribute_error"
    /\ UNCHANGED <<inputKind, futureCreated>>

Next ==
    \/ \E kind \in InputKinds : ChooseInput(kind)
    \/ Submit
    \/ RejectNonMapping
    \/ RaiseAttributeError
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ inputKind \in InputKinds
    /\ outcome \in Outcomes
    /\ futureCreated \in BOOLEAN

NoAttributeError == outcome # "attribute_error"
NoFutureOnRejectedInput == outcome = "rejected" => ~futureCreated
=============================================================================
