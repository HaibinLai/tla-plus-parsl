--------------------------- MODULE ParslCondorSubmit ---------------------------
EXTENDS Naturals

(***************************************************************************
 * CondorProvider.submit output boundary.
 *
 * A successful condor_submit command must still contain at least one
 * parseable cluster line.  The current implementation collects job ids and
 * then unconditionally returns job_id[0], so empty or malformed successful
 * output reaches an uncaught indexing error.  The fixed path rejects it.
 ***************************************************************************)

CONSTANT FIXED

Outputs == {"valid", "empty", "malformed", "command_error"}
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
    /\ kind \in Outputs
    /\ output' = kind
    /\ UNCHANGED <<result, resourceRegistered>>

Submit ==
    /\ output \in Outputs
    /\ result = "none"
    /\ output' = output
    /\ IF output = "valid" THEN
          /\ result' = "pending"
          /\ resourceRegistered' = TRUE
       ELSE IF output = "command_error" THEN
          /\ result' = "rejected"
          /\ resourceRegistered' = FALSE
       ELSE
          /\ result' = IF FIXED THEN "rejected" ELSE "crash"
          /\ resourceRegistered' = FALSE

Next ==
    \/ \E kind \in Outputs : ChooseOutput(kind)
    \/ Submit
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ output \in (Outputs \cup {"none"})
    /\ result \in Results
    /\ resourceRegistered \in BOOLEAN

NoCrash == result # "crash"

RegistrationMatchesResult ==
    resourceRegistered <=> result = "pending"

=============================================================================
