-------------------- MODULE ParslStrategyParallelismRangeAdmission --------------------
EXTENDS Integers, Naturals

(***************************************************************************
 * Strategy parallelism range admission.
 *
 * Parsl documents parallelism as a ratio in [0, 1], but the current strategy
 * path does not validate values above one.  With one active slot and queued
 * tasks, a value above one inflates the calculated excess-slot demand and can
 * request the provider maximum.  The fixed branch rejects it before polling.
 *************************************************************************** *)

CONSTANTS USE_FIXED, ABOVE_ONE_PARALLELISM

States == {"configured", "polling", "rejected", "scaled", "overprovisioned"}

VARIABLE state
vars == <<state>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ ABOVE_ONE_PARALLELISM \in BOOLEAN
    /\ state = "configured"

Admit ==
    /\ state = "configured"
    /\ IF USE_FIXED /\ ABOVE_ONE_PARALLELISM
          THEN state' = "rejected"
          ELSE state' = "polling"

PollBacklog ==
    /\ state = "polling"
    /\ IF ABOVE_ONE_PARALLELISM
          THEN state' = "overprovisioned"
          ELSE state' = "scaled"

Next == Admit \/ PollBacklog \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ ABOVE_ONE_PARALLELISM \in BOOLEAN

AdmissionRangeSafety == state = "polling" => ~ABOVE_ONE_PARALLELISM
NoOverprovisioning == state # "overprovisioned"

=============================================================================
