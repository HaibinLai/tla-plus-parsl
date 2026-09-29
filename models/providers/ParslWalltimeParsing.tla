--------------------------- MODULE ParslWalltimeParsing ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Walltime string conversion used by provider templates.
 *
 * wtime_to_minutes currently truncates the seconds field.  A positive
 * sub-minute request therefore becomes zero minutes.  USE_FIXED models
 * rounding any positive duration up to one minute before submission.
 *************************************************************************** *)

CONSTANT DURATION_KIND, USE_FIXED

Kinds == {"zero", "subminute", "whole-minute"}
VARIABLES state, minutes
vars == <<state, minutes>>

Init ==
    /\ DURATION_KIND \in Kinds
    /\ USE_FIXED \in BOOLEAN
    /\ state = "unparsed"
    /\ minutes = 0

Parse ==
    /\ state = "unparsed"
    /\ state' = "parsed"
    /\ minutes' =
          IF DURATION_KIND = "zero" THEN 0
          ELSE IF DURATION_KIND = "subminute" /\ USE_FIXED THEN 1
          ELSE IF DURATION_KIND = "subminute" THEN 0 ELSE 5

Next ==
    \/ Parse
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ DURATION_KIND \in Kinds
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"unparsed", "parsed"}
    /\ minutes \in Nat

PositiveDurationSafety ==
    state = "parsed" /\ DURATION_KIND = "subminute" => minutes >= 1

=============================================================================
