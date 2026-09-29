--------------------------- MODULE ParslRetryHandlerNegativeCost ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * Retry-handler cost validation.
 *
 * DataFlowKernel adds the value returned by retry_handler to fail_cost and
 * retries while fail_cost <= retries.  Config does not validate that the
 * handler cost is non-negative.  A negative cost can therefore make every
 * failure retryable forever.  The fixed branch rejects a negative cost as a
 * terminal handler error.
 *************************************************************************** *)

CONSTANTS RETRIES, COST_MAGNITUDE, NEGATIVE_COST, USE_FIXED
VARIABLES state, failCost, attempts
vars == <<state, failCost, attempts>>

Init ==
    /\ RETRIES \in Int
    /\ COST_MAGNITUDE \in Nat
    /\ NEGATIVE_COST \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "running"
    /\ failCost = 0
    /\ attempts = 1

Failure ==
    /\ state = "running"
    /\ IF USE_FIXED /\ NEGATIVE_COST
          THEN /\ state' = "failed"
               /\ UNCHANGED <<failCost, attempts>>
          ELSE /\ failCost' = failCost + (IF NEGATIVE_COST THEN -COST_MAGNITUDE ELSE COST_MAGNITUDE)
               /\ IF failCost' <= RETRIES
                     THEN /\ state' = "retrying"
                          /\ UNCHANGED attempts
                     ELSE /\ state' = "failed"
                          /\ UNCHANGED attempts

Retry ==
    /\ state = "retrying"
    /\ state' = "running"
    /\ attempts' = attempts + 1
    /\ UNCHANGED failCost

Next == Failure \/ Retry \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"running", "retrying", "failed"}
    /\ failCost \in Int
    /\ attempts \in Nat

RetryBound == state = "running" => attempts <= 1

=============================================================================
