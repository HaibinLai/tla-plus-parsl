--------------------------- MODULE ParslSlurmSubmit ---------------------------
EXTENDS Naturals

(***************************************************************************
 * SlurmProvider.submit output boundary.
 *
 * The provider uses re.match(regex_job_id, line), then unconditionally asks
 * for match.group("id").  A custom regex that matches but has no named `id`
 * group therefore raises instead of producing a SubmitException.  This
 * model keeps scheduler execution and script generation abstract and focuses
 * on that observable submission contract.
 ***************************************************************************)

CONSTANTS FIXED

OutputKinds == {"valid", "empty", "wrong_prefix", "unnamed_match"}
Results == {"none", "pending", "rejected", "crash"}

VARIABLES output, result, resourceRegistered
vars == <<output, result, resourceRegistered>>

Init ==
    /\ FIXED \in BOOLEAN
    /\ output = "none"
    /\ result = "none"
    /\ resourceRegistered = FALSE

ChooseOutput(kind) ==
    /\ output = "none"
    /\ kind \in OutputKinds
    /\ output' = kind
    /\ UNCHANGED <<result, resourceRegistered>>

Submit ==
    /\ output \in OutputKinds
    /\ result = "none"
    /\ output' = output
    /\ IF output = "valid" THEN
          /\ result' = "pending"
          /\ resourceRegistered' = TRUE
       ELSE IF output = "unnamed_match" THEN
          /\ result' = IF FIXED THEN "rejected" ELSE "crash"
          /\ resourceRegistered' = FALSE
       ELSE
          /\ result' = "rejected"
          /\ resourceRegistered' = FALSE

Next ==
    \/ \E kind \in OutputKinds : ChooseOutput(kind)
    \/ Submit
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ output \in (OutputKinds \cup {"none"})
    /\ result \in Results
    /\ resourceRegistered \in BOOLEAN

NoCrash == result # "crash"

RegistrationMatchesResult ==
    resourceRegistered <=> result = "pending"

RejectedHasNoResource ==
    result = "rejected" => ~resourceRegistered

=============================================================================
