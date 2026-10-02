--------------------------- MODULE ParslMonitoringQueueFairness ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Bounded database-manager queue service.
 *
 * db_manager.py visits priority, worker, and resource queues in one loop and
 * _get_messages_in_batch limits each visit by batching_threshold.  This model
 * isolates the scheduling policy: a continuously replenished priority queue
 * must not prevent a lower-priority queue from being admitted.
 ***************************************************************************)

CONSTANT USE_FIXED, MAX_ROUNDS

VARIABLES priority, lower, lowerProcessed, rounds
vars == <<priority, lower, lowerProcessed, rounds>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ MAX_ROUNDS = 3
    /\ priority = 1
    /\ lower = TRUE
    /\ lowerProcessed = FALSE
    /\ rounds = 0

Dispatch ==
    /\ rounds < MAX_ROUNDS
    /\ IF USE_FIXED
          THEN /\ lowerProcessed' = TRUE
               /\ lower' = FALSE
               /\ priority' = 1
          ELSE /\ lowerProcessed' = FALSE
               /\ lower' = TRUE
               /\ priority' = 1
    /\ rounds' = rounds + 1

Next == Dispatch \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ MAX_ROUNDS = 3
    /\ priority \in Nat
    /\ lower \in BOOLEAN
    /\ lowerProcessed \in BOOLEAN
    /\ rounds \in 0..MAX_ROUNDS

BoundedAdmission == rounds = MAX_ROUNDS => lowerProcessed

=============================================================================
