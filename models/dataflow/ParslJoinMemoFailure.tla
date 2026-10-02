--------------------------- MODULE ParslJoinMemoFailure ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * Memoized failure + join_app + data-readiness regression model.
 *
 * A failed memo hit is already a terminal Future and must not launch a new
 * physical attempt.  A join callback must still observe that exception and
 * fail the outer task, even when another inner Future is waiting for stage-in.
 ***************************************************************************)

INNER == {"memo_failure", "file_success"}
InnerStates == {"unresolved", "staging", "succeeded", "failed"}
OuterStates == {"new", "joining", "succeeded", "failed"}

CONSTANTS USE_FIXED

VARIABLES outer, inner, result, ready, attempts, callbacks,
          callbackLock, callbackTarget, joinResult

vars == <<outer, inner, result, ready, attempts, callbacks,
           callbackLock, callbackTarget, joinResult>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ outer = "new"
    /\ inner = [i \in INNER |-> "unresolved"]
    /\ result = [i \in INNER |-> "none"]
    /\ ready = [i \in INNER |-> FALSE]
    /\ attempts = [i \in INNER |-> 0]
    /\ callbacks = {}
    /\ callbackLock = FALSE
    /\ callbackTarget = "none"
    /\ joinResult = <<>>

StartJoin ==
    /\ outer = "new"
    /\ outer' = "joining"
    /\ UNCHANGED <<inner, result, ready, attempts, callbacks,
                    callbackLock, callbackTarget, joinResult>>

MemoizedFailure ==
    /\ outer = "joining"
    /\ inner["memo_failure"] = "unresolved"
    /\ inner' = [inner EXCEPT !["memo_failure"] = "failed"]
    /\ result' = [result EXCEPT !["memo_failure"] = "memo-error"]
    /\ attempts' = [attempts EXCEPT !["memo_failure"] = 0]
    /\ callbacks' = callbacks \cup {"memo_failure"}
    /\ UNCHANGED <<outer, ready, callbackLock, callbackTarget, joinResult>>

BeginStageIn ==
    /\ outer = "joining"
    /\ inner["file_success"] = "unresolved"
    /\ inner' = [inner EXCEPT !["file_success"] = "staging"]
    /\ UNCHANGED <<outer, result, ready, attempts, callbacks,
                    callbackLock, callbackTarget, joinResult>>

FinishStageIn ==
    /\ outer = "joining"
    /\ inner["file_success"] = "staging"
    /\ inner' = [inner EXCEPT !["file_success"] = "succeeded"]
    /\ result' = [result EXCEPT !["file_success"] = "file-ready"]
    /\ ready' = [ready EXCEPT !["file_success"] = TRUE]
    /\ callbacks' = callbacks \cup {"file_success"}
    /\ UNCHANGED <<outer, attempts, callbackLock,
                    callbackTarget, joinResult>>

StartCallback(i) ==
    /\ i \in callbacks
    /\ ~callbackLock
    /\ callbacks' = callbacks \ {i}
    /\ callbackLock' = TRUE
    /\ callbackTarget' = i
    /\ UNCHANGED <<outer, inner, result, ready, attempts, joinResult>>

RunCallback ==
    /\ callbackLock
    /\ callbackLock' = FALSE
    /\ callbackTarget' = "none"
    /\ IF \A i \in INNER : inner[i] \in {"succeeded", "failed"}
          THEN IF USE_FIXED
                  THEN IF inner["memo_failure"] = "failed"
                          THEN /\ outer' = "failed"
                               /\ joinResult' = <<>>
                          ELSE /\ outer' = "succeeded"
                               /\ joinResult' = <<result["memo_failure"],
                                                   result["file_success"]>>
                  ELSE /\ outer' = "succeeded"
                       /\ joinResult' = <<result["memo_failure"],
                                           result["file_success"]>>
          ELSE /\ UNCHANGED <<outer, joinResult>>
    /\ UNCHANGED <<inner, result, ready, attempts, callbacks>>

Next ==
    \/ StartJoin
    \/ MemoizedFailure
    \/ BeginStageIn
    \/ FinishStageIn
    \/ \E i \in INNER : StartCallback(i)
    \/ RunCallback
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ outer \in OuterStates
    /\ inner \in [INNER -> InnerStates]
    /\ result \in [INNER -> STRING]
    /\ ready \in [INNER -> BOOLEAN]
    /\ attempts \in [INNER -> 0..1]
    /\ callbacks \subseteq INNER
    /\ callbackLock \in BOOLEAN
    /\ callbackTarget \in INNER \cup {"none"}
    /\ joinResult \in Seq(STRING)

MemoHitNoAttempt == attempts["memo_failure"] = 0

DataReadiness == inner["file_success"] = "succeeded" => ready["file_success"]

JoinTerminality ==
    outer = "failed" => inner["memo_failure"] = "failed"

MemoFailurePropagation ==
    outer = "succeeded" => inner["memo_failure"] # "failed"

JoinResultSafety ==
    outer = "succeeded" =>
        /\ \A i \in INNER : inner[i] = "succeeded"
        /\ Len(joinResult) = 2

=============================================================================
