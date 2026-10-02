--------------------------- MODULE ParslHtexContactTimeoutStarvationFutureMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX contact-timeout starvation composed with task Future monitoring.
 *
 * Continuous result-socket traffic must not postpone the manager contact
 * deadline.  The Current loop leaves the logical task/Future pending while
 * results keep arriving; the Fixed loop expires the manager on the deadline
 * and publishes one terminal failure.
 ***************************************************************************)

CONSTANTS CONTACT_THRESHOLD, MAX_TIME, MAX_RESULTS, USE_FIXED

VARIABLES now, lastContact, manager, resultCount, task, future, monitor
vars == <<now, lastContact, manager, resultCount, task, future, monitor>>

Init ==
    /\ CONTACT_THRESHOLD > 0
    /\ MAX_TIME >= CONTACT_THRESHOLD
    /\ MAX_RESULTS > 0
    /\ USE_FIXED \in BOOLEAN
    /\ now = 0
    /\ lastContact = 0
    /\ manager = "active"
    /\ resultCount = 0
    /\ task = "running"
    /\ future = "pending"
    /\ monitor = "running"

AdvanceClock ==
    /\ manager = "active"
    /\ now < MAX_TIME
    /\ now' = now + 1
    /\ lastContact' = lastContact
    /\ manager' = IF USE_FIXED /\ now + 1 >= lastContact + CONTACT_THRESHOLD
                  THEN "expired" ELSE "active"
    /\ task' = IF USE_FIXED /\ now + 1 >= lastContact + CONTACT_THRESHOLD
               THEN "failed" ELSE task
    /\ future' = IF USE_FIXED /\ now + 1 >= lastContact + CONTACT_THRESHOLD
                 THEN "failed" ELSE future
    /\ monitor' = IF USE_FIXED /\ now + 1 >= lastContact + CONTACT_THRESHOLD
                  THEN "failed" ELSE monitor
    /\ UNCHANGED resultCount

ResultSocketReadable ==
    /\ manager = "active"
    /\ resultCount < MAX_RESULTS
    /\ now' = now
    /\ lastContact' = lastContact
    /\ manager' = IF USE_FIXED /\ now - lastContact >= CONTACT_THRESHOLD
                   THEN "expired" ELSE "active"
    /\ task' = IF manager' = "expired" THEN "failed" ELSE task
    /\ future' = IF manager' = "expired" THEN "failed" ELSE future
    /\ monitor' = IF manager' = "expired" THEN "failed" ELSE monitor
    /\ resultCount' = resultCount + 1

Next ==
    \/ AdvanceClock
    \/ ResultSocketReadable
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ CONTACT_THRESHOLD \in Nat
    /\ MAX_TIME \in Nat
    /\ MAX_RESULTS \in Nat
    /\ USE_FIXED \in BOOLEAN
    /\ now \in 0..MAX_TIME
    /\ lastContact \in Nat
    /\ manager \in {"active", "expired"}
    /\ resultCount \in 0..MAX_RESULTS
    /\ task \in {"running", "failed"}
    /\ future \in {"pending", "failed"}
    /\ monitor \in {"running", "failed"}

ContactTimeoutSafety ==
    manager = "active" => now - lastContact < CONTACT_THRESHOLD

TimeoutTerminality ==
    manager = "expired" =>
        /\ task = "failed"
        /\ future = "failed"
        /\ monitor = "failed"

PendingFutureSafety ==
    future = "pending" => manager = "active" /\ task = "running"

=============================================================================
