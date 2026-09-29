--------------------------- MODULE ParslFluxProviderStatusEmpty ---------------------------
EXTENDS Naturals

(***************************************************************************
 * FluxExecutor._check_provider_job assumes provider.status([job_id]) returns
 * at least one status.  A provider can instead return an empty list while an
 * allocation is disappearing.  The current implementation indexes element
 * zero and crashes the submission thread; the fixed branch treats this as a
 * terminal provider failure and reports it explicitly.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES reply, outcome
vars == <<reply, outcome>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ reply \in {"empty", "terminal", "running"}
    /\ reply = "empty"
    /\ outcome = "waiting"

Poll ==
    /\ outcome = "waiting"
    /\ outcome' =
        IF reply = "empty" THEN IF USE_FIXED THEN "provider-failed" ELSE "crash"
        ELSE IF reply = "terminal" THEN "provider-failed" ELSE "continue"
    /\ UNCHANGED reply

Next == Poll \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ reply \in {"empty", "terminal", "running"}
    /\ outcome \in {"waiting", "provider-failed", "crash", "continue"}

StatusQueryTotal == outcome # "crash"
=============================================================================
