--------------------------- MODULE ParslRadicalPilotDecodeMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Radical-Pilot DONE callback composed with the Parsl Future and monitoring
 * publication boundaries.  A malformed serialized result must not strand the
 * Future or hide the failure from monitoring.
 ***************************************************************************)

CONSTANT USE_FIXED

FutureStates == {"pending", "succeeded", "failed"}
MonitorStates == {"none", "succeeded", "failed"}
CallbackStates == {"waiting", "decoded", "decode_failed"}
CollectorStates == {"running", "stopped"}

VARIABLES futureState, monitorState, callbackState, collectorState
vars == <<futureState, monitorState, callbackState, collectorState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ futureState = "pending"
    /\ monitorState = "none"
    /\ callbackState = "waiting"
    /\ collectorState = "running"

DecodeSuccess ==
    /\ callbackState = "waiting"
    /\ callbackState' = "decoded"
    /\ futureState' = "succeeded"
    /\ monitorState' = "succeeded"
    /\ collectorState' = "running"

DecodeFailure ==
    /\ callbackState = "waiting"
    /\ callbackState' = "decode_failed"
    /\ IF USE_FIXED
          THEN /\ futureState' = "failed"
               /\ monitorState' = "failed"
               /\ collectorState' = "running"
          ELSE /\ futureState' = "pending"
               /\ monitorState' = "none"
               /\ collectorState' = "stopped"

Next ==
    \/ DecodeSuccess
    \/ DecodeFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ futureState \in FutureStates
    /\ monitorState \in MonitorStates
    /\ callbackState \in CallbackStates
    /\ collectorState \in CollectorStates

DecodeFailureTerminal ==
    callbackState = "decode_failed" => futureState = "failed"

MonitoringFailureVisible ==
    futureState = "failed" => monitorState = "failed"

CollectorProgress ==
    callbackState = "decode_failed" => collectorState = "running"

=============================================================================
