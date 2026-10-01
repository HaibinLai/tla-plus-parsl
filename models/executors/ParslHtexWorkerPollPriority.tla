--------------------------- MODULE ParslHtexWorkerPollPriority ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX worker communicator multiplexing.
 *
 * process_worker_pool.Manager.interchange_communicator checks the interchange
 * socket before the results socket when both are readable.  A continuously
 * readable task socket can therefore postpone result forwarding.  The fixed
 * branch services a ready result before accepting another task.
 ***************************************************************************)

CONSTANTS MAX_STEPS, USE_FIXED

VARIABLES steps, taskReady, resultReady, resultServed
vars == <<steps, taskReady, resultReady, resultServed>>

Init ==
    /\ MAX_STEPS > 0
    /\ USE_FIXED \in BOOLEAN
    /\ steps = 0
    /\ taskReady = TRUE
    /\ resultReady = TRUE
    /\ resultServed = FALSE

PollBoth ==
    /\ taskReady
    /\ resultReady
    /\ steps < MAX_STEPS
    /\ steps' = steps + 1
    /\ IF USE_FIXED
          THEN /\ taskReady' = TRUE
               /\ resultReady' = FALSE
               /\ resultServed' = TRUE
          ELSE /\ taskReady' = TRUE
               /\ resultReady' = TRUE
               /\ resultServed' = resultServed

PollTaskOnly ==
    /\ taskReady
    /\ ~resultReady
    /\ steps < MAX_STEPS
    /\ steps' = steps + 1
    /\ UNCHANGED <<taskReady, resultReady, resultServed>>

PollResultOnly ==
    /\ ~taskReady
    /\ resultReady
    /\ steps < MAX_STEPS
    /\ steps' = steps + 1
    /\ resultReady' = FALSE
    /\ resultServed' = TRUE
    /\ UNCHANGED taskReady

Next ==
    \/ PollBoth
    \/ PollTaskOnly
    \/ PollResultOnly
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ MAX_STEPS > 0
    /\ USE_FIXED \in BOOLEAN
    /\ steps \in 0..MAX_STEPS
    /\ taskReady \in BOOLEAN
    /\ resultReady \in BOOLEAN
    /\ resultServed \in BOOLEAN

BoundedResultService ==
    steps = MAX_STEPS => resultServed

=============================================================================
