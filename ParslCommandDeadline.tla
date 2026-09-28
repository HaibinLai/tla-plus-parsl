--------------------------- MODULE ParslCommandDeadline ---------------------------
EXTENDS Integers

(***************************************************************************
 * CommandClient.run computes a remaining deadline separately before each
 * ZMQ poll.  If the deadline has already elapsed, the current path forwards
 * a negative timeout to poll; the FIXED branch clamps it to zero.
 *************************************************************************** *)

CONSTANTS DEADLINE_EXPIRED, USE_FIXED
VARIABLES state, pollTimeout
vars == <<state, pollTimeout>>

Init ==
    /\ DEADLINE_EXPIRED \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "ready"
    /\ pollTimeout = 0

ComputePollTimeout ==
    /\ state = "ready"
    /\ state' = "polling"
    /\ pollTimeout' =
          IF DEADLINE_EXPIRED /\ ~USE_FIXED THEN -1 ELSE 0

Next ==
    \/ ComputePollTimeout
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"ready", "polling"}
    /\ pollTimeout \in Int

PollTimeoutSafety == state = "polling" => pollTimeout >= 0

=============================================================================
