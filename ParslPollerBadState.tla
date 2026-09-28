--------------------------- MODULE ParslPollerBadState ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * JobStatusPoller ordering and executor bad-state handling.
 *
 * A poll updates block status, the error handler counts FAILED/MISSING jobs,
 * and strategy scaling runs only while the executor is healthy.  Reaching
 * the all-initial-block failure threshold fails outstanding tasks and blocks
 * future admission/scaling.
 ***************************************************************************)

BLOCKS == {"B1", "B2", "B3"}
INIT_BLOCKS == 2
MIN_BLOCKS == 0
MAX_BLOCKS == 3
MAX_TASKS == 2
MAX_SCALE_EVENTS == 4
FAILURE_THRESHOLD == 2
BlockStatuses == {"absent", "pending", "running", "failed", "missing",
                  "completed", "scaled_in"}

VARIABLES blockStatus, badState, outstanding, failedTasks, scaleOutCount,
          scaleCountAtBad
vars == <<blockStatus, badState, outstanding, failedTasks, scaleOutCount,
           scaleCountAtBad>>

Init ==
    /\ blockStatus = [b \in BLOCKS |-> IF b = "B3" THEN "absent" ELSE "pending"]
    /\ badState = FALSE
    /\ outstanding = 0
    /\ failedTasks = 0
    /\ scaleOutCount = 0
    /\ scaleCountAtBad = 0

ProviderStarts(b) ==
    /\ b \in BLOCKS
    /\ blockStatus[b] = "pending"
    /\ blockStatus' = [blockStatus EXCEPT ![b] = "running"]
    /\ UNCHANGED <<badState, outstanding, failedTasks, scaleOutCount,
                   scaleCountAtBad>>

PollStatus(b, s) ==
    /\ b \in BLOCKS
    /\ blockStatus[b] \in {"pending", "running"}
    /\ s \in {"pending", "running", "failed", "missing", "completed"}
    /\ blockStatus' = [blockStatus EXCEPT ![b] = s]
    /\ UNCHANGED <<badState, outstanding, failedTasks, scaleOutCount,
                   scaleCountAtBad>>

SubmitTask ==
    /\ ~badState
    /\ outstanding < MAX_TASKS
    /\ outstanding' = outstanding + 1
    /\ UNCHANGED <<blockStatus, badState, failedTasks, scaleOutCount,
                   scaleCountAtBad>>

CompleteTask ==
    /\ outstanding > 0
    /\ outstanding' = outstanding - 1
    /\ UNCHANGED <<blockStatus, badState, failedTasks, scaleOutCount,
                   scaleCountAtBad>>

HandleErrors ==
    /\ ~badState
    /\ Cardinality({b \in BLOCKS :
          blockStatus[b] \in {"failed", "missing"}}) >= FAILURE_THRESHOLD
    /\ badState' = TRUE
    /\ failedTasks' = failedTasks + outstanding
    /\ outstanding' = 0
    /\ scaleCountAtBad' = scaleOutCount
    /\ UNCHANGED <<blockStatus, scaleOutCount>>

ScaleOut ==
    /\ ~badState
    /\ scaleOutCount < MAX_SCALE_EVENTS
    /\ outstanding > Cardinality({b \in BLOCKS : blockStatus[b] = "running"})
    /\ Cardinality({b \in BLOCKS : blockStatus[b] \in {"pending", "running"}}) < MAX_BLOCKS
    /\ \E b \in BLOCKS : blockStatus[b] = "absent"
    /\ \E b \in BLOCKS :
          /\ blockStatus[b] = "absent"
          /\ blockStatus' = [blockStatus EXCEPT ![b] = "pending"]
    /\ scaleOutCount' = scaleOutCount + 1
    /\ UNCHANGED <<badState, outstanding, failedTasks, scaleCountAtBad>>

ScaleIn ==
    /\ ~badState
    /\ outstanding = 0
    /\ Cardinality({b \in BLOCKS : blockStatus[b] = "running"}) > MIN_BLOCKS
    /\ \E b \in BLOCKS : blockStatus[b] = "running"
    /\ \E b \in BLOCKS :
          /\ blockStatus[b] = "running"
          /\ blockStatus' = [blockStatus EXCEPT ![b] = "scaled_in"]
    /\ UNCHANGED <<badState, outstanding, failedTasks, scaleOutCount,
                   scaleCountAtBad>>

Next ==
    \/ \E b \in BLOCKS : ProviderStarts(b)
    \/ \E b \in BLOCKS, s \in {"pending", "running", "failed", "missing", "completed"} :
          PollStatus(b, s)
    \/ SubmitTask
    \/ CompleteTask
    \/ HandleErrors
    \/ ScaleOut
    \/ ScaleIn
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ blockStatus \in [BLOCKS -> BlockStatuses]
    /\ badState \in BOOLEAN
    /\ outstanding \in 0..MAX_TASKS
    /\ failedTasks \in 0..MAX_TASKS
    /\ scaleOutCount \in 0..MAX_SCALE_EVENTS
    /\ scaleCountAtBad \in 0..MAX_SCALE_EVENTS

BadStateAdmissionSafety ==
    badState => outstanding = 0

FailureThresholdSafety ==
    badState => Cardinality({b \in BLOCKS :
        blockStatus[b] \in {"failed", "missing"}}) >= FAILURE_THRESHOLD

NoScaleAfterBadState ==
    badState => scaleOutCount = scaleCountAtBad

CapacitySafety ==
    Cardinality({b \in BLOCKS : blockStatus[b] = "running"}) <= MAX_BLOCKS

=============================================================================
