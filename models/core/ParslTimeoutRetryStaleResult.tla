------------------- MODULE ParslTimeoutRetryStaleResult -------------------
EXTENDS Naturals

(***************************************************************************
 * Timeout, retry, and late-result correlation.
 *
 * A wall-clock timeout loses attempt 0 and starts attempt 1.  A result from
 * the timed-out attempt can still arrive after the retry.  The fixed branch
 * classifies that frame as stale and leaves the logical Future unresolved.
 ***************************************************************************)

CONSTANT USE_FIXED
TIMEOUT == 2

VARIABLES attempt, age, physical, future, lateDelivered, staleClassified
vars == <<attempt, age, physical, future, lateDelivered, staleClassified>>

Init ==
    /\ attempt = 0
    /\ age = 0
    /\ physical = "running"
    /\ future = "unresolved"
    /\ lateDelivered = FALSE
    /\ staleClassified = FALSE

Tick ==
    /\ physical = "running"
    /\ age < TIMEOUT
    /\ age' = age + 1
    /\ UNCHANGED <<attempt, physical, future, lateDelivered, staleClassified>>

Timeout ==
    /\ physical = "running"
    /\ age = TIMEOUT
    /\ attempt = 0
    /\ attempt' = 1
    /\ age' = 0
    /\ physical' = "running"
    /\ UNCHANGED <<future, lateDelivered, staleClassified>>

LateResult ==
    /\ attempt = 1
    /\ physical = "running"
    /\ lateDelivered' = TRUE
    /\ IF USE_FIXED
          THEN /\ future' = future
               /\ staleClassified' = TRUE
          ELSE /\ future' = "resolved"
               /\ staleClassified' = FALSE
    /\ UNCHANGED <<attempt, age, physical>>

CompleteCurrent ==
    /\ attempt = 1
    /\ physical = "running"
    /\ physical' = "succeeded"
    /\ future' = "resolved"
    /\ UNCHANGED <<attempt, age, lateDelivered, staleClassified>>

Next ==
    \/ Tick
    \/ Timeout
    \/ LateResult
    \/ CompleteCurrent
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ attempt \in 0..1
    /\ age \in 0..TIMEOUT
    /\ physical \in {"running", "succeeded"}
    /\ future \in {"unresolved", "resolved"}
    /\ lateDelivered \in BOOLEAN
    /\ staleClassified \in BOOLEAN

RetryBoundSafety == attempt <= 1

StaleResultSafety ==
    lateDelivered => staleClassified \/ future = "unresolved"

TerminalSafety ==
    future = "resolved" => physical = "succeeded" \/ lateDelivered

=============================================================================
CONSTANT USE_FIXED = TRUE

SPECIFICATION Spec

INVARIANTS
    TypeOK
    RetryBoundSafety
    StaleResultSafety
    TerminalSafety
