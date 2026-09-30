--------------------------- MODULE ParslGoogleCloudZoneResponseShape ---------------------------
EXTENDS Naturals

(***************************************************************************
 * GoogleCloudProvider.get_zone indexes the zone-list response at `items`
 * before checking its shape.  A malformed or partial API response therefore
 * escapes as a raw KeyError during provider construction.  FIXED models
 * rejecting the response with an explicit provider configuration failure.
 ***************************************************************************)

CONSTANTS HAS_ITEMS, FIXED
VARIABLES phase
vars == <<phase>>

Init ==
    /\ HAS_ITEMS \in BOOLEAN
    /\ FIXED \in BOOLEAN
    /\ phase = "received"

SelectZone ==
    /\ phase = "received"
    /\ IF HAS_ITEMS
          THEN phase' = "selected"
          ELSE IF FIXED
               THEN phase' = "rejected"
               ELSE phase' = "crashed"

Next ==
    \/ SelectZone
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ HAS_ITEMS \in BOOLEAN
    /\ FIXED \in BOOLEAN
    /\ phase \in {"received", "selected", "rejected", "crashed"}

ResponseShapeSafety == phase # "crashed"

=============================================================================
