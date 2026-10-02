--------------------------- MODULE ParslLSFMissingJobFutureMonitoring ---------------------------
EXTENDS Naturals

(***************************************************************************
 * LSF missing-job polling composed with the logical task Future.  LSF omits
 * jobs that disappear from bjobs; treating that omission as COMPLETED can
 * publish a successful Future and monitoring row before an explicit terminal
 * observation arrives.
 ***************************************************************************)

CONSTANT USE_FIXED

PollStates == {"waiting", "complete"}
JobStates == {"running", "completed", "failed", "unknown"}
FutureStates == {"pending", "succeeded", "failed"}
MonitorStates == {"none", "succeeded", "failed"}

VARIABLES pollState, jobState, future, monitor, missingSeen
vars == <<pollState, jobState, future, monitor, missingSeen>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ pollState = "waiting"
    /\ jobState = "running"
    /\ future = "pending"
    /\ monitor = "none"
    /\ missingSeen = FALSE

MissingJob ==
    /\ pollState = "waiting"
    /\ pollState' = "complete"
    /\ missingSeen' = TRUE
    /\ IF USE_FIXED
          THEN /\ jobState' = "unknown"
               /\ UNCHANGED <<future, monitor>>
          ELSE /\ jobState' = "completed"
               /\ future' = "succeeded"
               /\ monitor' = "succeeded"

KnownFailure ==
    /\ pollState = "complete"
    /\ jobState = "unknown"
    /\ jobState' = "failed"
    /\ future' = "failed"
    /\ monitor' = "failed"
    /\ UNCHANGED <<pollState, missingSeen>>

Next ==
    \/ MissingJob
    \/ KnownFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ pollState \in PollStates
    /\ jobState \in JobStates
    /\ future \in FutureStates
    /\ monitor \in MonitorStates
    /\ missingSeen \in BOOLEAN

MissingJobSafety == missingSeen => jobState # "completed"

SuccessPropagation ==
    future = "succeeded" =>
        /\ jobState = "completed"
        /\ monitor = "succeeded"

FailurePropagation ==
    future = "failed" => jobState = "failed" /\ monitor = "failed"

=============================================================================
