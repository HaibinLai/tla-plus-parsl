--------------------------- MODULE ParslMonitoringDispatchEnvelope ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Monitoring queue-envelope validation.
 *
 * DatabaseManager._dispatch_to_internal expects a two-element tuple.  The
 * current assertion lets a malformed queue item escape and kill the migration
 * thread; USE_FIXED represents logging/discarding the malformed item instead.
 *************************************************************************** *)

CONSTANTS VALID_ENVELOPE, USE_FIXED
VARIABLES state, queued
vars == <<state, queued>>

Init ==
    /\ VALID_ENVELOPE \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "received"
    /\ queued = FALSE

DispatchValid ==
    /\ state = "received"
    /\ VALID_ENVELOPE
    /\ state' = "dispatched"
    /\ queued' = TRUE

RejectMalformed ==
    /\ state = "received"
    /\ ~VALID_ENVELOPE
    /\ USE_FIXED
    /\ state' = "rejected"
    /\ UNCHANGED queued

MalformedAssertion ==
    /\ state = "received"
    /\ ~VALID_ENVELOPE
    /\ ~USE_FIXED
    /\ state' = "crashed"
    /\ UNCHANGED queued

Next == DispatchValid \/ RejectMalformed \/ MalformedAssertion \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"received", "dispatched", "rejected", "crashed"}
    /\ queued \in BOOLEAN

MalformedIsolation == state # "crashed"
DispatchSafety == queued => VALID_ENVELOPE
=============================================================================
