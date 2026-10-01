--------------------------- MODULE ParslZMQResultAttempt ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Result-side multipart delivery for two physical attempts.
 *
 * Attempt 0 may be lost and replaced by attempt 1.  Either attempt can later
 * publish a serialized result, and the result can be duplicated or malformed.
 * The Fixed branch resolves only the current attempt, rejects malformed data,
 * and consumes duplicate valid results at most once.
 ***************************************************************************)

CONSTANTS USE_FIXED, BAD_RESULT

AttemptStates == {"pending", "running", "lost", "done"}
WireStates == {"none", "queued", "decoded", "rejected", "stale", "resolved"}

VARIABLES currentAttempt, attempt0, attempt1, resultAttempt, resultWire,
          resultValid, duplicate, seen, resolveCount, task, future

vars == <<currentAttempt, attempt0, attempt1, resultAttempt, resultWire,
           resultValid, duplicate, seen, resolveCount, task, future>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ BAD_RESULT \in BOOLEAN
    /\ currentAttempt = 0
    /\ attempt0 = "running"
    /\ attempt1 = "pending"
    /\ resultAttempt = 0
    /\ resultWire = "none"
    /\ resultValid = ~BAD_RESULT
    /\ duplicate = FALSE
    /\ seen = FALSE
    /\ resolveCount = 0
    /\ task = "running"
    /\ future = "unresolved"

LoseAttempt0 ==
    /\ currentAttempt = 0
    /\ attempt0 = "running"
    /\ attempt0' = "lost"
    /\ attempt1' = "running"
    /\ currentAttempt' = 1
    /\ UNCHANGED <<resultAttempt, resultWire, resultValid, duplicate, seen,
                    resolveCount, task, future>>

CompleteAttempt0 ==
    /\ currentAttempt = 0
    /\ attempt0 = "running"
    /\ attempt0' = "done"
    /\ UNCHANGED <<currentAttempt, attempt1, resultAttempt, resultWire,
                    resultValid, duplicate, seen, resolveCount, task, future>>

CompleteAttempt1 ==
    /\ currentAttempt = 1
    /\ attempt1 = "running"
    /\ attempt1' = "done"
    /\ UNCHANGED <<currentAttempt, attempt0, resultAttempt, resultWire,
                    resultValid, duplicate, seen, resolveCount, task, future>>

CompleteLateAttempt0 ==
    /\ currentAttempt = 1
    /\ attempt0 = "lost"
    /\ attempt0' = "done"
    /\ resultAttempt' = 0
    /\ resultWire' = "none"
    /\ UNCHANGED <<currentAttempt, attempt1, resultValid, duplicate, seen,
                    resolveCount, task, future>>

PublishResult ==
    /\ resultWire = "none"
    /\ (resultAttempt = 0 => attempt0 = "done")
    /\ (resultAttempt = 1 => attempt1 = "done")
    /\ resultWire' = "queued"
    /\ UNCHANGED <<currentAttempt, attempt0, attempt1, resultAttempt,
                    resultValid, duplicate, seen, resolveCount, task, future>>

DeliverValidResult ==
    /\ resultWire = "queued"
    /\ resultValid
    /\ resultWire' = "decoded"
    /\ UNCHANGED <<currentAttempt, attempt0, attempt1, resultAttempt,
                    resultValid, duplicate, seen, resolveCount, task, future>>

DeliverMalformedFixed ==
    /\ resultWire = "queued"
    /\ ~resultValid
    /\ USE_FIXED
    /\ resultWire' = "rejected"
    /\ UNCHANGED <<currentAttempt, attempt0, attempt1, resultAttempt,
                    resultValid, duplicate, seen, resolveCount, task, future>>

DeliverMalformedCurrent ==
    /\ resultWire = "queued"
    /\ ~resultValid
    /\ ~USE_FIXED
    /\ resultWire' = "decoded"
    /\ UNCHANGED <<currentAttempt, attempt0, attempt1, resultAttempt,
                    resultValid, duplicate, seen, resolveCount, task, future>>

DuplicateResult ==
    /\ resultWire = "decoded"
    /\ ~duplicate
    /\ duplicate' = TRUE
    /\ UNCHANGED <<currentAttempt, attempt0, attempt1, resultAttempt,
                    resultWire, resultValid, seen, resolveCount, task, future>>

ResolveCurrentFixed ==
    /\ resultWire = "decoded"
    /\ ~seen
    /\ USE_FIXED
    /\ resultValid
    /\ resultAttempt = currentAttempt
    /\ seen' = TRUE
    /\ resolveCount' = resolveCount + 1
    /\ resultWire' = "resolved"
    /\ future' = "resolved"
    /\ task' = "done"
    /\ UNCHANGED <<currentAttempt, attempt0, attempt1, resultAttempt,
                    resultValid, duplicate>>

ResolveStaleFixed ==
    /\ resultWire = "decoded"
    /\ ~seen
    /\ USE_FIXED
    /\ resultValid
    /\ resultAttempt # currentAttempt
    /\ seen' = TRUE
    /\ resultWire' = "stale"
    /\ UNCHANGED <<currentAttempt, attempt0, attempt1, resultAttempt,
                    resultValid, duplicate, resolveCount, task, future>>

ResolveCurrentBranch ==
    /\ resultWire = "decoded"
    /\ ~seen
    /\ ~USE_FIXED
    /\ seen' = TRUE
    /\ resolveCount' = resolveCount + 1
    /\ resultWire' = "resolved"
    /\ future' = "resolved"
    /\ task' = "done"
    /\ UNCHANGED <<currentAttempt, attempt0, attempt1, resultAttempt,
                    resultValid, duplicate>>

ResolveDuplicate ==
    /\ resultWire = "resolved" \/ resultWire = "stale"
    /\ duplicate
    /\ resultWire' = IF USE_FIXED THEN resultWire ELSE "resolved"
    /\ resolveCount' = IF USE_FIXED THEN resolveCount ELSE resolveCount + 1
    /\ UNCHANGED <<currentAttempt, attempt0, attempt1, resultAttempt,
                    resultValid, duplicate, seen, task, future>>

Next ==
    \/ LoseAttempt0
    \/ CompleteAttempt0
    \/ CompleteAttempt1
    \/ CompleteLateAttempt0
    \/ PublishResult
    \/ DeliverValidResult
    \/ DeliverMalformedFixed
    \/ DeliverMalformedCurrent
    \/ DuplicateResult
    \/ ResolveCurrentFixed
    \/ ResolveStaleFixed
    \/ ResolveCurrentBranch
    \/ ResolveDuplicate
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ currentAttempt \in 0..1
    /\ attempt0 \in AttemptStates
    /\ attempt1 \in AttemptStates
    /\ resultAttempt \in 0..1
    /\ resultWire \in WireStates
    /\ resultValid \in BOOLEAN
    /\ duplicate \in BOOLEAN
    /\ seen \in BOOLEAN
    /\ resolveCount \in 0..2
    /\ task \in {"running", "done"}
    /\ future \in {"unresolved", "resolved"}

CurrentAttemptSafety ==
    future = "resolved" => resultAttempt = currentAttempt
StaleResultSafety ==
    resultWire = "stale" => resultAttempt # currentAttempt
MalformedSafety == BAD_RESULT => resultWire # "resolved"
AtMostOnce == resolveCount <= 1
FutureConsistency == future = "resolved" => task = "done"

=============================================================================
