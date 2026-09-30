--------------------------- MODULE ParslHTTPContentLength ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTTP in-task staging and declared content length.
 *
 * A successful HTTP response can still end before the advertised
 * Content-Length.  The current wrapper publishes the bytes it received and
 * runs the user function; the fixed branch rejects the truncated transfer
 * before task execution.
 ***************************************************************************)

CONSTANTS EXPECTED, RECEIVED, USE_FIXED

VARIABLES transfer, app
vars == <<transfer, app>>

Init ==
    /\ EXPECTED \in 1..20
    /\ RECEIVED \in 0..20
    /\ USE_FIXED \in BOOLEAN
    /\ transfer = "fetching"
    /\ app = "blocked"

FinishFetch ==
    /\ transfer = "fetching"
    /\ transfer' = IF USE_FIXED /\ RECEIVED # EXPECTED
                         THEN "rejected" ELSE "published"
    /\ app' = IF USE_FIXED /\ RECEIVED # EXPECTED
                  THEN "blocked" ELSE "ran"

Next == FinishFetch \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ EXPECTED \in 1..20
    /\ RECEIVED \in 0..20
    /\ transfer \in {"fetching", "published", "rejected"}
    /\ app \in {"blocked", "ran"}

LengthSafety ==
    app = "ran" => RECEIVED = EXPECTED

=============================================================================
