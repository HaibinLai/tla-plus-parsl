--------------------------- MODULE ParslTimerIntervalValidation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Timer interval admission.
 *
 * parsl.utils.Timer currently applies max(0, interval), so a negative
 * interval is silently accepted as a zero-delay periodic timer.  The fixed
 * branch rejects negative configuration before starting the timer thread.
 *************************************************************************** *)

CONSTANT INPUT_KIND, USE_FIXED

Kinds == {"negative", "zero", "positive"}
States == {"unvalidated", "running", "rejected"}

VARIABLES state, effectiveInterval, callbackCount
vars == <<state, effectiveInterval, callbackCount>>

Init ==
    /\ INPUT_KIND \in Kinds
    /\ USE_FIXED \in BOOLEAN
    /\ state = "unvalidated"
    /\ effectiveInterval = "unset"
    /\ callbackCount = 0

Validate ==
    /\ state = "unvalidated"
    /\ IF INPUT_KIND = "negative" /\ USE_FIXED
       THEN /\ state' = "rejected"
            /\ effectiveInterval' = "unset"
       ELSE /\ state' = "running"
            /\ effectiveInterval' =
                   IF INPUT_KIND = "negative" THEN "zero" ELSE INPUT_KIND
    /\ UNCHANGED callbackCount

Callback ==
    /\ state = "running"
    /\ effectiveInterval = "zero"
    /\ callbackCount' = callbackCount + 1
    /\ UNCHANGED <<state, effectiveInterval>>

Next ==
    \/ Validate
    \/ Callback
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ INPUT_KIND \in Kinds
    /\ USE_FIXED \in BOOLEAN
    /\ state \in States
    /\ effectiveInterval \in {"unset", "negative", "zero", "positive"}
    /\ callbackCount \in Nat

NegativeIntervalSafety ==
    (INPUT_KIND = "negative" /\ state # "unvalidated") => state = "rejected"

NoNegativeEffectiveInterval ==
    state = "running" => effectiveInterval \in {"zero", "positive"}

=============================================================================
