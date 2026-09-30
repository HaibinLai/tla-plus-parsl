--------------------------- MODULE ParslHTTPSeparateContentLength ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Separate-task HTTP stage-in and declared content length.
 *
 * The current _http_stage_in helper publishes whatever bytes iter_content
 * yields, without comparing them with Content-Length.  USE_FIXED rejects a
 * clean early EOF before completing the staging Future.
 ***************************************************************************)

CONSTANTS EXPECTED, RECEIVED, USE_FIXED
VARIABLES transfer, staging
vars == <<transfer, staging>>

Init ==
    /\ EXPECTED \in 1..20
    /\ RECEIVED \in 0..20
    /\ USE_FIXED \in BOOLEAN
    /\ transfer = "fetching"
    /\ staging = "pending"

FinishFetch ==
    /\ transfer = "fetching"
    /\ transfer' = IF USE_FIXED /\ RECEIVED # EXPECTED
                         THEN "rejected" ELSE "published"
    /\ staging' = IF USE_FIXED /\ RECEIVED # EXPECTED
                       THEN "failed" ELSE "succeeded"

Next == FinishFetch \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ transfer \in {"fetching", "published", "rejected"}
    /\ staging \in {"pending", "succeeded", "failed"}

LengthSafety == staging = "succeeded" => RECEIVED = EXPECTED
=============================================================================
