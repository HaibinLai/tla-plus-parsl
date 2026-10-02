-------------------- MODULE ParslStrategyParallelismAdmission --------------------
EXTENDS Integers, Naturals

(***************************************************************************
 * Strategy parallelism admission.
 *
 * Strategy._general_strategy treats provider.parallelism as a ratio but the
 * provider constructors do not reject negative values.  With one active block
 * and a backlog, a negative ratio bypasses the overload branch and silently
 * under-provisions.  Current admits that value; Fixed rejects it before the
 * first poll.
 *************************************************************************** *)

CONSTANTS USE_FIXED, NEGATIVE_PARALLELISM

States == {"configured", "polling", "rejected", "scaled", "underprovisioned"}

VARIABLES state
vars == <<state>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ NEGATIVE_PARALLELISM \in BOOLEAN
    /\ state = "configured"

Admit ==
    /\ state = "configured"
    /\ IF USE_FIXED /\ NEGATIVE_PARALLELISM
          THEN state' = "rejected"
          ELSE state' = "polling"

PollBacklog ==
    /\ state = "polling"
    /\ IF NEGATIVE_PARALLELISM
          THEN state' = "underprovisioned"
          ELSE state' = "scaled"

Next == Admit \/ PollBacklog \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ NEGATIVE_PARALLELISM \in BOOLEAN

AdmissionSafety == state = "polling" => ~NEGATIVE_PARALLELISM
NoUnderprovisioning == state # "underprovisioned"

=============================================================================
