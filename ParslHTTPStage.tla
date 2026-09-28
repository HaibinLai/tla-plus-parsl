--------------------------- MODULE ParslHTTPStage ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTTP in-task staging status handling.
 *
 * HTTPInTaskStaging writes the response stream before calling the user
 * function.  A correct wrapper must reject non-success HTTP status codes;
 * the current implementation does not inspect the status at all.
 ***************************************************************************)

CONSTANT HTTP_OK, USE_FIXED

Phases == {"fetch", "app", "succeeded", "failed"}

VARIABLES phase, appRan, payloadWritten
vars == <<phase, appRan, payloadWritten>>

Init ==
    /\ HTTP_OK \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "fetch"
    /\ appRan = FALSE
    /\ payloadWritten = FALSE

FetchResponse ==
    /\ phase = "fetch"
    /\ payloadWritten' = TRUE
    /\ phase' = IF HTTP_OK \/ ~USE_FIXED THEN "app" ELSE "failed"
    /\ UNCHANGED appRan

RunApp ==
    /\ phase = "app"
    /\ appRan' = TRUE
    /\ phase' = "succeeded"
    /\ UNCHANGED payloadWritten

Next ==
    \/ FetchResponse
    \/ RunApp
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ appRan \in BOOLEAN
    /\ payloadWritten \in BOOLEAN

HTTPStatusSafety ==
    phase = "succeeded" => HTTP_OK

FailureVisibility ==
    ~HTTP_OK /\ USE_FIXED => phase = "failed" \/ phase = "fetch"

=============================================================================
