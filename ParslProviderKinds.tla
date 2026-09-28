--------------------------- MODULE ParslProviderKinds ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Concrete provider API/status abstraction.
 *
 * The model keeps the provider API boundary small but explicit: submit
 * creates a pending job, status maps backend states to Parsl JobState values,
 * and cancel returns a per-job success value.  Cluster providers model the
 * squeue/sacct convention that a missing job is treated as completed, while
 * Kubernetes maps an unknown pod observation to UNKNOWN.
 ***************************************************************************)

CONSTANTS PROVIDERS, CLUSTER_PROVIDERS, KUBERNETES_PROVIDERS,
          MAX_FAILURES, CORES_PER_NODE, TASKS_PER_NODE

ProviderStates == {"ready", "failed"}
RawStates == {"PENDING", "RUNNING", "COMPLETED", "FAILED",
              "CANCELLED", "TIMEOUT", "SUSPENDED", "REQUEUED", "UNKNOWN"}
JobStates == {"DOWN", "PENDING", "RUNNING", "COMPLETED", "FAILED",
              "CANCELLED", "TIMEOUT", "HELD", "UNKNOWN", "MISSING",
              "SCALED_IN"}
TerminalStates == {"COMPLETED", "FAILED", "CANCELLED", "TIMEOUT", "MISSING",
                   "SCALED_IN"}

Translate(p, raw) ==
    IF raw = "PENDING" THEN "PENDING"
    ELSE IF raw = "RUNNING" THEN "RUNNING"
    ELSE IF raw = "COMPLETED" THEN "COMPLETED"
    ELSE IF raw = "CANCELLED" THEN "CANCELLED"
    ELSE IF raw = "TIMEOUT" THEN "TIMEOUT"
    ELSE IF raw = "SUSPENDED" THEN "HELD"
    ELSE IF raw = "REQUEUED" THEN "PENDING"
    ELSE IF raw = "FAILED" THEN "FAILED"
    ELSE "UNKNOWN"

MissingTranslation(p) ==
    IF p \in CLUSTER_PROVIDERS THEN "COMPLETED" ELSE "UNKNOWN"

VARIABLES providerState, jobState, rawState, observed,
          statusFailures, submitRejected, cancelResult, cpusPerTask
vars == <<providerState, jobState, rawState, observed,
          statusFailures, submitRejected, cancelResult, cpusPerTask>>

Init ==
    /\ PROVIDERS # {}
    /\ CLUSTER_PROVIDERS \cup KUBERNETES_PROVIDERS = PROVIDERS
    /\ CLUSTER_PROVIDERS \cap KUBERNETES_PROVIDERS = {}
    /\ MAX_FAILURES > 0
    /\ CORES_PER_NODE > 0
    /\ TASKS_PER_NODE > 0
    /\ providerState = [p \in PROVIDERS |-> "ready"]
    /\ jobState = [p \in PROVIDERS |-> "DOWN"]
    /\ rawState = [p \in PROVIDERS |-> "UNKNOWN"]
    /\ observed = [p \in PROVIDERS |-> FALSE]
    /\ statusFailures = [p \in PROVIDERS |-> 0]
    /\ submitRejected = [p \in PROVIDERS |-> 0]
    /\ cancelResult = [p \in PROVIDERS |-> "none"]
    /\ cpusPerTask = CORES_PER_NODE \div TASKS_PER_NODE

Submit(p) ==
    /\ providerState[p] = "ready"
    /\ jobState[p] = "DOWN"
    /\ TASKS_PER_NODE <= CORES_PER_NODE
    /\ jobState' = [jobState EXCEPT ![p] = "PENDING"]
    /\ rawState' = [rawState EXCEPT ![p] = "PENDING"]
    /\ observed' = [observed EXCEPT ![p] = TRUE]
    /\ cancelResult' = [cancelResult EXCEPT ![p] = "none"]
    /\ UNCHANGED <<providerState, statusFailures, submitRejected, cpusPerTask>>

RejectSubmit(p) ==
    /\ providerState[p] = "failed"
        \/ TASKS_PER_NODE > CORES_PER_NODE
    /\ submitRejected[p] < MAX_FAILURES
    /\ submitRejected' = [submitRejected EXCEPT ![p] = @ + 1]
    /\ UNCHANGED <<providerState, jobState, rawState, observed,
                    statusFailures, cancelResult, cpusPerTask>>

StatusSuccess(p, raw) ==
    /\ providerState[p] = "ready"
    /\ jobState[p] \notin TerminalStates
    /\ raw \in RawStates
    /\ rawState' = [rawState EXCEPT ![p] = raw]
    /\ jobState' = [jobState EXCEPT ![p] = Translate(p, raw)]
    /\ observed' = [observed EXCEPT ![p] = TRUE]
    /\ UNCHANGED <<providerState, statusFailures, submitRejected,
                    cancelResult, cpusPerTask>>

StatusFailure(p) ==
    /\ providerState[p] = "ready"
    /\ jobState[p] \notin TerminalStates
    /\ statusFailures[p] < MAX_FAILURES
    /\ statusFailures' = [statusFailures EXCEPT ![p] = @ + 1]
    /\ UNCHANGED <<providerState, jobState, rawState, observed,
                    submitRejected, cancelResult, cpusPerTask>>

