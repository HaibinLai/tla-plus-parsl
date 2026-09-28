--------------------------- MODULE ParslProviderPollClockRollback ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * BlockProviderExecutor.poll_facade uses wall-clock time:
 *   now >= _last_poll_time + status_polling_interval
 * A wall-clock rollback can therefore suppress status polling until the old
 * timestamp is reached.  USE_FIXED models a rollback-aware/monotonic guard.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES now, lastPoll, interval, polls
vars == <<now, lastPoll, interval, polls>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ now = 100
    /\ lastPoll = 100
    /\ interval = 10
    /\ polls = 0

ClockRollback ==
    /\ now = 100
    /\ now' = 90
    /\ lastPoll' = IF USE_FIXED THEN 90 ELSE lastPoll
    /\ polls' = IF USE_FIXED THEN 1 ELSE polls
    /\ UNCHANGED interval

Poll ==
    /\ (USE_FIXED /\ now < lastPoll) \/ now >= lastPoll + interval
    /\ polls' = polls + 1
    /\ lastPoll' = now
    /\ UNCHANGED <<now, interval>>

Done ==
    /\ polls > 0
    /\ UNCHANGED vars

Next == ClockRollback \/ Poll \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ now \in Int
    /\ lastPoll \in Int
    /\ interval \in Nat
    /\ polls \in Nat

RollbackPollSafety ==
    now < lastPoll => polls > 0

=============================================================================
