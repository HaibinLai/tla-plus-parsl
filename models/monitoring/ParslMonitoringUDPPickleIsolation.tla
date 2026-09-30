--------------------------- MODULE ParslMonitoringUDPPickleIsolation ---------------------------
EXTENDS Naturals, Sequences

(***************************************************************************
 * Monitoring UDP router payload isolation.
 *
 * MonitoringRouter validates the HMAC before calling pickle.loads, but a
 * validly authenticated malformed pickle currently escapes process_message
 * and terminates the listener.  USE_FIXED isolates the decode failure and
 * continues to the next datagram.
 *************************************************************************** *)

CONSTANT USE_FIXED

Frames == <<"malformed", "valid">>

VARIABLES position, routerAlive, forwarded, malformedSeen
vars == <<position, routerAlive, forwarded, malformedSeen>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ position = 1
    /\ routerAlive = TRUE
    /\ forwarded = FALSE
    /\ malformedSeen = FALSE

ReceiveMalformed ==
    /\ position = 1
    /\ position' = IF USE_FIXED THEN 2 ELSE 1
    /\ routerAlive' = IF USE_FIXED THEN TRUE ELSE FALSE
    /\ malformedSeen' = TRUE
    /\ UNCHANGED forwarded

ReceiveValid ==
    /\ routerAlive
    /\ position = 2
    /\ position' = 3
    /\ forwarded' = TRUE
    /\ UNCHANGED <<routerAlive, malformedSeen>>

Next ==
    \/ ReceiveMalformed
    \/ ReceiveValid
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ position \in 1..3
    /\ routerAlive \in BOOLEAN
    /\ forwarded \in BOOLEAN
    /\ malformedSeen \in BOOLEAN

ValidAfterMalformedSafety ==
    position = 3 => forwarded

RouterSurvivalSafety ==
    malformedSeen /\ ~forwarded => position = 2 /\ routerAlive

=============================================================================
