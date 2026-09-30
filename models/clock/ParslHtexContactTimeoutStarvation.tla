--------------------------- MODULE ParslHtexContactTimeoutStarvation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * The manager's communicator checks interchange contact only in the branch
 * where neither the interchange socket nor the result socket is readable.
 * Continuous result-socket traffic can therefore postpone the contact check.
 * USE_FIXED checks the deadline on every loop iteration.
 ***************************************************************************)

CONSTANTS CONTACT_THRESHOLD, MAX_TIME, MAX_RESULTS, USE_FIXED
VARIABLES now, lastContact, state, resultCount
vars == <<now, lastContact, state, resultCount>>

Init ==
    /\ CONTACT_THRESHOLD \in Nat
    /\ CONTACT_THRESHOLD > 0
    /\ MAX_TIME \in Nat
    /\ MAX_TIME >= CONTACT_THRESHOLD
    /\ MAX_RESULTS \in Nat
    /\ USE_FIXED \in BOOLEAN
    /\ now = 0
    /\ lastContact = 0
    /\ state = "active"
    /\ resultCount = 0

AdvanceClock ==
    /\ state = "active"
    /\ now < MAX_TIME
    /\ now' = now + 1
    /\ lastContact' = lastContact
    /\ state' = IF USE_FIXED /\ now + 1 >= lastContact + CONTACT_THRESHOLD
                   THEN "expired" ELSE "active"
    /\ UNCHANGED resultCount

ResultSocketReadable ==
    /\ state = "active"
    /\ resultCount < MAX_RESULTS
    /\ now' = now
    /\ lastContact' = lastContact
    /\ state' = IF USE_FIXED /\ now - lastContact >= CONTACT_THRESHOLD
                   THEN "expired" ELSE "active"
    /\ resultCount' = resultCount + 1

Next ==
    \/ AdvanceClock
    \/ ResultSocketReadable
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in 0..MAX_TIME
    /\ lastContact \in Nat
    /\ state \in {"active", "expired"}
    /\ resultCount \in 0..MAX_RESULTS

ContactTimeoutSafety == state = "active" => now - lastContact < CONTACT_THRESHOLD
=============================================================================
