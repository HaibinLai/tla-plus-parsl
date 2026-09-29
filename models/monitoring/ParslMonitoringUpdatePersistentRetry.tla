--------------------------- MODULE ParslMonitoringUpdatePersistentRetry ---------------------------
EXTENDS Naturals

(***************************************************************************
 * DatabaseManager._update retries OperationalError forever, independently of
 * the analogous _insert path.  A permanent lock can therefore keep an update
 * worker alive indefinitely.  USE_FIXED adds a bounded retry budget and an
 * explicit aborted outcome.
 ***************************************************************************)

CONSTANT USE_FIXED
MAX_ATTEMPTS == 2

VARIABLES state, attempts
vars == <<state, attempts>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "queued"
    /\ attempts = 0

BeginUpdate ==
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

Next == BeginUpdate \/ OperationalFailure \/ RetryWait \/ Success \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"queued", "writing", "retrying", "stored", "aborted"}
    /\ attempts \in 0..MAX_ATTEMPTS

RetryBoundSafety ==
    attempts < MAX_ATTEMPTS \/ state \in {"stored", "aborted"}

FixedTermination ==
    USE_FIXED /\ attempts = MAX_ATTEMPTS => state \in {"writing", "stored", "aborted"}

=============================================================================
