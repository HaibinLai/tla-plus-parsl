--------------------------- MODULE ParslHtexResultMessageMalformed ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX interchange handling of a malformed manager result frame.
 *
 * Metadata is parsed before each result payload is unpickled.  The current
 * path lets a corrupt payload escape the result loop; USE_FIXED discards the
 * bad frame and keeps the manager protocol alive.
 ***************************************************************************)

CONSTANT USE_FIXED

States == {"ready", "processing", "failed", "ignored"}
VARIABLES state, forwarded
vars == <<state, forwarded>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "ready"
    /\ forwarded = 0

ReceiveBatch ==
    /\ state = "ready"
    /\ state' = "processing"
    /\ UNCHANGED forwarded

DecodeMalformedFrame ==
    /\ state = "processing"
    /\ IF USE_FIXED THEN state' = "ignored" ELSE state' = "failed"
    /\ UNCHANGED forwarded

ForwardValidFrame ==
    /\ state = "processing"
    /\ forwarded = 0
    /\ state' = "ready"
    /\ forwarded' = forwarded + 1

Next ==
    \/ ReceiveBatch
    \/ DecodeMalformedFrame
    \/ ForwardValidFrame
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in States
    /\ forwarded \in 0..1

MalformedFrameSafety ==
    state # "failed"

=============================================================================
