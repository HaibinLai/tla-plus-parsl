--------------------------- MODULE ParslHtexMonitoringMessage ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX manager result batches carrying monitoring payloads.
 *
 * Interchange.process_manager_socket_message asserts that a monitoring radio
 * exists when a manager sends a monitoring result.  The current branch can
 * therefore crash when monitoring is disabled; USE_FIXED models ignoring the
 * optional payload instead.
 ***************************************************************************)

CONSTANTS MONITORING_ENABLED, USE_FIXED

States == {"received", "forwarded", "ignored", "crashed"}

VARIABLES state, taskListChanged, payloadForwarded
vars == <<state, taskListChanged, payloadForwarded>>

Init ==
    /\ MONITORING_ENABLED \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "received"
    /\ taskListChanged = FALSE
    /\ payloadForwarded = FALSE

HandleMonitoring ==
    /\ state = "received"
    /\ IF MONITORING_ENABLED
          THEN /\ state' = "forwarded"
               /\ payloadForwarded' = TRUE
               /\ UNCHANGED taskListChanged
          ELSE IF USE_FIXED
               THEN /\ state' = "ignored"
                    /\ UNCHANGED <<taskListChanged, payloadForwarded>>
               ELSE /\ state' = "crashed"
                    /\ UNCHANGED <<taskListChanged, payloadForwarded>>

Next ==
    \/ HandleMonitoring
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ MONITORING_ENABLED \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state \in States
    /\ taskListChanged \in BOOLEAN
    /\ payloadForwarded \in BOOLEAN

NoCrash == state # "crashed"

ForwardingSafety ==
    state = "forwarded" => MONITORING_ENABLED /\ payloadForwarded

TaskIsolation == ~taskListChanged

=============================================================================
