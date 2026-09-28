--------------------------- MODULE ParslHtexUnknownManagerMessage ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Identity isolation at Interchange.process_manager_socket_message.
 *
 * A non-registration message from an unknown manager is ignored before any
 * heartbeat reply, task update, or result forwarding.  Registration is the
 * only message that may create a new ready-manager record.
 ***************************************************************************)

CONSTANTS MESSAGE_KIND, MANAGER_KNOWN

Kinds == {"heartbeat", "result", "registration"}
States == {"received", "ignored", "processed", "registered"}

VARIABLES state, readyManagers, replies, taskUpdates
vars == <<state, readyManagers, replies, taskUpdates>>

Init ==
    /\ MESSAGE_KIND \in Kinds
    /\ MANAGER_KNOWN \in BOOLEAN
    /\ state = "received"
    /\ readyManagers = 0
    /\ replies = 0
    /\ taskUpdates = 0

HandleMessage ==
    /\ state = "received"
    /\ IF MESSAGE_KIND = "registration"
          THEN /\ state' = "registered"
               /\ readyManagers' = readyManagers + 1
               /\ UNCHANGED <<replies, taskUpdates>>
          ELSE IF ~MANAGER_KNOWN
               THEN /\ state' = "ignored"
                    /\ UNCHANGED <<readyManagers, replies, taskUpdates>>
               ELSE /\ state' = "processed"
                    /\ replies' = IF MESSAGE_KIND = "heartbeat" THEN 1 ELSE 0
                    /\ taskUpdates' = IF MESSAGE_KIND = "result" THEN 1 ELSE 0
                    /\ UNCHANGED readyManagers

Next ==
    \/ HandleMessage
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ MESSAGE_KIND \in Kinds
    /\ MANAGER_KNOWN \in BOOLEAN
    /\ state \in States
    /\ readyManagers \in Nat
    /\ replies \in Nat
    /\ taskUpdates \in Nat

UnknownIsolation ==
    ~MANAGER_KNOWN /\ MESSAGE_KIND # "registration" /\ state = "ignored" =>
        /\ readyManagers = 0
        /\ replies = 0
        /\ taskUpdates = 0

=============================================================================
