--------------------------- MODULE ParslHtexPollPriorityFutureTimeout ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Cross-layer HTEX worker poll model.
 *
 * A worker multiplexes a task socket and a result socket.  If both remain
 * readable, the current task-first policy can postpone a ready result until
 * the logical Future deadline.  The fixed branch services the result first.
 ***************************************************************************)

CONSTANTS MAX_POLLS, RESULT_DEADLINE, USE_FIXED

FutureStates == {"pending", "timed_out", "succeeded"}
MonitorStates == {"none", "timed_out", "succeeded"}

VARIABLES polls, taskReady, resultReady, resultServed, future, monitor
vars == <<polls, taskReady, resultReady, resultServed, future, monitor>>

Init ==
    /\ MAX_POLLS > 0
    /\ RESULT_DEADLINE > 0
    /\ RESULT_DEADLINE <= MAX_POLLS
    /\ USE_FIXED \in BOOLEAN
    /\ polls = 0
    /\ taskReady = TRUE
    /\ resultReady = TRUE
    /\ resultServed = FALSE
    /\ future = "pending"
    /\ monitor = "none"

PollBoth ==
    /\ taskReady /\ resultReady /\ polls < MAX_POLLS
    /\ polls' = polls + 1
    /\ IF USE_FIXED
          THEN /\ resultServed' = TRUE
               /\ resultReady' = FALSE
               /\ taskReady' = TRUE
          ELSE /\ UNCHANGED <<resultServed, resultReady, taskReady>>
    /\ UNCHANGED <<future, monitor>>

PollTaskOnly ==
    /\ taskReady /\ ~resultReady /\ polls < MAX_POLLS
    /\ polls' = polls + 1
    /\ UNCHANGED <<taskReady, resultReady, resultServed, future, monitor>>

PollResultOnly ==
    /\ ~taskReady /\ resultReady /\ polls < MAX_POLLS
    /\ polls' = polls + 1
    /\ resultReady' = FALSE
    /\ resultServed' = TRUE
    /\ UNCHANGED <<taskReady, future, monitor>>

PublishResult ==
    /\ resultServed /\ future = "pending"
    /\ future' = "succeeded"
    /\ monitor' = "succeeded"
    /\ UNCHANGED <<polls, taskReady, resultReady, resultServed>>

Timeout ==
    /\ polls >= RESULT_DEADLINE
    /\ ~resultServed
    /\ future = "pending"
    /\ future' = "timed_out"
    /\ monitor' = "timed_out"
    /\ UNCHANGED <<polls, taskReady, resultReady, resultServed>>

Next ==
    \/ PollBoth
    \/ PollTaskOnly
    \/ PollResultOnly
    \/ PublishResult
    \/ Timeout
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ MAX_POLLS > 0
    /\ RESULT_DEADLINE > 0
    /\ RESULT_DEADLINE <= MAX_POLLS
    /\ USE_FIXED \in BOOLEAN
    /\ polls \in 0..MAX_POLLS
    /\ taskReady \in BOOLEAN
    /\ resultReady \in BOOLEAN
    /\ resultServed \in BOOLEAN
    /\ future \in FutureStates
    /\ monitor \in MonitorStates

TerminalConsistency ==
    /\ future = "succeeded" => /\ resultServed /\ monitor = "succeeded"
    /\ future = "timed_out" => /\ ~resultServed /\ monitor = "timed_out"

FixedResultBound ==
    USE_FIXED => (polls >= 1 => resultServed \/ future = "timed_out")

=============================================================================
