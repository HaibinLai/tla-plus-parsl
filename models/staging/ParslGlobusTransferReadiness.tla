--------------------------- MODULE ParslGlobusTransferReadiness ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Globus transfer timeout propagated to DataFuture and consumer admission.
 *
 * Globus.transfer_file polls an ACTIVE transfer with a per-call timeout but
 * no overall deadline.  This composition connects that transfer Future to
 * DataFuture readiness and a dependent task.  USE_FIXED turns exhaustion of
 * the bounded poll budget into a failed transfer and failed DataFuture, so a
 * consumer cannot remain ambiguously pending.
 ***************************************************************************)

CONSTANTS MAX_POLLS, USE_FIXED

TransferStates == {"submitted", "polling", "succeeded", "timed-out"}
DataStates == {"pending", "ready", "failed"}
ConsumerStates == {"blocked", "running", "failed"}

VARIABLES transfer, polls, dataFuture, consumer
vars == <<transfer, polls, dataFuture, consumer>>

Init ==
    /\ MAX_POLLS \in Nat
    /\ MAX_POLLS > 0
    /\ USE_FIXED \in BOOLEAN
    /\ transfer = "submitted"
    /\ polls = 0
    /\ dataFuture = "pending"
    /\ consumer = "blocked"

StartPolling ==
    /\ transfer = "submitted"
    /\ transfer' = "polling"
    /\ UNCHANGED <<polls, dataFuture, consumer>>

ActivePoll ==
    /\ transfer = "polling"
    /\ polls < MAX_POLLS
    /\ polls' = polls + 1
    /\ UNCHANGED <<transfer, dataFuture, consumer>>

TransferSucceeds ==
    /\ transfer = "polling"
    /\ transfer' = "succeeded"
    /\ dataFuture' = "ready"
    /\ UNCHANGED <<polls, consumer>>

BudgetExpires ==
    /\ transfer = "polling"
    /\ polls = MAX_POLLS
    /\ IF USE_FIXED
          THEN /\ transfer' = "timed-out"
               /\ dataFuture' = "failed"
               /\ consumer' = "failed"
          ELSE /\ transfer' = "polling"
               /\ UNCHANGED <<dataFuture, consumer>>
    /\ UNCHANGED polls

AdmitConsumer ==
    /\ dataFuture = "ready"
    /\ consumer = "blocked"
    /\ consumer' = "running"
    /\ UNCHANGED <<transfer, polls, dataFuture>>

Next ==
    \/ StartPolling
    \/ ActivePoll
    \/ TransferSucceeds
    \/ BudgetExpires
    \/ AdmitConsumer
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ MAX_POLLS \in Nat
    /\ transfer \in TransferStates
    /\ polls \in Nat
    /\ dataFuture \in DataStates
    /\ consumer \in ConsumerStates

TimeoutOutcomeSafety ==
    polls = MAX_POLLS => transfer = "timed-out" \/ dataFuture = "ready" \/ USE_FIXED

DataFutureFailureConsistency ==
    transfer = "timed-out" => dataFuture = "failed" /\ consumer = "failed"

ConsumerGate ==
    consumer = "running" => dataFuture = "ready"

=============================================================================
