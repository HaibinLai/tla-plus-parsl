--------------------------- MODULE ParslProbeAddresses ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX connection probing.
 *
 * probe_addresses rejects an empty candidate set, returns one candidate after
 * a probe response, and raises ConnectionError when the poll timeout expires
 * without a response.  The address strings, sockets, and pickle payload are
 * abstracted to a bounded response outcome.
 *************************************************************************** *)

CONSTANTS ADDRESS_COUNT, RESPONSE
VARIABLES state, selected
vars == <<state, selected>>

States == {"initial", "probing", "selected", "failed", "rejected"}

Init ==
    /\ ADDRESS_COUNT \in 0..2
    /\ RESPONSE \in BOOLEAN
    /\ state = "initial"
    /\ selected = FALSE

RejectEmpty ==
    /\ state = "initial"
    /\ ADDRESS_COUNT = 0
    /\ state' = "rejected"
    /\ UNCHANGED selected

StartProbes ==
    /\ state = "initial"
    /\ ADDRESS_COUNT > 0
    /\ state' = "probing"
    /\ UNCHANGED selected

ReceiveProbeReply ==
    /\ state = "probing"
    /\ RESPONSE
    /\ state' = "selected"
    /\ selected' = TRUE

ProbeTimeout ==
    /\ state = "probing"
    /\ ~RESPONSE
    /\ state' = "failed"
    /\ UNCHANGED selected

Next ==
    \/ RejectEmpty
    \/ StartProbes
    \/ ReceiveProbeReply
    \/ ProbeTimeout
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ selected \in BOOLEAN

ProbeOutcomeSafety ==
    /\ state = "selected" => selected
    /\ state = "selected" => ADDRESS_COUNT > 0
    /\ state = "failed" => ~selected
=============================================================================
