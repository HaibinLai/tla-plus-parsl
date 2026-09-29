--------------------------- MODULE ParslHtexManagerEligibility ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * HTEX selection versus dispatch eligibility.
 *
 * The selector orders interesting managers, while Interchange dispatch still
 * checks each record's active and draining flags.  A selector result is not an
 * admission decision: inactive or draining managers are skipped.
 *************************************************************************** *)

MANAGERS == {"m0", "m1", "m2"}
ACTIVE == [m \in MANAGERS |-> m = "m2"]
DRAINING == [m \in MANAGERS |-> m = "m1"]
Eligible(m) == ACTIVE[m] /\ ~DRAINING[m]

VARIABLES phase, pending, order, cursor, sent, skipped
vars == <<phase, pending, order, cursor, sent, skipped>>

Init ==
    /\ phase = "queued"
    /\ pending = TRUE
    /\ order = <<"m0", "m1", "m2">>
    /\ cursor = 1
    /\ sent = {}
    /\ skipped = {}

SkipManager ==
    /\ phase = "queued"
    /\ pending
    /\ cursor <= Len(order)
    /\ ~Eligible(order[cursor])
    /\ skipped' = skipped \cup {order[cursor]}
    /\ cursor' = cursor + 1
    /\ UNCHANGED <<phase, pending, order, sent>>

DispatchManager ==
    /\ phase = "queued"
    /\ pending
    /\ cursor <= Len(order)
    /\ Eligible(order[cursor])
    /\ sent' = sent \cup {order[cursor]}
    /\ pending' = FALSE
    /\ phase' = "sent"
    /\ UNCHANGED <<order, cursor, skipped>>

Next ==
    \/ SkipManager
    \/ DispatchManager
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"queued", "sent"}
    /\ pending \in BOOLEAN
    /\ order \in Seq(MANAGERS)
    /\ cursor \in 1..(Len(order) + 1)
    /\ sent \subseteq MANAGERS
    /\ skipped \subseteq MANAGERS

EligibilitySafety ==
    \A m \in sent : Eligible(m)

SkipSafety ==
    skipped \subseteq {m \in MANAGERS : ~Eligible(m)}

SingleDispatchSafety == Cardinality(sent) <= 1

=============================================================================
