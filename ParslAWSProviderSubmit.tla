--------------------------- MODULE ParslAWSProviderSubmit ---------------------------
EXTENDS Naturals

(***************************************************************************
 * AWSProvider.submit launch boundary.
 *
 * spin_up_instance normally returns a one-element list containing an EC2
 * instance or None.  submit destructures that list before checking the value,
 * so an empty provider response reaches an uncaught pattern-unpacking error.
 * Successful unknown EC2 states are conservatively represented as PENDING.
 ***************************************************************************)

CONSTANT FIXED

Outcomes == {"success", "failure", "empty"}
Results == {"none", "pending", "running", "crash"}

VARIABLES outcome, result, resourceRegistered
vars == <<outcome, result, resourceRegistered>>

Init ==
    /\ FIXED \in BOOLEAN
    /\ outcome = "none"
    /\ result = "none"
    /\ resourceRegistered = FALSE

ChooseOutcome(value) ==
    /\ outcome = "none"
    /\ value \in Outcomes
    /\ outcome' = value
    /\ UNCHANGED <<result, resourceRegistered>>

Submit ==
    /\ outcome \in Outcomes
    /\ result = "none"
    /\ outcome' = outcome
    /\ IF outcome = "success" THEN
          /\ result' = "pending"
          /\ resourceRegistered' = TRUE
       ELSE IF outcome = "failure" THEN
          /\ result' = "none"
          /\ resourceRegistered' = FALSE
       ELSE
          /\ result' = IF FIXED THEN "none" ELSE "crash"
          /\ resourceRegistered' = FALSE

Next ==
    \/ \E value \in Outcomes : ChooseOutcome(value)
    \/ Submit
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ outcome \in (Outcomes \cup {"none"})
    /\ result \in Results
    /\ resourceRegistered \in BOOLEAN

NoCrash == result # "crash"

RegistrationMatchesResult ==
    resourceRegistered <=> result = "pending" \/ result = "running"

=============================================================================
