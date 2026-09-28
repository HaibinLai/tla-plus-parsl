--------------------------- MODULE ParslJoinCallbackRace ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * Callback-level join_app model.
 *
 * Each inner Future completion schedules a callback.  A callback may run
 * before all inner Futures are done and return without finalizing the outer
 * Future.  The callback for the final inner Future then performs one atomic
 * all-done check under a join lock.  Duplicate callbacks after termination
 * are harmless.
 ***************************************************************************)

INNER == {"I1", "I2", "I3"}
InnerStates == {"unresolved", "succeeded", "failed"}
OuterStates == {"new", "joining", "succeeded", "failed"}
CallbackTargets == INNER \cup {"none"}

VARIABLES outerState, joinHandle, innerState, innerResult,
          callbackPending, callbackLock, callbackTarget, listResult
vars == <<outerState, joinHandle, innerState, innerResult,
          callbackPending, callbackLock, callbackTarget, listResult>>

ExpectedResult == <<innerResult["I1"], innerResult["I2"], innerResult["I3"]>>
AllDone == \A i \in INNER : innerState[i] \in {"succeeded", "failed"}
HasFailure == \E i \in INNER : innerState[i] = "failed"

Init ==
    /\ outerState = "new"
    /\ joinHandle = FALSE
    /\ innerState = [i \in INNER |-> "unresolved"]
    /\ innerResult = [i \in INNER |-> "none"]
    /\ callbackPending = {}
    /\ callbackLock = FALSE
    /\ callbackTarget = "none"
    /\ listResult = <<>>

StartJoin ==
    /\ outerState = "new"
    /\ outerState' = "joining"
    /\ joinHandle' = TRUE
    /\ UNCHANGED <<innerState, innerResult, callbackPending,
                    callbackLock, callbackTarget, listResult>>

CompleteInner(i) ==
    /\ innerState[i] = "unresolved"
    /\ innerState' = [innerState EXCEPT ![i] = "succeeded"]
    /\ innerResult' = [innerResult EXCEPT ![i] = i \o ":result"]
    /\ callbackPending' = callbackPending \cup {i}
    /\ UNCHANGED <<outerState, joinHandle, callbackLock,
                    callbackTarget, listResult>>

FailInner(i) ==
    /\ innerState[i] = "unresolved"
    /\ innerState' = [innerState EXCEPT ![i] = "failed"]
    /\ innerResult' = [innerResult EXCEPT ![i] = i \o ":error"]
    /\ callbackPending' = callbackPending \cup {i}
    /\ UNCHANGED <<outerState, joinHandle, callbackLock,
                    callbackTarget, listResult>>

EmitDuplicateCallback(i) ==
    /\ innerState[i] \in {"succeeded", "failed"}
    /\ outerState \in {"joining", "succeeded", "failed"}
    /\ callbackPending' = callbackPending \cup {i}
    /\ UNCHANGED <<outerState, joinHandle, innerState, innerResult,
                    callbackLock, callbackTarget, listResult>>

StartCallback(i) ==
    /\ i \in callbackPending
    /\ ~callbackLock
    /\ callbackPending' = callbackPending \ {i}
    /\ callbackLock' = TRUE
    /\ callbackTarget' = i
    /\ UNCHANGED <<outerState, joinHandle, innerState, innerResult, listResult>>

RunCallback ==
    /\ callbackLock
    /\ callbackLock' = FALSE
    /\ callbackTarget' = "none"
    /\ IF outerState = "joining" /\ AllDone
       THEN /\ outerState' = IF HasFailure THEN "failed" ELSE "succeeded"
            /\ joinHandle' = FALSE
            /\ listResult' = IF HasFailure THEN <<>> ELSE ExpectedResult
       ELSE /\ UNCHANGED <<outerState, joinHandle, listResult>>
    /\ UNCHANGED <<innerState, innerResult, callbackPending>>

Next ==
    \/ StartJoin
    \/ \E i \in INNER : CompleteInner(i) \/ FailInner(i)
    \/ \E i \in INNER : EmitDuplicateCallback(i)
    \/ \E i \in INNER : StartCallback(i)
    \/ RunCallback
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ outerState \in OuterStates
    /\ joinHandle \in BOOLEAN
    /\ innerState \in [INNER -> InnerStates]
    /\ innerResult \in [INNER -> STRING]
    /\ callbackPending \subseteq INNER
    /\ callbackLock \in BOOLEAN
    /\ callbackTarget \in CallbackTargets
    /\ listResult \in Seq(STRING)

JoinCompletionSafety ==
    outerState = "succeeded" =>
        /\ AllDone
        /\ ~joinHandle
        /\ listResult = ExpectedResult

JoinFailureSafety ==
    outerState = "failed" =>
        /\ AllDone
        /\ HasFailure
        /\ ~joinHandle

NoEarlyFinalization ==
    outerState = "joining" => joinHandle

LockSafety ==
    /\ callbackLock => callbackTarget \in INNER
    /\ ~callbackLock => callbackTarget = "none"

=============================================================================
