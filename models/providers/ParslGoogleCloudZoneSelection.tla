--------------------------- MODULE ParslGoogleCloudZoneSelection ---------------------------
EXTENDS Naturals

(***************************************************************************
 * GoogleCloudProvider.get_zone selects the first UP zone containing the
 * requested region.  With no matching zone, the current implementation
 * returns None and construction can continue until a later API call.  The
 * fixed branch rejects the configuration at selection time.
 ***************************************************************************)

CONSTANTS MATCHING_ZONE, USE_FIXED

States == {"idle", "selected", "invalid", "rejected"}

VARIABLES state, zone
vars == <<state, zone>>

Init ==
    /\ MATCHING_ZONE \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "idle"
    /\ zone = "none"

SelectMatching ==
    /\ state = "idle"
    /\ MATCHING_ZONE
    /\ state' = "selected"
    /\ zone' = "region-zone"

MissingZoneCurrent ==
    /\ state = "idle"
    /\ ~MATCHING_ZONE
    /\ ~USE_FIXED
    /\ state' = "invalid"
    /\ zone' = "none"

MissingZoneFixed ==
    /\ state = "idle"
    /\ ~MATCHING_ZONE
    /\ USE_FIXED
    /\ state' = "rejected"
    /\ UNCHANGED zone

Next ==
    \/ SelectMatching
    \/ MissingZoneCurrent
    \/ MissingZoneFixed
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ zone \in {"none", "region-zone"}

ZoneSelectionSafety == state # "invalid"

================================================================================
