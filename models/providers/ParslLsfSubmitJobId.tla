--------------------------- MODULE ParslLsfSubmitJobId ---------------------------
EXTENDS Naturals

(***************************************************************************
 * LSFProvider.submit accepts a successful-looking scheduler line and uses
 * its second whitespace token as the job identifier.  A malformed line such
 * as "Job is submitted to queue" therefore publishes "is" as a resource.
 * USE_FIXED rejects the response unless the identifier is valid.
 ***************************************************************************)

CONSTANT USE_FIXED, VALID_RESPONSE

VARIABLES responseValid, publishedJobId
vars == <<responseValid, publishedJobId>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ VALID_RESPONSE \in BOOLEAN
    /\ responseValid = VALID_RESPONSE
    /\ publishedJobId = ""

ParseSubmitResponse ==
    /\ publishedJobId' =
          IF responseValid THEN "123"
          ELSE IF USE_FIXED THEN "" ELSE "is"
    /\ UNCHANGED responseValid

Next == ParseSubmitResponse \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ VALID_RESPONSE \in BOOLEAN
    /\ responseValid = VALID_RESPONSE
    /\ publishedJobId \in {"", "123", "is"}

JobIdSafety ==
    publishedJobId = "" \/ responseValid

=============================================================================
