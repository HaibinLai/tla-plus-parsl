--------------------------- MODULE ParslMPIMalformedResultMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * MPI malformed-result cleanup across resources, Future, and monitoring.
 *
 * A corrupt MPI worker payload currently escapes get_result before allocated
 * nodes are returned.  This composition makes the downstream obligations
 * explicit: release the task allocation, terminate its Future, and publish a
 * monitoring failure.  USE_FIXED represents isolated decode failure cleanup.
 ***************************************************************************)

CONSTANT USE_FIXED

Phases == {"queued", "decode-error", "failed"}
FutureStates == {"pending", "failed"}
MonitorStates == {"none", "failed"}

VARIABLES allocation, phase, future, monitor
vars == <<allocation, phase, future, monitor>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ allocation = "held"
    /\ phase = "queued"
    /\ future = "pending"
    /\ monitor = "none"

DecodeCorruptPayload ==
    /\ phase = "queued"
    /\ phase' = IF USE_FIXED THEN "failed" ELSE "decode-error"
    /\ allocation' = IF USE_FIXED THEN "released" ELSE "held"
    /\ future' = IF USE_FIXED THEN "failed" ELSE "pending"
    /\ monitor' = IF USE_FIXED THEN "failed" ELSE "none"

Done ==
    /\ phase \in {"decode-error", "failed"}
    /\ UNCHANGED vars

Next == DecodeCorruptPayload \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ allocation \in {"held", "released"}
    /\ phase \in Phases
    /\ future \in FutureStates
    /\ monitor \in MonitorStates

DecodeFailureTerminal ==
    phase \in {"decode-error", "failed"} => future = "failed" \/ USE_FIXED

NoDecodeLeak ==
    phase = "decode-error" => allocation = "released" \/ USE_FIXED

MonitoringFailureVisible ==
    future = "failed" => monitor = "failed"

=============================================================================
