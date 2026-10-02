--------------------------- MODULE ParslGlobusTransferReadinessMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Globus ACTIVE-transfer timeout composed with DataFuture and monitoring.
 *
 * Per-call task_wait timeouts do not provide an overall transfer deadline.
 * The Current branch can therefore leave the transfer, DataFuture, consumer,
 * and monitoring row pending forever.  The Fixed branch turns poll-budget
 * exhaustion into one terminal failure across the full staging path.
 ***************************************************************************)

CONSTANTS MAX_POLLS, USE_FIXED

TransferStates == {"submitted", "polling", "succeeded", "timed-out"}
DataStates == {"pending", "ready", "failed"}
ConsumerStates == {"blocked", "running", "failed"}
MonitorStates == {"none", "ready", "failed"}

VARIABLES transfer, polls, dataFuture, consumer, monitor
vars == <<transfer, polls, dataFuture, consumer, monitor>>

Init ==
    /\ MAX_POLLS > 0
    /\ USE_FIXED \in BOOLEAN
    /\ transfer = "submitted"
    /\ polls = 0
    /\ dataFuture = "pending"
    /\ consumer = "blocked"
    /\ monitor = "none"

StartPolling ==
    /\ transfer = "submitted"
    /\ transfer' = "polling"
    /\ UNCHANGED <<polls, dataFuture, consumer, monitor>>

ActivePoll ==
    /\ transfer = "polling"
    /\ polls < MAX_POLLS
    /\ polls' = polls + 1
    /\ transfer' = IF USE_FIXED /\ polls + 1 = MAX_POLLS
                   THEN "timed-out" ELSE transfer
    /\ dataFuture' = IF USE_FIXED /\ polls + 1 = MAX_POLLS
                     THEN "failed" ELSE dataFuture
    /\ consumer' = IF USE_FIXED /\ polls + 1 = MAX_POLLS
                   THEN "failed" ELSE consumer
    /\ monitor' = IF USE_FIXED /\ polls + 1 = MAX_POLLS
                  THEN "failed" ELSE monitor

TransferSucceeds ==
    /\ transfer = "polling"
    /\ transfer' = "succeeded"
    /\ dataFuture' = "ready"
    /\ consumer' = "running"
    /\ monitor' = "ready"
    /\ UNCHANGED polls

BudgetExpires ==
    /\ transfer = "polling"
    /\ polls = MAX_POLLS
    /\ transfer' = IF USE_FIXED THEN "timed-out" ELSE "polling"
    /\ dataFuture' = IF USE_FIXED THEN "failed" ELSE dataFuture
    /\ consumer' = IF USE_FIXED THEN "failed" ELSE consumer
    /\ monitor' = IF USE_FIXED THEN "failed" ELSE monitor
    /\ UNCHANGED polls

Next ==
    \/ StartPolling
    \/ ActivePoll
    \/ TransferSucceeds
    \/ BudgetExpires
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ MAX_POLLS \in Nat
    /\ USE_FIXED \in BOOLEAN
    /\ transfer \in TransferStates
    /\ polls \in Nat
    /\ dataFuture \in DataStates
    /\ consumer \in ConsumerStates
    /\ monitor \in MonitorStates

TimeoutTerminality ==
    polls = MAX_POLLS =>
        /\ transfer = "timed-out"
        /\ dataFuture = "failed"
        /\ consumer = "failed"
        /\ monitor = "failed"

DataFutureFailureConsistency ==
    transfer = "timed-out" => dataFuture = "failed" /\ monitor = "failed"

ConsumerGate == consumer = "running" => dataFuture = "ready" /\ monitor = "ready"

=============================================================================
