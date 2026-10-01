--------------------------- MODULE ParslRadicalPilotDecodeFailure ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Radical-Pilot Python result decode boundary.
 *
 * A DONE callback carries a serialized Python result.  The Current callback
 * lets a decode exception escape, leaving the Parsl Future pending.  The
 * Fixed branch converts the decode failure into a terminal Future exception.
 ***************************************************************************)

CONSTANT USE_FIXED

FutureStates == {"pending", "succeeded", "failed"}
CallbackStates == {"waiting", "decoded", "decode_failed"}

VARIABLES futureState, callbackState
vars == <<futureState, callbackState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ futureState = "pending"
    /\ callbackState = "waiting"

DecodeSuccess ==
    /\ callbackState = "waiting"
    /\ callbackState' = "decoded"
    /\ futureState' = "succeeded"

DecodeFailure ==
    /\ callbackState = "waiting"
    /\ callbackState' = "decode_failed"
    /\ futureState' = IF USE_FIXED THEN "failed" ELSE "pending"

Next ==
    \/ DecodeSuccess
    \/ DecodeFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ futureState \in FutureStates
    /\ callbackState \in CallbackStates

CallbackTerminality ==
    callbackState = "decode_failed" => futureState # "pending"

=============================================================================
