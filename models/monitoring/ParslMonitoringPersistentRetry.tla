--------------------------- MODULE ParslMonitoringPersistentRetry ---------------------------
EXTENDS Naturals

(***************************************************************************
 * DatabaseManager._insert retries OperationalError forever.  A transient
 * database lock can recover, but a persistent lock or broken database leaves
 * the monitoring thread unable to finish shutdown.  USE_FIXED adds a bounded
 * retry budget and records an aborted write instead of spinning forever.
 *************************************************************************** *)

CONSTANT USE_FIXED
MAX_ATTEMPTS == 2

VARIABLES state, attempts
vars == <<state, attempts>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "queued"
    /\ attempts = 0

BeginInsert ==
    /\ state = "queued"
    /\ state' = "writing"
    /\ UNCHANGED attempts

OperationalFailure ==
    /\ state = "writing"
    /\ IF USE_FIXED /\ attempts + 1 >= MAX_ATTEMPTS
          THEN /\ state' = "aborted"
               /\ attempts' = MAX_ATTEMPTS
          ELSE /\ state' = "retrying"
               /\ attempts' = attempts + 1

RetryWait ==
    /\ state = "retrying"
    /\ state' = "writing"
    /\ UNCHANGED attempts

Success ==
    /\ state = "writing"
    /\ state' = "stored"
    /\ UNCHANGED attempts

Done ==
    /\ state \in {"stored", "aborted"}
    /\ UNCHANGED vars

Next == BeginInsert \/ OperationalFailure \/ RetryWait \/ Success \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"queued", "writing", "retrying", "stored", "aborted"}
    /\ attempts \in 0..MAX_ATTEMPTS

RetryBoundSafety ==
    attempts < MAX_ATTEMPTS \/ state \in {"stored", "aborted"}

FixedTermination ==
    USE_FIXED /\ attempts = MAX_ATTEMPTS => state \in {"writing", "stored", "aborted"}

=============================================================================
