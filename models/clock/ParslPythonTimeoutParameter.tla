--------------------------- MODULE ParslPythonTimeoutParameter ---------------------------
EXTENDS Integers

(***************************************************************************
 * Python-app timeout parameter admission.
 *
 * ``parsl.app.python.timeout`` passes the delay directly to
 * ``threading.Timer``.  Non-positive values therefore inject AppTimeout
 * immediately.  USE_FIXED models rejecting non-positive timeout values at
 * wrapper construction.
 *************************************************************************** *)

CONSTANTS DELAY_KIND, USE_FIXED
Kinds == {"negative", "zero", "positive"}
States == {"unvalidated", "running", "timed_out", "rejected"}

VARIABLES state
vars == <<state>>

Init ==
    /\ DELAY_KIND \in Kinds
    /\ USE_FIXED \in BOOLEAN
    /\ state = "unvalidated"

Start ==
    /\ state = "unvalidated"
    /\ state' = IF (DELAY_KIND = "negative" \/ DELAY_KIND = "zero") /\ USE_FIXED
                   THEN "rejected"
                   ELSE IF DELAY_KIND = "positive" THEN "running" ELSE "timed_out"

InjectImmediateTimeout ==
    /\ state = "unvalidated"
    /\ DELAY_KIND = "negative"
    /\ ~USE_FIXED
    /\ state' = "timed_out"

Next ==
    \/ Start
    \/ InjectImmediateTimeout
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ DELAY_KIND \in Kinds
    /\ USE_FIXED \in BOOLEAN
    /\ state \in States

TimeoutParameterSafety ==
    state \in {"running", "timed_out"} => DELAY_KIND = "positive"

=============================================================================
