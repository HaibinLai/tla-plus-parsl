--------------------------- MODULE ParslMonitoringDeferredMultiplicity ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Multiple first worker messages can arrive before the corresponding TRY
 * row.  DatabaseManager currently stores one deferred message per task/try,
 * so later observations replace earlier ones.  The fixed branch keeps a
 * bounded sequence of three observations for this model.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES tryInserted, pending, replayed, lost
vars == <<tryInserted, pending, replayed, lost>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ tryInserted = FALSE
    /\ pending = 0
    /\ replayed = 0
    /\ lost = 0

ReceiveFirst ==
    /\ ~tryInserted
    /\ IF USE_FIXED THEN pending < 3 ELSE lost < 3
    /\ IF USE_FIXED
          THEN /\ pending' = pending + 1
               /\ UNCHANGED lost
          ELSE /\ pending' = 1
               /\ lost' = lost + IF pending > 0 THEN 1 ELSE 0
    /\ UNCHANGED <<tryInserted, replayed>>

InsertTry ==
    /\ ~tryInserted
    /\ tryInserted' = TRUE
    /\ UNCHANGED <<pending, replayed, lost>>

ReplayOne ==
    /\ tryInserted
    /\ pending > 0
    /\ pending' = pending - 1
    /\ replayed' = replayed + 1
    /\ UNCHANGED <<tryInserted, lost>>

Next ==
    \/ ReceiveFirst
    \/ InsertTry
    \/ ReplayOne
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ tryInserted \in BOOLEAN
    /\ pending \in 0..3
    /\ replayed \in 0..3
    /\ lost \in 0..3

NoDeferredLoss == USE_FIXED \/ lost = 0
ReplayCountSafety == replayed + pending <= 3

=============================================================================
