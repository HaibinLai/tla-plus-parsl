--------------------------- MODULE ParslPollerCloseScaleInRace ---------------------------
EXTENDS Naturals

(***************************************************************************
 * JobStatusPoller.close(timeout) and executor scale-in.
 *
 * Timer.close sets the kill event and joins with a timeout.  The current
 * JobStatusPoller.close then scales in executors even when the poll callback
 * thread is still running.  The fixed branch waits for callback quiescence
 * before allowing provider scale-in.
 ***************************************************************************)

CONSTANT USE_FIXED

TimerStates == {"running", "stopping", "stopped"}
CallbackStates == {"idle", "running"}
Outcomes == {"none", "joined", "timed_out"}

VARIABLES timerState, callbackState, closeRequested, closeOutcome, scaledIn
vars == <<timerState, callbackState, closeRequested, closeOutcome, scaledIn>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ timerState = "running"
    /\ callbackState = "idle"
    /\ closeRequested = FALSE
    /\ closeOutcome = "none"
    /\ scaledIn = FALSE

StartPoll ==
    /\ timerState = "running"
    /\ callbackState = "idle"
    /\ callbackState' = "running"
    /\ UNCHANGED <<timerState, closeRequested, closeOutcome, scaledIn>>

FinishPoll ==
    /\ callbackState = "running"
    /\ callbackState' = "idle"
    /\ UNCHANGED <<timerState, closeRequested, closeOutcome, scaledIn>>

RequestClose ==
    /\ timerState = "running"
    /\ closeRequested' = TRUE
    /\ timerState' = "stopping"
    /\ UNCHANGED <<callbackState, closeOutcome, scaledIn>>

JoinReturns ==
    /\ closeRequested
    /\ callbackState = "idle"
    /\ timerState' = "stopped"
    /\ closeOutcome' = "joined"
    /\ UNCHANGED <<callbackState, closeRequested, scaledIn>>

JoinTimesOut ==
    /\ closeRequested
    /\ callbackState = "running"
    /\ timerState' = IF USE_FIXED THEN "stopping" ELSE "stopped"
    /\ closeOutcome' = "timed_out"
    /\ UNCHANGED <<callbackState, closeRequested, scaledIn>>

ScaleIn ==
    /\ closeRequested
    /\ timerState = IF USE_FIXED THEN "stopped" ELSE "stopped"
    /\ scaledIn' = TRUE
    /\ UNCHANGED <<timerState, callbackState, closeRequested, closeOutcome>>

Next ==
    \/ StartPoll
    \/ FinishPoll
    \/ RequestClose
    \/ JoinReturns
    \/ JoinTimesOut
    \/ ScaleIn
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ timerState \in TimerStates
    /\ callbackState \in CallbackStates
    /\ closeRequested \in BOOLEAN
    /\ closeOutcome \in Outcomes
    /\ scaledIn \in BOOLEAN

ScaleInAfterPollQuiescence ==
    scaledIn => callbackState = "idle"

CloseOutcomeSafety ==
    closeOutcome = "joined" => timerState = "stopped"

=============================================================================
