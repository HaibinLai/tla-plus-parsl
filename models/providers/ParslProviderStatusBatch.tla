--------------------------- MODULE ParslProviderStatusBatch ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Batched scheduler status polling.
 *
 * ClusterProvider.status calls the provider-specific _status method once,
 * and Slurm batches active jobs by status_batch_size.  A scheduler command
 * failure returns before any accumulated output is applied.  A successful
 * poll applies all reported states and maps jobs absent from squeue/sacct to
 * COMPLETED, matching the current Slurm implementation.
 ***************************************************************************)

CONSTANTS JOBS, MAX_BATCH, MAX_POLLS
RawStates == {"PD", "R", "CD", "F", "TO", "UNKNOWN"}
JobStates == {"PENDING", "RUNNING", "COMPLETED", "FAILED", "TIMEOUT", "UNKNOWN"}
TerminalStates == {"COMPLETED", "FAILED", "TIMEOUT"}

Translate(raw) ==
    IF raw = "PD" THEN "PENDING"
    ELSE IF raw = "R" THEN "RUNNING"
    ELSE IF raw = "CD" THEN "COMPLETED"
    ELSE IF raw = "F" THEN "FAILED"
    ELSE IF raw = "TO" THEN "TIMEOUT"
    ELSE "UNKNOWN"

VARIABLES jobState, rawState, observed, pollVersion, lastPollFailed,
          beforeFailure, lastBatchSize, lastMissing
vars == <<jobState, rawState, observed, pollVersion, lastPollFailed,
           beforeFailure, lastBatchSize, lastMissing>>

Init ==
    /\ JOBS # {}
    /\ MAX_BATCH > 0
    /\ MAX_POLLS > 0
    /\ jobState = [j \in JOBS |-> "PENDING"]
    /\ rawState = [j \in JOBS |-> "PD"]
    /\ observed = [j \in JOBS |-> TRUE]
    /\ pollVersion = 0
    /\ lastPollFailed = FALSE
    /\ beforeFailure = [j \in JOBS |-> "PENDING"]
    /\ lastBatchSize = 0
    /\ lastMissing = {}

Active == {j \in JOBS : jobState[j] \notin TerminalStates}

StatusBatchFailure(batch) ==
    /\ batch \subseteq Active
    /\ batch # {}
    /\ Cardinality(batch) <= MAX_BATCH
    /\ lastPollFailed' = TRUE
    /\ beforeFailure' = jobState
    /\ lastBatchSize' = Cardinality(batch)
    /\ lastMissing' = {}
    /\ UNCHANGED <<jobState, rawState, observed, pollVersion>>

StatusBatchSuccess(batch, reported, raw) ==
    /\ batch \subseteq Active
    /\ batch # {}
    /\ Cardinality(batch) <= MAX_BATCH
    /\ pollVersion < MAX_POLLS
    /\ reported \subseteq batch
    /\ raw \in RawStates
    /\ jobState' = [j \in JOBS |->
          IF j \notin batch THEN jobState[j]
          ELSE IF j \in reported THEN Translate(raw)
          ELSE "COMPLETED"]
    /\ rawState' = [j \in JOBS |->
          IF j \notin batch THEN rawState[j]
          ELSE IF j \in reported THEN raw
          ELSE "UNKNOWN"]
    /\ observed' = [j \in JOBS |->
          IF j \notin batch THEN observed[j] ELSE j \in reported]
    /\ pollVersion' = pollVersion + 1
    /\ lastPollFailed' = FALSE
    /\ lastBatchSize' = Cardinality(batch)
    /\ lastMissing' = batch \ reported
    /\ UNCHANGED beforeFailure

Next ==
    \/ \E batch \in SUBSET JOBS : StatusBatchFailure(batch)
    \/ \E batch \in SUBSET JOBS :
          \E reported \in SUBSET batch :
                \E raw \in RawStates :
                      StatusBatchSuccess(batch, reported, raw)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ jobState \in [JOBS -> JobStates]
    /\ rawState \in [JOBS -> (RawStates \cup {"UNKNOWN"})]
    /\ observed \in [JOBS -> BOOLEAN]
    /\ pollVersion \in 0..MAX_POLLS
    /\ lastPollFailed \in BOOLEAN
    /\ beforeFailure \in [JOBS -> JobStates]
    /\ lastBatchSize \in 0..MAX_BATCH
    /\ lastMissing \subseteq JOBS

BatchBoundSafety ==
    lastBatchSize <= MAX_BATCH

FailureAtomicity ==
    lastPollFailed =>
        /\ jobState = beforeFailure
        /\ lastMissing = {}

MissingJobSafety ==
    lastMissing # {} =>
        /\ \A j \in lastMissing : jobState[j] = "COMPLETED"
        /\ ~lastPollFailed

TerminalStability ==
    \A j \in JOBS : jobState[j] \in TerminalStates
        => j \notin Active

=============================================================================
