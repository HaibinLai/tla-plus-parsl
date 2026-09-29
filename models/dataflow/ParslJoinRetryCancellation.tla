--------------------------- MODULE ParslJoinRetryCancellation ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * join_app retry followed by cancellation.
 *
 * One inner Future fails a non-final physical attempt, enters retry_wait, and
 * is then cancelled.  The other inner Future succeeds.  The current callback
 * lets CancelledError escape and leaves the outer join in joining; the fixed
 * branch records cancellation as terminal inner failure and finalizes the
 * outer join as failed.
 ***************************************************************************)

CONSTANT MAX_RETRIES, USE_FIXED
INNER == {"I1", "I2"}

OuterStates == {"new", "joining", "succeeded", "failed"}
InnerStates == {"unresolved", "retry_wait", "running", "succeeded", "failed", "cancelled"}
AttemptStates == {"absent", "running", "failed", "succeeded"}

VARIABLES outer, inner, currentAttempt, attemptState, observed,
          callbackRaised, failure
vars == <<outer, inner, currentAttempt, attemptState, observed,
           callbackRaised, failure>>

AllTerminal == \A i \in INNER : inner[i] \in {"succeeded", "failed", "cancelled"}

Init ==
    /\ MAX_RETRIES >= 1
    /\ USE_FIXED \in BOOLEAN
    /\ outer = "new"
    /\ inner = [i \in INNER |-> "unresolved"]
    /\ currentAttempt = [i \in INNER |-> 0]
    /\ attemptState = [i \in INNER |->
          [k \in 0..MAX_RETRIES |-> "absent"]]
    /\ observed = {}
    /\ callbackRaised = FALSE
    /\ failure = FALSE

StartJoin ==
    /\ outer = "new"
    /\ outer' = "joining"
    /\ UNCHANGED <<inner, currentAttempt, attemptState, observed,
                    callbackRaised, failure>>

StartAttempt(i) ==
    /\ i \in INNER
    /\ outer = "joining"
    /\ inner[i] \in {"unresolved", "retry_wait"}
    /\ attemptState[i][currentAttempt[i]] = "absent"
    /\ attemptState' = [attemptState EXCEPT
          ![i][currentAttempt[i]] = "running"]
    /\ inner' = [inner EXCEPT ![i] = "running"]
    /\ UNCHANGED <<outer, currentAttempt, observed, callbackRaised, failure>>

FailAttempt(i) ==
    /\ i \in INNER
    /\ inner[i] = "running"
    /\ attemptState[i][currentAttempt[i]] = "running"
    /\ attemptState' = [attemptState EXCEPT
          ![i][currentAttempt[i]] = "failed"]
    /\ inner' = [inner EXCEPT ![i] =
          IF currentAttempt[i] = MAX_RETRIES THEN "failed" ELSE "retry_wait"]
    /\ failure' = IF currentAttempt[i] = MAX_RETRIES THEN TRUE ELSE failure
    /\ UNCHANGED <<outer, currentAttempt, observed, callbackRaised>>

RetryAttempt(i) ==
    /\ i \in INNER
    /\ inner[i] = "retry_wait"
    /\ currentAttempt[i] < MAX_RETRIES
    /\ currentAttempt' = [currentAttempt EXCEPT ![i] = @ + 1]
    /\ inner' = [inner EXCEPT ![i] = "unresolved"]
    /\ UNCHANGED <<outer, attemptState, observed, callbackRaised, failure>>

CancelInner(i) ==
    /\ i \in INNER
    /\ inner[i] \in {"unresolved", "retry_wait", "running"}
    /\ inner' = [inner EXCEPT ![i] = "cancelled"]
    /\ UNCHANGED <<outer, currentAttempt, attemptState, observed,
                    callbackRaised, failure>>

CompleteInner(i) ==
    /\ i \in INNER
    /\ inner[i] = "running"
    /\ attemptState[i][currentAttempt[i]] = "running"
    /\ attemptState' = [attemptState EXCEPT
          ![i][currentAttempt[i]] = "succeeded"]
    /\ inner' = [inner EXCEPT ![i] = "succeeded"]
    /\ UNCHANGED <<outer, currentAttempt, observed, callbackRaised, failure>>

Observe(i) ==
    /\ outer = "joining"
    /\ i \in INNER
    /\ inner[i] \in {"succeeded", "failed", "cancelled"}
    /\ i \notin observed
    /\ IF inner[i] = "cancelled" /\ ~USE_FIXED
       THEN /\ observed' = observed
            /\ callbackRaised' = TRUE
            /\ UNCHANGED outer
       ELSE /\ observed' = observed \cup {i}
            /\ callbackRaised' = callbackRaised
            /\ outer' = IF USE_FIXED /\ inner[i] = "cancelled"
                        THEN IF AllTerminal /\ observed \cup {i} = INNER
                             THEN "failed" ELSE "joining"
                        ELSE outer
    /\ UNCHANGED <<inner, currentAttempt, attemptState, failure>>

Finalize ==
    /\ outer = "joining"
    /\ observed = INNER
    /\ AllTerminal
    /\ outer' = IF failure \/ \E i \in INNER : inner[i] = "cancelled"
                THEN "failed" ELSE "succeeded"
    /\ UNCHANGED <<inner, currentAttempt, attemptState, observed,
                    callbackRaised, failure>>

Next ==
    \/ StartJoin
    \/ \E i \in INNER : StartAttempt(i) \/ FailAttempt(i) \/ RetryAttempt(i)
    \/ \E i \in INNER : CancelInner(i) \/ CompleteInner(i) \/ Observe(i)
    \/ Finalize
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ outer \in OuterStates
    /\ inner \in [INNER -> InnerStates]
    /\ currentAttempt \in [INNER -> 0..MAX_RETRIES]
    /\ attemptState \in [INNER -> [0..MAX_RETRIES -> AttemptStates]]
    /\ observed \subseteq INNER
    /\ callbackRaised \in BOOLEAN
    /\ failure \in BOOLEAN

RetryBound == \A i \in INNER : currentAttempt[i] <= MAX_RETRIES

CancellationSafety ==
    /\ outer = "failed" => \E i \in INNER : inner[i] \in {"failed", "cancelled"}
    /\ callbackRaised /\ ~USE_FIXED => outer = "joining"

NoUnexpectedCallback ==
    ~callbackRaised

JoinTerminalSafety ==
    outer \in {"succeeded", "failed"} => observed = INNER

=============================================================================
