--------------------------- MODULE ParslThreadExecutorResourceSpec ---------------------------
EXTENDS Naturals

(***************************************************************************
 * ThreadPoolExecutor.submit resource-specification validation.
 *
 * ThreadPoolExecutor does not support Parsl resource specifications.  The
 * current path cleanly rejects a non-empty mapping, but calls .keys() before
 * constructing InvalidResourceSpecification.  A truthy non-mapping value
 * therefore raises AttributeError instead of a controlled executor error.
 ***************************************************************************)

CONSTANT USE_FIXED

InputKinds == {"none", "empty_mapping", "mapping", "non_mapping"}
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
    /\ inputKind \in {"none", "empty_mapping"}
    /\ outcome' = "submitted"
    /\ futureCreated' = TRUE
    /\ UNCHANGED inputKind

RejectMapping ==
    /\ outcome = "idle"
    /\ inputKind = "mapping"
    /\ outcome' = "rejected"
    /\ UNCHANGED <<inputKind, futureCreated>>

RejectNonMapping ==
    /\ outcome = "idle"
    /\ inputKind = "non_mapping"
    /\ outcome' = "rejected"
    /\ UNCHANGED <<inputKind, futureCreated>>

RaiseAttributeError ==
    /\ ~USE_FIXED
    /\ outcome = "idle"
    /\ inputKind = "non_mapping"
    /\ outcome' = "attribute_error"
    /\ UNCHANGED <<inputKind, futureCreated>>

Next ==
    \/ \E kind \in InputKinds : ChooseInput(kind)
    \/ Submit
    \/ RejectMapping
    \/ IF USE_FIXED THEN RejectNonMapping ELSE RaiseAttributeError
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ inputKind \in InputKinds
    /\ outcome \in Outcomes
    /\ futureCreated \in BOOLEAN

NoAttributeError == outcome # "attribute_error"

NoFutureOnRejectedInput ==
    outcome \in {"rejected", "attribute_error"} => ~futureCreated

=============================================================================
