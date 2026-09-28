--------------------------- MODULE ParslJoinMemoData ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * join_app interaction with memoization and DataFuture readiness.
 *
 * A memo hit produces an already-completed Future without an executor
 * attempt.  A file-valued inner Future cannot complete until stage-in/stage-
 * out readiness is published.  The outer join still uses callback all-done
 * gating and preserves input order.
 ***************************************************************************)

INNER == {"memo", "file", "compute"}
MEMO_HITS == {"memo"}
DATA_INNERS == {"file"}
COMPUTE_INNERS == {"compute"}

InnerStates == {"unresolved", "staging", "running", "succeeded", "failed"}
OuterStates == {"new", "joining", "succeeded", "failed"}
Targets == INNER \cup {"none"}

VARIABLES outerState, joinHandle, innerState, innerResult,
          dataReady, attemptStarted, callbackPending,
          callbackLock, callbackTarget, listResult
vars == <<outerState, joinHandle, innerState, innerResult,
          dataReady, attemptStarted, callbackPending,
          callbackLock, callbackTarget, listResult>>

AllDone == \A i \in INNER : innerState[i] \in {"succeeded", "failed"}
HasFailure == \E i \in INNER : innerState[i] = "failed"
ExpectedResult == <<innerResult["memo"], innerResult["file"], innerResult["compute"]>>

Init ==
    /\ outerState = "new"
    /\ joinHandle = FALSE
    /\ innerState = [i \in INNER |-> "unresolved"]
    /\ innerResult = [i \in INNER |-> "none"]
    /\ dataReady = [i \in INNER |-> FALSE]
    /\ attemptStarted = [i \in INNER |-> FALSE]
    /\ callbackPending = {}
    /\ callbackLock = FALSE
    /\ callbackTarget = "none"
    /\ listResult = <<>>

StartJoin ==
    /\ outerState = "new"
    /\ outerState' = "joining"
    /\ joinHandle' = TRUE
    /\ UNCHANGED <<innerState, innerResult, dataReady, attemptStarted,
                    callbackPending, callbackLock, callbackTarget, listResult>>

CheckMemo(i) ==
    /\ i \in MEMO_HITS
    /\ innerState[i] = "unresolved"
    /\ innerState' = [innerState EXCEPT ![i] = "succeeded"]
    /\ innerResult' = [innerResult EXCEPT ![i] = i \o ":cached"]
    /\ callbackPending' = callbackPending \cup {i}
    /\ UNCHANGED <<outerState, joinHandle, dataReady, attemptStarted,
                    callbackLock, callbackTarget, listResult>>

BeginStage(i) ==
    /\ i \in DATA_INNERS
    /\ innerState[i] = "unresolved"
    /\ innerState' = [innerState EXCEPT ![i] = "staging"]
    /\ UNCHANGED <<outerState, joinHandle, innerResult, dataReady,
                    attemptStarted, callbackPending, callbackLock,
                    callbackTarget, listResult>>

FinishStage(i) ==
    /\ i \in DATA_INNERS
    /\ innerState[i] = "staging"
    /\ innerState' = [innerState EXCEPT ![i] = "succeeded"]
    /\ innerResult' = [innerResult EXCEPT ![i] = i \o ":ready"]
    /\ dataReady' = [dataReady EXCEPT ![i] = TRUE]
    /\ callbackPending' = callbackPending \cup {i}
    /\ UNCHANGED <<outerState, joinHandle, attemptStarted,
                    callbackLock, callbackTarget, listResult>>

StartCompute(i) ==
    /\ i \in COMPUTE_INNERS
    /\ innerState[i] = "unresolved"
    /\ innerState' = [innerState EXCEPT ![i] = "running"]
    /\ attemptStarted' = [attemptStarted EXCEPT ![i] = TRUE]
    /\ UNCHANGED <<outerState, joinHandle, innerResult, dataReady,
                    callbackPending, callbackLock, callbackTarget, listResult>>

CompleteCompute(i) ==
    /\ i \in COMPUTE_INNERS
    /\ innerState[i] = "running"
    /\ innerState' = [innerState EXCEPT ![i] = "succeeded"]
    /\ innerResult' = [innerResult EXCEPT ![i] = i \o ":result"]
    /\ callbackPending' = callbackPending \cup {i}
    /\ UNCHANGED <<outerState, joinHandle, dataReady, attemptStarted,
                    callbackLock, callbackTarget, listResult>>

FailInner(i) ==
    /\ innerState[i] \in {"staging", "running"}
    /\ innerState' = [innerState EXCEPT ![i] = "failed"]
    /\ innerResult' = [innerResult EXCEPT ![i] = i \o ":error"]
    /\ callbackPending' = callbackPending \cup {i}
    /\ UNCHANGED <<outerState, joinHandle, dataReady, attemptStarted,
                    callbackLock, callbackTarget, listResult>>

StartCallback(i) ==
    /\ i \in callbackPending
    /\ ~callbackLock
    /\ callbackPending' = callbackPending \ {i}
    /\ callbackLock' = TRUE
    /\ callbackTarget' = i
    /\ UNCHANGED <<outerState, joinHandle, innerState, innerResult,
                    dataReady, attemptStarted, listResult>>

RunCallback ==
    /\ callbackLock
    /\ callbackLock' = FALSE
    /\ callbackTarget' = "none"
    /\ IF outerState = "joining" /\ AllDone
       THEN /\ outerState' = IF HasFailure THEN "failed" ELSE "succeeded"
            /\ joinHandle' = FALSE
            /\ listResult' = IF HasFailure THEN <<>> ELSE ExpectedResult
       ELSE /\ UNCHANGED <<outerState, joinHandle, listResult>>
    /\ UNCHANGED <<innerState, innerResult, dataReady, attemptStarted,
                    callbackPending>>

Next ==
    \/ StartJoin
    \/ \E i \in INNER : CheckMemo(i)
    \/ \E i \in INNER : BeginStage(i) \/ FinishStage(i)
    \/ \E i \in INNER : StartCompute(i) \/ CompleteCompute(i)
    \/ \E i \in INNER : FailInner(i)
    \/ \E i \in INNER : StartCallback(i)
    \/ RunCallback
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ outerState \in OuterStates
    /\ joinHandle \in BOOLEAN
    /\ innerState \in [INNER -> InnerStates]
    /\ innerResult \in [INNER -> STRING]
    /\ dataReady \in [INNER -> BOOLEAN]
    /\ attemptStarted \in [INNER -> BOOLEAN]
    /\ callbackPending \subseteq INNER
    /\ callbackLock \in BOOLEAN
    /\ callbackTarget \in Targets
    /\ listResult \in Seq(STRING)

MemoizationSafety ==
    \A i \in MEMO_HITS : innerState[i] = "succeeded"
        => /\ ~attemptStarted[i]
           /\ innerResult[i] = i \o ":cached"

DataReadinessSafety ==
    \A i \in DATA_INNERS :
        innerState[i] = "succeeded" => dataReady[i]

JoinCompletionSafety ==
    outerState = "succeeded" =>
        /\ AllDone
        /\ ~joinHandle
        /\ listResult = ExpectedResult
        /\ \A i \in DATA_INNERS : dataReady[i]

JoinFailureSafety ==
    outerState = "failed" =>
        /\ AllDone
        /\ HasFailure
        /\ ~joinHandle

JoinHandleSafety ==
    /\ outerState = "joining" => joinHandle
    /\ outerState \in {"succeeded", "failed"} => ~joinHandle

LockSafety ==
    /\ callbackLock => callbackTarget \in INNER
    /\ ~callbackLock => callbackTarget = "none"

=============================================================================
