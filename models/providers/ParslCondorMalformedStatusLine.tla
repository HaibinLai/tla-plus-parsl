--------------------------- MODULE ParslCondorMalformedStatusLine ---------------------------
EXTENDS Naturals

(***************************************************************************
 * CondorProvider._status and malformed successful output.
 *
 * Even when condor_q returns code zero, a truncated line can lack the state
 * token.  The current parser indexes parts[1] and aborts the poll.  USE_FIXED
 * represents skipping the malformed record and preserving the known status.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES state, jobStatus, malformedIgnored
vars == <<state, jobStatus, malformedIgnored>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "polling"
    /\ jobStatus = "running"
    /\ malformedIgnored = FALSE

ParseLine ==
    /\ state = "polling"
    /\ IF USE_FIXED
          THEN /\ state' = "preserved"
               /\ malformedIgnored' = TRUE
               /\ UNCHANGED jobStatus
          ELSE /\ state' = "crashed"
               /\ UNCHANGED <<jobStatus, malformedIgnored>>

Next == ParseLine \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"polling", "preserved", "crashed"}
    /\ jobStatus \in {"running", "unknown"}
    /\ malformedIgnored \in BOOLEAN

MalformedLineSafety ==
    state = "preserved" => jobStatus = "running" /\ malformedIgnored

NoParserCrash == state # "crashed"

=============================================================================
