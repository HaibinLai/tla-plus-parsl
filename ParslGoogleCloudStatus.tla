--------------------------- MODULE ParslGoogleCloudStatus ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Google Compute Engine status translation.
 *
 * GoogleCloudProvider.status indexes translate_table directly.  A new or
 * otherwise unrecognized GCE status therefore raises KeyError; a tolerant
 * candidate maps it to UNKNOWN instead.
 ***************************************************************************)

CONSTANTS UNKNOWN_STATUS, USE_FIXED

States == {"idle", "updated", "crashed"}

VARIABLES state, mappedStatus
vars == <<state, mappedStatus>>

Init ==
    /\ UNKNOWN_STATUS \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "idle"
    /\ mappedStatus = "none"

TranslateKnown ==
    /\ state = "idle"
    /\ ~UNKNOWN_STATUS
    /\ state' = "updated"
    /\ mappedStatus' = "running"

UnknownStatusCurrent ==
    /\ state = "idle"
    /\ UNKNOWN_STATUS
    /\ ~USE_FIXED
    /\ state' = "crashed"
    /\ UNCHANGED mappedStatus

UnknownStatusFixed ==
    /\ state = "idle"
    /\ UNKNOWN_STATUS
    /\ USE_FIXED
    /\ state' = "updated"
    /\ mappedStatus' = "unknown"

Next ==
    \/ TranslateKnown
    \/ UnknownStatusCurrent
    \/ UnknownStatusFixed
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ mappedStatus \in {"none", "running", "unknown"}

PollingSafety == state # "crashed"

=============================================================================