ObserveMissing(p) ==
    /\ providerState[p] = "ready"
    /\ jobState[p] \notin TerminalStates
    /\ observed' = [observed EXCEPT ![p] = FALSE]
    /\ rawState' = [rawState EXCEPT ![p] = "UNKNOWN"]
    /\ jobState' = [jobState EXCEPT ![p] = MissingTranslation(p)]
    /\ UNCHANGED <<providerState, statusFailures, submitRejected,
                    cancelResult, cpusPerTask>>

CancelSuccess(p) ==
    /\ providerState[p] = "ready"
    /\ jobState[p] \notin TerminalStates
    /\ jobState' = [jobState EXCEPT ![p] = "CANCELLED"]
    /\ rawState' = [rawState EXCEPT ![p] = "CANCELLED"]
    /\ cancelResult' = [cancelResult EXCEPT ![p] = "true"]
    /\ UNCHANGED <<providerState, observed, statusFailures,
                    submitRejected, cpusPerTask>>

CancelFailure(p) ==
    /\ providerState[p] = "ready"
    /\ jobState[p] \notin TerminalStates
    /\ cancelResult' = [cancelResult EXCEPT ![p] = "false"]
    /\ UNCHANGED <<providerState, jobState, rawState, observed,
                    statusFailures, submitRejected, cpusPerTask>>

ScaleIn(p) ==
    /\ providerState[p] = "ready"
    /\ jobState[p] \notin TerminalStates
    /\ jobState' = [jobState EXCEPT ![p] = "SCALED_IN"]
    /\ rawState' = [rawState EXCEPT ![p] = "UNKNOWN"]
    /\ observed' = [observed EXCEPT ![p] = FALSE]
    /\ cancelResult' = [cancelResult EXCEPT ![p] = "none"]
    /\ UNCHANGED <<providerState, statusFailures, submitRejected,
                    cpusPerTask>>

FailProvider(p) ==
    /\ providerState[p] = "ready"
    /\ providerState' = [providerState EXCEPT ![p] = "failed"]
    /\ UNCHANGED <<jobState, rawState, observed, statusFailures,
                    submitRejected, cancelResult, cpusPerTask>>

RecoverProvider(p) ==
    /\ providerState[p] = "failed"
    /\ providerState' = [providerState EXCEPT ![p] = "ready"]
    /\ UNCHANGED <<jobState, rawState, observed, statusFailures,
                    submitRejected, cancelResult, cpusPerTask>>

Next ==
    \/ \E p \in PROVIDERS : Submit(p) \/ RejectSubmit(p)
    \/ \E p \in PROVIDERS, raw \in RawStates : StatusSuccess(p, raw)
    \/ \E p \in PROVIDERS : StatusFailure(p) \/ ObserveMissing(p)
    \/ \E p \in PROVIDERS : CancelSuccess(p) \/ CancelFailure(p)
    \/ \E p \in PROVIDERS : ScaleIn(p)
    \/ \E p \in PROVIDERS : FailProvider(p) \/ RecoverProvider(p)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ providerState \in [PROVIDERS -> ProviderStates]
    /\ jobState \in [PROVIDERS -> JobStates]
    /\ rawState \in [PROVIDERS -> (RawStates \cup {"UNKNOWN"})]
    /\ observed \in [PROVIDERS -> BOOLEAN]
    /\ statusFailures \in [PROVIDERS -> 0..MAX_FAILURES]
    /\ submitRejected \in [PROVIDERS -> 0..MAX_FAILURES]
    /\ cancelResult \in [PROVIDERS -> {"none", "true", "false"}]
    /\ cpusPerTask = CORES_PER_NODE \div TASKS_PER_NODE

TerminalStability ==
    \A p \in PROVIDERS : jobState[p] \in TerminalStates
        => /\ (jobState[p] = "CANCELLED" => rawState[p] = "CANCELLED")
           /\ (jobState[p] = "TIMEOUT" => rawState[p] = "TIMEOUT")
           /\ (jobState[p] = "FAILED" => rawState[p] = "FAILED")
           /\ (jobState[p] = "MISSING" => ~observed[p])
           /\ (jobState[p] = "SCALED_IN" => ~observed[p])

TimeoutIsDistinct ==
    \A p \in PROVIDERS : rawState[p] = "TIMEOUT"
        => jobState[p] = "TIMEOUT"

SubmitStatusSafety ==
    \A p \in PROVIDERS : jobState[p] = "PENDING" \/ jobState[p] = "RUNNING"
        => observed[p]

CancelSafety ==
    \A p \in PROVIDERS : cancelResult[p] = "true"
        => jobState[p] = "CANCELLED"

ScaleInSafety ==
    \A p \in PROVIDERS : jobState[p] = "SCALED_IN"
        => /\ ~observed[p]
           /\ cancelResult[p] = "none"

ResourceSafety ==
    TASKS_PER_NODE <= CORES_PER_NODE => cpusPerTask > 0

=============================================================================
