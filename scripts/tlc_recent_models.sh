#!/usr/bin/env bash

# Run the bounded cross-layer models added in the recent refinement stages.
# Current configurations are expected to produce a counterexample; fixed and
# ordinary configurations must complete without an invariant violation.

set -u

JAVA_BIN=${JAVA_BIN:-java}
TLA_JAR=${TLA_JAR:-tla2tools.jar}
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

run_case() {
    local label=$1
    local expectation=$2
    local config=$3
    local spec=$4
    local log="$WORK_DIR/${label}.log"

    set +e
    "$JAVA_BIN" -cp "$TLA_JAR" tlc2.TLC -config "$config" "$spec" >"$log" 2>&1
    local rc=$?
    set -e

    if [[ "$expectation" == "pass" && $rc -ne 0 ]]; then
        cat "$log"
        echo "FAIL: $label expected TLC success (rc=$rc)" >&2
        exit 1
    fi
    if [[ "$expectation" == "counterexample" && $rc -eq 0 ]]; then
        cat "$log"
        echo "FAIL: $label expected a TLC counterexample" >&2
        exit 1
    fi

    local summary
    summary=$(grep -E '[0-9]+ states generated' "$log" | tail -1 || true)
    printf 'PASS %-42s rc=%s %s\n' "$label" "$rc" "$summary"
}

run_case callable-retry-current counterexample \
    models/serialization/ParslCallableRetryTransportCurrent.cfg \
    models/serialization/ParslCallableRetryTransport.tla
run_case callable-retry-fixed pass \
    models/serialization/ParslCallableRetryTransportFixed.cfg \
    models/serialization/ParslCallableRetryTransport.tla
run_case function-object-contents pass \
    models/serialization/ParslFunctionObjectContents.cfg \
    models/serialization/ParslFunctionObjectContents.tla
run_case serialization-wire pass \
    models/serialization/ParslSerializationWire.cfg \
    models/serialization/ParslSerializationWire.tla
run_case serialization-wire-failure pass \
    models/serialization/ParslSerializationWireFailure.cfg \
    models/serialization/ParslSerializationWire.tla
run_case callable-closure-memo-current counterexample \
    models/serialization/ParslCallableClosureMemo.cfg \
    models/serialization/ParslCallableClosureMemo.tla
run_case callable-closure-memo-fixed pass \
    models/serialization/ParslCallableClosureMemoFixed.cfg \
    models/serialization/ParslCallableClosureMemo.tla
run_case callable-mutation-cache-current counterexample \
    models/serialization/ParslCallableMutationCacheCurrent.cfg \
    models/serialization/ParslCallableMutationCache.tla
run_case callable-mutation-cache-fixed pass \
    models/serialization/ParslCallableMutationCacheFixed.cfg \
    models/serialization/ParslCallableMutationCache.tla
run_case zmq-serialization-current counterexample \
    models/serialization/ParslZMQSerializationEndToEnd.cfg \
    models/serialization/ParslZMQSerializationEndToEnd.tla
run_case zmq-serialization-fixed pass \
    models/serialization/ParslZMQSerializationEndToEndFixed.cfg \
    models/serialization/ParslZMQSerializationEndToEnd.tla
run_case message-loss pass \
    models/core/ParslMessageLoss.cfg \
    models/core/ParslAbstract.tla
run_case message-duplicate pass \
    models/core/ParslMessageDuplicate.cfg \
    models/core/ParslAbstract.tla
run_case message-misroute pass \
    models/core/ParslMisroute.cfg \
    models/core/ParslAbstract.tla
run_case result-misroute pass \
    models/core/ParslResultMisroute.cfg \
    models/core/ParslAbstract.tla
run_case provider-failure-retry-current counterexample \
    models/core/ParslProviderFailureRetryCurrent.cfg \
    models/core/ParslProviderFailureRetry.tla
run_case provider-failure-retry-fixed pass \
    models/core/ParslProviderFailureRetryFixed.cfg \
    models/core/ParslProviderFailureRetry.tla
run_case python-object-graph pass \
    models/serialization/ParslPython.cfg \
    models/serialization/ParslPython.tla
run_case python-object-graph-failure pass \
    models/serialization/ParslPythonFailure.cfg \
    models/serialization/ParslPython.tla
run_case python-object-graph-cyclic pass \
    models/serialization/ParslPythonCyclic.cfg \
    models/serialization/ParslPython.tla
run_case python-timeout-catch-current counterexample \
    models/serialization/ParslPythonTimeoutCatch.cfg \
    models/serialization/ParslPythonTimeoutCatch.tla
run_case python-timeout-catch-fixed pass \
    models/serialization/ParslPythonTimeoutCatchFixed.cfg \
    models/serialization/ParslPythonTimeoutCatch.tla
run_case function-object-transport pass \
    models/serialization/ParslFunctionObjectTransport.cfg \
    models/serialization/ParslFunctionObjectTransport.tla
run_case object-snapshot-retry-current counterexample \
    models/serialization/ParslObjectSnapshotRetryCurrent.cfg \
    models/serialization/ParslObjectSnapshotRetry.tla
run_case object-snapshot-retry-fixed pass \
    models/serialization/ParslObjectSnapshotRetryFixed.cfg \
    models/serialization/ParslObjectSnapshotRetry.tla
run_case zmq-object-snapshot-current counterexample \
    models/serialization/ParslZMQObjectSnapshotCurrent.cfg \
    models/serialization/ParslZMQObjectSnapshot.tla
run_case zmq-object-snapshot-fixed pass \
    models/serialization/ParslZMQObjectSnapshotFixed.cfg \
    models/serialization/ParslZMQObjectSnapshot.tla
run_case heartbeat-timeout-current counterexample \
    models/clock/ParslHeartbeatTimeoutPersistenceCurrent.cfg \
    models/clock/ParslHeartbeatTimeoutPersistence.tla
run_case heartbeat-timeout-fixed pass \
    models/clock/ParslHeartbeatTimeoutPersistenceFixed.cfg \
    models/clock/ParslHeartbeatTimeoutPersistence.tla
run_case clock-retry-heartbeat pass \
    models/clock/ParslClock.cfg \
    models/clock/ParslClock.tla
run_case clock-terminal-timeout pass \
    models/clock/ParslClockTerminal.cfg \
    models/clock/ParslClock.tla
run_case heartbeat-clock-rollback-current counterexample \
    models/clock/ParslHeartbeatClockRollbackCurrent.cfg \
    models/clock/ParslHeartbeatClockRollback.tla
run_case heartbeat-clock-rollback-fixed pass \
    models/clock/ParslHeartbeatClockRollbackFixed.cfg \
    models/clock/ParslHeartbeatClockRollback.tla
run_case time-limited-open-current counterexample \
    models/clock/ParslTimeLimitedOpenTimeoutCurrent.cfg \
    models/clock/ParslTimeLimitedOpenTimeout.tla
run_case time-limited-open-fixed pass \
    models/clock/ParslTimeLimitedOpenTimeoutFixed.cfg \
    models/clock/ParslTimeLimitedOpenTimeout.tla
run_case time-limited-open-success pass \
    models/clock/ParslTimeLimitedOpenTimeoutSuccess.cfg \
    models/clock/ParslTimeLimitedOpenTimeout.tla
run_case monitoring-history pass \
    models/monitoring/ParslMonitoringStatusHistory.cfg \
    models/monitoring/ParslMonitoringStatusHistory.tla
run_case provider-worker-scaling pass \
    models/executors/ParslProviderWorkerScaling.cfg \
    models/executors/ParslProviderWorkerScaling.tla
run_case join-callable-transport pass \
    models/dataflow/ParslJoinCallableTransport.cfg \
    models/dataflow/ParslJoinCallableTransport.tla
run_case bash-app-outcome pass \
    models/executors/ParslBashAppOutcome.cfg \
    models/executors/ParslBashAppOutcome.tla
run_case local-provider-exit-status pass \
    models/providers/ParslLocalProviderExitStatus.cfg \
    models/providers/ParslLocalProviderExitStatus.tla
run_case thread-future-lifecycle pass \
    models/executors/ParslThreadExecutorFutureLifecycle.cfg \
    models/executors/ParslThreadExecutorFutureLifecycle.tla
run_case executor-shutdown pass \
    models/executors/ParslExecutorShutdown.cfg \
    models/executors/ParslExecutorShutdown.tla
run_case taskvine-factory pass \
    models/executors/ParslTaskVineFactory.cfg \
    models/executors/ParslTaskVineFactory.tla
run_case periodic-timer pass \
    models/clock/ParslPeriodicTimer.cfg \
    models/clock/ParslPeriodicTimer.tla
run_case timeout-monitoring-current counterexample \
    models/clock/ParslTimeoutMonitoringCurrent.cfg \
    models/clock/ParslTimeoutMonitoring.tla
run_case timeout-monitoring-fixed pass \
    models/clock/ParslTimeoutMonitoringFixed.cfg \
    models/clock/ParslTimeoutMonitoring.tla
run_case timer-reentrant-close-current counterexample \
    models/clock/ParslTimerReentrantCloseCurrent.cfg \
    models/clock/ParslTimerReentrantClose.tla
run_case timer-reentrant-close-fixed pass \
    models/clock/ParslTimerReentrantCloseFixed.cfg \
    models/clock/ParslTimerReentrantClose.tla
run_case apply-dispatch-current counterexample \
    models/serialization/ParslApplyDispatchBoundaryCurrent.cfg \
    models/serialization/ParslApplyDispatchBoundary.tla
run_case apply-dispatch-fixed pass \
    models/serialization/ParslApplyDispatchBoundaryFixed.cfg \
    models/serialization/ParslApplyDispatchBoundary.tla
run_case htex-shutdown-timeout pass \
    models/clock/ParslHtexShutdownTimeout.cfg \
    models/clock/ParslHtexShutdownTimeout.tla
run_case join-cancellation-current counterexample \
    models/dataflow/ParslJoinCancellationCurrent.cfg \
    models/dataflow/ParslJoinCancellation.tla
run_case join-cancellation-fixed pass \
    models/dataflow/ParslJoinCancellationFixed.cfg \
    models/dataflow/ParslJoinCancellation.tla
run_case join-list-cancellation-current counterexample \
    models/dataflow/ParslJoinListCancellationCurrent.cfg \
    models/dataflow/ParslJoinListCancellation.tla
run_case join-list-cancellation-fixed pass \
    models/dataflow/ParslJoinListCancellationFixed.cfg \
    models/dataflow/ParslJoinListCancellation.tla
run_case data-ready-current counterexample \
    models/core/ParslDataReadyExecutionCurrent.cfg \
    models/core/ParslDataReadyExecution.tla
run_case data-ready-fixed pass \
    models/core/ParslDataReadyExecutionFixed.cfg \
    models/core/ParslDataReadyExecution.tla
run_case dependency-traversal-shallow counterexample \
    models/dataflow/ParslDependencyTraversalShallow.cfg \
    models/dataflow/ParslDependencyTraversal.tla
run_case dependency-traversal-deep-list pass \
    models/dataflow/ParslDependencyTraversal.cfg \
    models/dataflow/ParslDependencyTraversal.tla
run_case dependency-traversal-deep-dict pass \
    models/dataflow/ParslDependencyTraversalDeepDict.cfg \
    models/dataflow/ParslDependencyTraversal.tla
run_case dependency-traversal-deep-key pass \
    models/dataflow/ParslDependencyTraversalDeepDictKey.cfg \
    models/dataflow/ParslDependencyTraversal.tla
run_case dependency-traversal-deep-tuple pass \
    models/dataflow/ParslDependencyTraversalDeepTuple.cfg \
    models/dataflow/ParslDependencyTraversal.tla
run_case dependency-traversal-deep-set pass \
    models/dataflow/ParslDependencyTraversalDeepSet.cfg \
    models/dataflow/ParslDependencyTraversal.tla
run_case memo-function-identity-current counterexample \
    models/dataflow/ParslMemoFunctionIdentityCurrent.cfg \
    models/dataflow/ParslMemoFunctionIdentity.tla
run_case memo-function-identity-fixed pass \
    models/dataflow/ParslMemoFunctionIdentityFixed.cfg \
    models/dataflow/ParslMemoFunctionIdentity.tla
run_case memo-function-identity-stable pass \
    models/dataflow/ParslMemoFunctionIdentityStable.cfg \
    models/dataflow/ParslMemoFunctionIdentity.tla
run_case memo-exception-checkpoint-current counterexample \
    models/dataflow/ParslMemoExceptionCheckpointCurrent.cfg \
    models/dataflow/ParslMemoExceptionCheckpoint.tla
run_case memo-exception-checkpoint-fixed pass \
    models/dataflow/ParslMemoExceptionCheckpointFixed.cfg \
    models/dataflow/ParslMemoExceptionCheckpoint.tla
run_case memo-dict-order-current counterexample \
    models/dataflow/ParslMemoDictOrderingCurrent.cfg \
    models/dataflow/ParslMemoDictOrdering.tla
run_case memo-dict-order-fixed pass \
    models/dataflow/ParslMemoDictOrderingFixed.cfg \
    models/dataflow/ParslMemoDictOrdering.tla
run_case memo-dict-order-homogeneous pass \
    models/dataflow/ParslMemoDictOrderingHomogeneous.cfg \
    models/dataflow/ParslMemoDictOrdering.tla
run_case monitoring-retry-current counterexample \
    models/monitoring/ParslMonitoringTaskRetry.cfg \
    models/monitoring/ParslMonitoringTaskRetry.tla
run_case monitoring-retry-fixed pass \
    models/monitoring/ParslMonitoringTaskRetryFixed.cfg \
    models/monitoring/ParslMonitoringTaskRetry.tla
run_case htex-task-message-current counterexample \
    models/executors/ParslHtexTaskMessageMalformedCurrent.cfg \
    models/executors/ParslHtexTaskMessageMalformed.tla
run_case htex-task-message-fixed pass \
    models/executors/ParslHtexTaskMessageMalformedFixed.cfg \
    models/executors/ParslHtexTaskMessageMalformed.tla
run_case htex-result-message-current counterexample \
    models/executors/ParslHtexResultMessageMalformedCurrent.cfg \
    models/executors/ParslHtexResultMessageMalformed.tla
run_case htex-result-message-fixed pass \
    models/executors/ParslHtexResultMessageMalformedFixed.cfg \
    models/executors/ParslHtexResultMessageMalformed.tla
run_case htex-result-batch-current counterexample \
    models/executors/ParslHtexResultBatchContinuationCurrent.cfg \
    models/executors/ParslHtexResultBatchContinuation.tla
run_case htex-result-batch-fixed pass \
    models/executors/ParslHtexResultBatchContinuationFixed.cfg \
    models/executors/ParslHtexResultBatchContinuation.tla
run_case htex-executor-result-frame-current counterexample \
    models/executors/ParslHtexExecutorResultFrameContinuationCurrent.cfg \
    models/executors/ParslHtexExecutorResultFrameContinuation.tla
run_case htex-executor-result-frame-fixed pass \
    models/executors/ParslHtexExecutorResultFrameContinuationFixed.cfg \
    models/executors/ParslHtexExecutorResultFrameContinuation.tla
run_case htex-result-queue-current counterexample \
    models/executors/ParslHtexResultQueue.cfg \
    models/executors/ParslHtexResultQueue.tla
run_case htex-result-queue-fixed pass \
    models/executors/ParslHtexResultQueueFixed.cfg \
    models/executors/ParslHtexResultQueue.tla
run_case htex-manager-selection pass \
    models/executors/ParslHtexManagerSelection.cfg \
    models/executors/ParslHtexManagerSelection.tla
run_case htex-manager-selection-block pass \
    models/executors/ParslHtexManagerSelectionBlock.cfg \
    models/executors/ParslHtexManagerSelection.tla
run_case htex-manager-eligibility pass \
    models/executors/ParslHtexManagerEligibility.cfg \
    models/executors/ParslHtexManagerEligibility.tla
run_case executor-selection-current counterexample \
    models/executors/ParslExecutorSelectionCurrent.cfg \
    models/executors/ParslExecutorSelection.tla
run_case executor-selection-fixed pass \
    models/executors/ParslExecutorSelectionFixed.cfg \
    models/executors/ParslExecutorSelection.tla
run_case resource-admission pass \
    models/dataflow/ParslResourceAdmission.cfg \
    models/dataflow/ParslResourceAdmission.tla
run_case resource-admission-autolabel pass \
    models/dataflow/ParslResourceAdmissionAutolabel.cfg \
    models/dataflow/ParslResourceAdmission.tla
run_case resource-scaling pass \
    models/dataflow/ParslResourceScaling.cfg \
    models/dataflow/ParslResourceScaling.tla
run_case htex-priority-current counterexample \
    models/executors/ParslHtexTaskPriorityTypeCurrent.cfg \
    models/executors/ParslHtexTaskPriorityType.tla
run_case htex-priority-fixed pass \
    models/executors/ParslHtexTaskPriorityTypeFixed.cfg \
    models/executors/ParslHtexTaskPriorityType.tla
run_case slurm-status-current counterexample \
    models/providers/ParslSlurmStatusCurrent.cfg \
    models/providers/ParslSlurmStatus.tla
run_case slurm-status-fixed pass \
    models/providers/ParslSlurmStatusFixed.cfg \
    models/providers/ParslSlurmStatus.tla
run_case htex-resource-spec-current counterexample \
    models/executors/ParslHtexTaskResourceSpecTypeCurrent.cfg \
    models/executors/ParslHtexTaskResourceSpecType.tla
run_case htex-resource-spec-fixed pass \
    models/executors/ParslHtexTaskResourceSpecTypeFixed.cfg \
    models/executors/ParslHtexTaskResourceSpecType.tla
run_case aws-status-cardinality-current counterexample \
    models/providers/ParslAwsStatusMissingResultCurrent.cfg \
    models/providers/ParslAwsStatusMissingResult.tla
run_case aws-status-cardinality-fixed pass \
    models/providers/ParslAwsStatusMissingResultFixed.cfg \
    models/providers/ParslAwsStatusMissingResult.tla
run_case kubernetes-polling-current counterexample \
    models/providers/ParslKubernetesPolling.cfg \
    models/providers/ParslKubernetesPolling.tla
run_case kubernetes-polling-fixed pass \
    models/providers/ParslKubernetesPollingFixed.cfg \
    models/providers/ParslKubernetesPolling.tla
run_case local-provider-current counterexample \
    models/providers/ParslLocalProviderCurrent.cfg \
    models/providers/ParslLocalProvider.tla
run_case local-provider-fixed pass \
    models/providers/ParslLocalProviderFixed.cfg \
    models/providers/ParslLocalProvider.tla
run_case local-provider-status-scope-current counterexample \
    models/providers/ParslLocalProviderStatusScope.cfg \
    models/providers/ParslLocalProviderStatusScope.tla
run_case local-provider-status-scope-fixed pass \
    models/providers/ParslLocalProviderStatusScopeFixed.cfg \
    models/providers/ParslLocalProviderStatusScope.tla
run_case slurm-malformed-line-current counterexample \
    models/providers/ParslSlurmMalformedLineCurrent.cfg \
    models/providers/ParslSlurmMalformedLine.tla
run_case slurm-malformed-line-fixed pass \
    models/providers/ParslSlurmMalformedLineFixed.cfg \
    models/providers/ParslSlurmMalformedLine.tla
run_case pbspro-malformed-json-current counterexample \
    models/providers/ParslPBSProMalformedJSONCurrent.cfg \
    models/providers/ParslPBSProMalformedJSON.tla
run_case pbspro-malformed-json-fixed pass \
    models/providers/ParslPBSProMalformedJSONFixed.cfg \
    models/providers/ParslPBSProMalformedJSON.tla
run_case pbspro-job-alias-current counterexample \
    models/providers/ParslPBSProJobIdAliasCurrent.cfg \
    models/providers/ParslPBSProJobIdAlias.tla
run_case pbspro-job-alias-fixed pass \
    models/providers/ParslPBSProJobIdAliasFixed.cfg \
    models/providers/ParslPBSProJobIdAlias.tla
run_case pbspro-job-alias-unique pass \
    models/providers/ParslPBSProJobIdAliasUnique.cfg \
    models/providers/ParslPBSProJobIdAlias.tla
run_case condor-malformed-line-current counterexample \
    models/providers/ParslCondorMalformedStatusLineCurrent.cfg \
    models/providers/ParslCondorMalformedStatusLine.tla
run_case condor-malformed-line-fixed pass \
    models/providers/ParslCondorMalformedStatusLineFixed.cfg \
    models/providers/ParslCondorMalformedStatusLine.tla
run_case condor-unknown-job-current counterexample \
    models/providers/ParslCondorUnknownJobCurrent.cfg \
    models/providers/ParslCondorUnknownJob.tla
run_case condor-unknown-job-fixed pass \
    models/providers/ParslCondorUnknownJobFixed.cfg \
    models/providers/ParslCondorUnknownJob.tla
run_case gridengine-duplicate-current counterexample \
    models/providers/ParslGridEngineDuplicateStatusCurrent.cfg \
    models/providers/ParslGridEngineDuplicateStatus.tla
run_case gridengine-duplicate-fixed pass \
    models/providers/ParslGridEngineDuplicateStatusFixed.cfg \
    models/providers/ParslGridEngineDuplicateStatus.tla
run_case gridengine-status-batch-current counterexample \
    models/providers/ParslGridEngineStatusBatchCurrent.cfg \
    models/providers/ParslGridEngineStatusBatch.tla
run_case gridengine-status-batch-fixed pass \
    models/providers/ParslGridEngineStatusBatchFixed.cfg \
    models/providers/ParslGridEngineStatusBatch.tla
run_case torque-submit-success pass \
    models/providers/ParslTorqueSubmit.cfg \
    models/providers/ParslTorqueSubmit.tla
run_case torque-submit-empty pass \
    models/providers/ParslTorqueSubmitEmpty.cfg \
    models/providers/ParslTorqueSubmit.tla
run_case torque-submit-failure pass \
    models/providers/ParslTorqueSubmitFailure.cfg \
    models/providers/ParslTorqueSubmit.tla
run_case workqueue-submit-current counterexample \
    models/executors/ParslWorkQueueSubmitFailure.cfg \
    models/executors/ParslWorkQueueSubmit.tla
run_case workqueue-submit-fixed pass \
    models/executors/ParslWorkQueueSubmitFixed.cfg \
    models/executors/ParslWorkQueueSubmit.tla
run_case workqueue-serialization-current counterexample \
    models/executors/ParslWorkQueueSubmitSerializationFailure.cfg \
    models/executors/ParslWorkQueueSubmit.tla
run_case workqueue-serialization-fixed pass \
    models/executors/ParslWorkQueueSubmitSerializationFailureFixed.cfg \
    models/executors/ParslWorkQueueSubmit.tla
run_case taskvine-submit-current counterexample \
    models/executors/ParslTaskVineSubmitCurrent.cfg \
    models/executors/ParslTaskVineSubmit.tla
run_case taskvine-submit-fixed pass \
    models/executors/ParslTaskVineSubmitFixed.cfg \
    models/executors/ParslTaskVineSubmit.tla
run_case taskvine-serialization-current counterexample \
    models/executors/ParslTaskVineSubmitSerializationFailure.cfg \
    models/executors/ParslTaskVineSubmit.tla
run_case taskvine-serialization-fixed pass \
    models/executors/ParslTaskVineSubmitSerializationFailureFixed.cfg \
    models/executors/ParslTaskVineSubmit.tla
run_case flux-cleanup-current counterexample \
    models/executors/ParslFluxErrorCleanupCancellationCurrent.cfg \
    models/executors/ParslFluxErrorCleanupCancellation.tla
run_case flux-cleanup-fixed pass \
    models/executors/ParslFluxErrorCleanupCancellationFixed.cfg \
    models/executors/ParslFluxErrorCleanupCancellation.tla
run_case poller-scalein-current counterexample \
    models/providers/ParslPollerCloseScaleInRaceCurrent.cfg \
    models/providers/ParslPollerCloseScaleInRace.tla
run_case poller-scalein-fixed pass \
    models/providers/ParslPollerCloseScaleInRaceFixed.cfg \
    models/providers/ParslPollerCloseScaleInRace.tla
run_case htex-duplicate-registration-current counterexample \
    models/executors/ParslHtexDuplicateRegistrationCurrent.cfg \
    models/executors/ParslHtexDuplicateRegistration.tla
run_case htex-duplicate-registration-fixed pass \
    models/executors/ParslHtexDuplicateRegistrationFixed.cfg \
    models/executors/ParslHtexDuplicateRegistration.tla
run_case htex-manager-drain-current counterexample \
    models/executors/ParslHtexManagerDrainCurrent.cfg \
    models/executors/ParslHtexManagerDrain.tla
run_case htex-manager-drain-fixed pass \
    models/executors/ParslHtexManagerDrainFixed.cfg \
    models/executors/ParslHtexManagerDrain.tla
run_case htex-manager-drain-present pass \
    models/executors/ParslHtexManagerDrainPresent.cfg \
    models/executors/ParslHtexManagerDrain.tla
run_case htex-watchdog-result-current counterexample \
    models/executors/ParslHtexWatchdogResultRaceCurrent.cfg \
    models/executors/ParslHtexWatchdogResultRace.tla
run_case htex-watchdog-result-fixed pass \
    models/executors/ParslHtexWatchdogResultRaceFixed.cfg \
    models/executors/ParslHtexWatchdogResultRace.tla
run_case htex-worker-watchdog-busy pass \
    models/executors/ParslHtexWorkerWatchdog.cfg \
    models/executors/ParslHtexWorkerWatchdog.tla
run_case htex-worker-watchdog-idle pass \
    models/executors/ParslHtexWorkerWatchdogIdle.cfg \
    models/executors/ParslHtexWorkerWatchdog.tla
run_case radical-bulk-shutdown-current counterexample \
    models/executors/ParslRadicalPilotBulkShutdownCurrent.cfg \
    models/executors/ParslRadicalPilotBulkShutdown.tla
run_case radical-bulk-shutdown-fixed pass \
    models/executors/ParslRadicalPilotBulkShutdownFixed.cfg \
    models/executors/ParslRadicalPilotBulkShutdown.tla
run_case radical-results-current counterexample \
    models/executors/ParslRadicalPilotResults.cfg \
    models/executors/ParslRadicalPilotResults.tla
run_case radical-results-fixed pass \
    models/executors/ParslRadicalPilotResultsFixed.cfg \
    models/executors/ParslRadicalPilotResults.tla
run_case aws-unknown-instance-current counterexample \
    models/providers/ParslAwsUnknownInstanceCurrent.cfg \
    models/providers/ParslAwsUnknownInstance.tla
run_case aws-unknown-instance-fixed pass \
    models/providers/ParslAwsUnknownInstanceFixed.cfg \
    models/providers/ParslAwsUnknownInstance.tla
run_case command-client-close-current counterexample \
    models/executors/ParslCommandClientCloseRaceCurrent.cfg \
    models/executors/ParslCommandClientCloseRace.tla
run_case command-client-close-fixed pass \
    models/executors/ParslCommandClientCloseRaceFixed.cfg \
    models/executors/ParslCommandClientCloseRace.tla
run_case kubernetes-admission-current counterexample \
    models/providers/ParslKubernetesAdmissionCurrent.cfg \
    models/providers/ParslKubernetesAdmission.tla
run_case kubernetes-admission-fixed pass \
    models/providers/ParslKubernetesAdmissionFixed.cfg \
    models/providers/ParslKubernetesAdmission.tla
run_case kubernetes-unknown-job-current counterexample \
    models/providers/ParslKubernetesUnknownJobCurrent.cfg \
    models/providers/ParslKubernetesUnknownJob.tla
run_case kubernetes-unknown-job-fixed pass \
    models/providers/ParslKubernetesUnknownJobFixed.cfg \
    models/providers/ParslKubernetesUnknownJob.tla
run_case kubernetes-submit-current counterexample \
    models/providers/ParslKubernetesSubmit.cfg \
    models/providers/ParslKubernetesSubmit.tla
run_case kubernetes-submit-fixed pass \
    models/providers/ParslKubernetesSubmitFixed.cfg \
    models/providers/ParslKubernetesSubmit.tla
run_case aws-submit-current counterexample \
    models/providers/ParslAWSProviderSubmit.cfg \
    models/providers/ParslAWSProviderSubmit.tla
run_case aws-submit-fixed pass \
    models/providers/ParslAWSProviderSubmitFixed.cfg \
    models/providers/ParslAWSProviderSubmit.tla
run_case aws-submit-empty-current counterexample \
    models/providers/ParslAwsSubmitEmptyResponseCurrent.cfg \
    models/providers/ParslAwsSubmitEmptyResponse.tla
run_case aws-submit-empty-fixed pass \
    models/providers/ParslAwsSubmitEmptyResponseFixed.cfg \
    models/providers/ParslAwsSubmitEmptyResponse.tla
run_case googlecloud-status-current counterexample \
    models/providers/ParslGoogleCloudStatus.cfg \
    models/providers/ParslGoogleCloudStatus.tla
run_case googlecloud-status-fixed pass \
    models/providers/ParslGoogleCloudStatusFixed.cfg \
    models/providers/ParslGoogleCloudStatus.tla
run_case googlecloud-status-present pass \
    models/providers/ParslGoogleCloudStatusPresent.cfg \
    models/providers/ParslGoogleCloudStatus.tla
run_case condor-status-failure-current-valid counterexample \
    models/providers/ParslCondorStatusFailureCurrentValid.cfg \
    models/providers/ParslCondorStatusFailure.tla
run_case condor-status-failure-current-malformed counterexample \
    models/providers/ParslCondorStatusFailureCurrentMalformed.cfg \
    models/providers/ParslCondorStatusFailure.tla
run_case condor-status-failure-fixed-valid pass \
    models/providers/ParslCondorStatusFailureFixedValid.cfg \
    models/providers/ParslCondorStatusFailure.tla
run_case condor-status-failure-fixed-malformed pass \
    models/providers/ParslCondorStatusFailureFixedMalformed.cfg \
    models/providers/ParslCondorStatusFailure.tla
run_case condor-status-failure-success pass \
    models/providers/ParslCondorStatusFailureSuccess.cfg \
    models/providers/ParslCondorStatusFailure.tla
run_case cluster-submit-script-valid pass \
    models/providers/ParslClusterSubmitScript.cfg \
    models/providers/ParslClusterSubmitScript.tla
run_case cluster-submit-script-missing-key pass \
    models/providers/ParslClusterSubmitScriptMissingKey.cfg \
    models/providers/ParslClusterSubmitScript.tla
run_case cluster-submit-script-io-error pass \
    models/providers/ParslClusterSubmitScriptIOError.cfg \
    models/providers/ParslClusterSubmitScript.tla
run_case cluster-status-request pass \
    models/providers/ParslClusterStatusRequest.cfg \
    models/providers/ParslClusterStatusRequest.tla
run_case callable-equal-cache-current counterexample \
    models/serialization/ParslCallableEqualCacheCurrent.cfg \
    models/serialization/ParslCallableEqualCache.tla
run_case callable-equal-cache-fixed pass \
    models/serialization/ParslCallableEqualCacheFixed.cfg \
    models/serialization/ParslCallableEqualCache.tla
run_case zip-stagein-write-current counterexample \
    models/staging/ParslZipStageInWriteFailure.cfg \
    models/staging/ParslZipStageIn.tla
run_case zip-stagein-write-fixed pass \
    models/staging/ParslZipStageInWriteFailureFixed.cfg \
    models/staging/ParslZipStageIn.tla
run_case monitoring-update-permanent-current counterexample \
    models/monitoring/ParslMonitoringDBUpdatePermanentErrorCurrent.cfg \
    models/monitoring/ParslMonitoringDBUpdatePermanentError.tla
run_case monitoring-update-permanent-fixed pass \
    models/monitoring/ParslMonitoringDBUpdatePermanentErrorFixed.cfg \
    models/monitoring/ParslMonitoringDBUpdatePermanentError.tla
run_case monitoring-update-retry-current counterexample \
    models/monitoring/ParslMonitoringUpdatePersistentRetryCurrent.cfg \
    models/monitoring/ParslMonitoringUpdatePersistentRetry.tla
run_case monitoring-update-retry-fixed pass \
    models/monitoring/ParslMonitoringUpdatePersistentRetryFixed.cfg \
    models/monitoring/ParslMonitoringUpdatePersistentRetry.tla
run_case monitoring-insert-retry-current counterexample \
    models/monitoring/ParslMonitoringPersistentRetryCurrent.cfg \
    models/monitoring/ParslMonitoringPersistentRetry.tla
run_case monitoring-insert-retry-fixed pass \
    models/monitoring/ParslMonitoringPersistentRetryFixed.cfg \
    models/monitoring/ParslMonitoringPersistentRetry.tla
run_case monitoring-batch-atomicity-current counterexample \
    models/monitoring/ParslMonitoringBatchAtomicityCurrent.cfg \
    models/monitoring/ParslMonitoringBatchAtomicity.tla
run_case monitoring-batch-atomicity-fixed pass \
    models/monitoring/ParslMonitoringBatchAtomicityFixed.cfg \
    models/monitoring/ParslMonitoringBatchAtomicity.tla
run_case monitoring-batch-atomicity-success pass \
    models/monitoring/ParslMonitoringBatchAtomicitySuccess.cfg \
    models/monitoring/ParslMonitoringBatchAtomicity.tla
run_case monitoring-workflow-insert-current counterexample \
    models/monitoring/ParslMonitoringWorkflowInsertBookkeepingCurrent.cfg \
    models/monitoring/ParslMonitoringWorkflowInsertBookkeeping.tla
run_case monitoring-workflow-insert-fixed pass \
    models/monitoring/ParslMonitoringWorkflowInsertBookkeepingFixed.cfg \
    models/monitoring/ParslMonitoringWorkflowInsertBookkeeping.tla
run_case monitoring-workflow-end-current counterexample \
    models/monitoring/ParslMonitoringWorkflowEndBookkeepingCurrent.cfg \
    models/monitoring/ParslMonitoringWorkflowEndBookkeeping.tla
run_case monitoring-workflow-end-fixed pass \
    models/monitoring/ParslMonitoringWorkflowEndBookkeepingFixed.cfg \
    models/monitoring/ParslMonitoringWorkflowEndBookkeeping.tla
run_case monitoring-last-message-current counterexample \
    models/monitoring/ParslMonitoringLastMessageRaceCurrent.cfg \
    models/monitoring/ParslMonitoringLastMessageRace.tla
run_case monitoring-last-message-fixed pass \
    models/monitoring/ParslMonitoringLastMessageRaceFixed.cfg \
    models/monitoring/ParslMonitoringLastMessageRace.tla
run_case monitoring-zmq-router-current counterexample \
    models/monitoring/ParslMonitoringZMQRouterFailureCurrent.cfg \
    models/monitoring/ParslMonitoringZMQRouterFailure.tla
run_case monitoring-zmq-router-fixed pass \
    models/monitoring/ParslMonitoringZMQRouterFailureFixed.cfg \
    models/monitoring/ParslMonitoringZMQRouterFailure.tla
run_case monitoring-zmq-router-valid pass \
    models/monitoring/ParslMonitoringZMQRouterFailureValid.cfg \
    models/monitoring/ParslMonitoringZMQRouterFailure.tla
run_case globus-transfer-timeout-current counterexample \
    models/staging/ParslGlobusTransferTimeoutCurrent.cfg \
    models/staging/ParslGlobusTransferTimeout.tla
run_case globus-transfer-timeout-fixed pass \
    models/staging/ParslGlobusTransferTimeoutFixed.cfg \
    models/staging/ParslGlobusTransferTimeout.tla
run_case globus-transfer-failure-current-empty counterexample \
    models/staging/ParslGlobusTransferFailureCurrentEmpty.cfg \
    models/staging/ParslGlobusTransferFailure.tla
run_case globus-transfer-failure-current-event pass \
    models/staging/ParslGlobusTransferFailureCurrentEvent.cfg \
    models/staging/ParslGlobusTransferFailure.tla
run_case globus-transfer-failure-fixed-empty pass \
    models/staging/ParslGlobusTransferFailureFixedEmpty.cfg \
    models/staging/ParslGlobusTransferFailure.tla
run_case globus-transfer-failure-success pass \
    models/staging/ParslGlobusTransferFailureSuccess.cfg \
    models/staging/ParslGlobusTransferFailure.tla
run_case join-duplicate-failure-current counterexample \
    models/dataflow/ParslJoinDuplicateFailureAggregationCurrent.cfg \
    models/dataflow/ParslJoinDuplicateFailureAggregation.tla
run_case join-duplicate-failure-fixed pass \
    models/dataflow/ParslJoinDuplicateFailureAggregationFixed.cfg \
    models/dataflow/ParslJoinDuplicateFailureAggregation.tla
run_case azure-status-bookkeeping-current counterexample \
    models/providers/ParslAzureStatusBookkeepingCurrent.cfg \
    models/providers/ParslAzureStatusBookkeeping.tla
run_case azure-status-bookkeeping-fixed pass \
    models/providers/ParslAzureStatusBookkeepingFixed.cfg \
    models/providers/ParslAzureStatusBookkeeping.tla
run_case aws-cancel-missing-current counterexample \
    models/providers/ParslAWSProviderCancelMissingCurrent.cfg \
    models/providers/ParslAWSProviderCancel.tla
run_case aws-cancel-missing-fixed pass \
    models/providers/ParslAWSProviderCancelMissingFixed.cfg \
    models/providers/ParslAWSProviderCancel.tla
run_case azure-submit-current counterexample \
    models/providers/ParslAzureProviderSubmit.cfg \
    models/providers/ParslAzureProviderSubmit.tla
run_case azure-submit-fixed pass \
    models/providers/ParslAzureProviderSubmitFixed.cfg \
    models/providers/ParslAzureProviderSubmit.tla
run_case local-submit-cleanup-current counterexample \
    models/providers/ParslLocalProviderSubmitCleanupCurrent.cfg \
    models/providers/ParslLocalProviderSubmitCleanup.tla
run_case local-submit-cleanup-fixed pass \
    models/providers/ParslLocalProviderSubmitCleanupFixed.cfg \
    models/providers/ParslLocalProviderSubmitCleanup.tla
run_case local-submit-cleanup-success pass \
    models/providers/ParslLocalProviderSubmitCleanupSuccess.cfg \
    models/providers/ParslLocalProviderSubmitCleanup.tla
run_case globus-compute-submit-current counterexample \
    models/executors/ParslGlobusComputeSubmitRaceCurrent.cfg \
    models/executors/ParslGlobusComputeSubmitRace.tla
run_case globus-compute-submit-fixed pass \
    models/executors/ParslGlobusComputeSubmitRaceFixed.cfg \
    models/executors/ParslGlobusComputeSubmitRace.tla
run_case lsf-duplicate-current counterexample \
    models/providers/ParslLSFDuplicateStatusCurrent.cfg \
    models/providers/ParslLSFDuplicateStatus.tla
run_case lsf-duplicate-fixed pass \
    models/providers/ParslLSFDuplicateStatusFixed.cfg \
    models/providers/ParslLSFDuplicateStatus.tla
run_case lsf-duplicate-unique pass \
    models/providers/ParslLSFDuplicateStatusUnique.cfg \
    models/providers/ParslLSFDuplicateStatus.tla
run_case timer-close-timeout-current counterexample \
    models/clock/ParslTimerCloseTimeoutCurrent.cfg \
    models/clock/ParslTimerCloseTimeout.tla
run_case timer-close-timeout-fixed pass \
    models/clock/ParslTimerCloseTimeoutFixed.cfg \
    models/clock/ParslTimerCloseTimeout.tla
run_case join-list-mutation-current counterexample \
    models/dataflow/ParslJoinListMutationCurrent.cfg \
    models/dataflow/ParslJoinListMutation.tla
run_case join-list-mutation-fixed pass \
    models/dataflow/ParslJoinListMutationFixed.cfg \
    models/dataflow/ParslJoinListMutation.tla
run_case join-list-mutation-stable pass \
    models/dataflow/ParslJoinListMutationStable.cfg \
    models/dataflow/ParslJoinListMutation.tla
run_case command-client-retries-current counterexample \
    models/executors/ParslCommandClientMaxRetriesCurrent.cfg \
    models/executors/ParslCommandClientMaxRetries.tla
run_case command-client-retries-fixed pass \
    models/executors/ParslCommandClientMaxRetriesFixed.cfg \
    models/executors/ParslCommandClientMaxRetries.tla
run_case taskvine-duplicate-report-current counterexample \
    models/executors/ParslTaskVineDuplicateReport.cfg \
    models/executors/ParslTaskVineDuplicateReport.tla
run_case taskvine-duplicate-report-fixed pass \
    models/executors/ParslTaskVineDuplicateReportFixed.cfg \
    models/executors/ParslTaskVineDuplicateReport.tla
run_case workqueue-duplicate-report-current counterexample \
    models/executors/ParslWorkQueueDuplicateReport.cfg \
    models/executors/ParslWorkQueueDuplicateReport.tla
run_case workqueue-duplicate-report-fixed pass \
    models/executors/ParslWorkQueueDuplicateReportFixed.cfg \
    models/executors/ParslWorkQueueDuplicateReport.tla
run_case results-incoming-close-current counterexample \
    models/executors/ParslResultsIncomingCloseRaceCurrent.cfg \
    models/executors/ParslResultsIncomingCloseRace.tla
run_case results-incoming-close-fixed pass \
    models/executors/ParslResultsIncomingCloseRaceFixed.cfg \
    models/executors/ParslResultsIncomingCloseRace.tla
run_case googlecloud-cancel-current counterexample \
    models/providers/ParslGoogleCloudCancel.cfg \
    models/providers/ParslGoogleCloudCancel.tla
run_case googlecloud-cancel-fixed pass \
    models/providers/ParslGoogleCloudCancelFixed.cfg \
    models/providers/ParslGoogleCloudCancel.tla
run_case googlecloud-cancel-failure pass \
    models/providers/ParslGoogleCloudCancelFailure.cfg \
    models/providers/ParslGoogleCloudCancel.tla
run_case monitoring-task-insert-current counterexample \
    models/monitoring/ParslMonitoringTaskInsertBookkeepingCurrent.cfg \
    models/monitoring/ParslMonitoringTaskInsertBookkeeping.tla
run_case monitoring-task-insert-fixed pass \
    models/monitoring/ParslMonitoringTaskInsertBookkeepingFixed.cfg \
    models/monitoring/ParslMonitoringTaskInsertBookkeeping.tla
run_case monitoring-try-insert-current counterexample \
    models/monitoring/ParslMonitoringTryInsertBookkeepingCurrent.cfg \
    models/monitoring/ParslMonitoringTryInsertBookkeeping.tla
run_case monitoring-try-insert-fixed pass \
    models/monitoring/ParslMonitoringTryInsertBookkeepingFixed.cfg \
    models/monitoring/ParslMonitoringTryInsertBookkeeping.tla
run_case tasks-outgoing-close-current counterexample \
    models/executors/ParslTasksOutgoingCloseRaceCurrent.cfg \
    models/executors/ParslTasksOutgoingCloseRace.tla
run_case tasks-outgoing-close-fixed pass \
    models/executors/ParslTasksOutgoingCloseRaceFixed.cfg \
    models/executors/ParslTasksOutgoingCloseRace.tla
run_case task-transport-close-current counterexample \
    models/serialization/ParslTaskTransportCloseRaceCurrent.cfg \
    models/serialization/ParslTaskTransportCloseRace.tla
run_case task-transport-close-fixed pass \
    models/serialization/ParslTaskTransportCloseRaceFixed.cfg \
    models/serialization/ParslTaskTransportCloseRace.tla
run_case file-bytes-transfer pass \
    models/staging/ParslFileBytes.cfg \
    models/staging/ParslFileBytes.tla
run_case file-corruption-small pass \
    models/core/ParslFileCorruptionSmall.cfg \
    models/core/ParslAbstract.tla
run_case input-corruption pass \
    models/staging/ParslInputCorruption.cfg \
    models/core/ParslAbstract.tla
run_case file-transfer-retry-current counterexample \
    models/staging/ParslFileTransferRetryCurrent.cfg \
    models/staging/ParslFileTransferRetry.tla
run_case file-transfer-retry-fixed pass \
    models/staging/ParslFileTransferRetryFixed.cfg \
    models/staging/ParslFileTransferRetry.tla
run_case datafuture-transfer-current counterexample \
    models/staging/ParslDataFutureTransfer.cfg \
    models/staging/ParslDataFutureTransfer.tla
run_case datafuture-transfer-fixed pass \
    models/staging/ParslDataFutureTransferFixed.cfg \
    models/staging/ParslDataFutureTransfer.tla
run_case http-status-current counterexample \
    models/staging/ParslHTTPStatusValidationCurrent.cfg \
    models/staging/ParslHTTPStatusValidation.tla
run_case http-status-fixed pass \
    models/staging/ParslHTTPStatusValidationFixed.cfg \
    models/staging/ParslHTTPStatusValidation.tla
run_case http-status-success pass \
    models/staging/ParslHTTPStatusValidationSuccess.cfg \
    models/staging/ParslHTTPStatusValidation.tla
run_case rsync-partial-current counterexample \
    models/staging/ParslRsyncPartialCleanupCurrent.cfg \
    models/staging/ParslRsyncPartialCleanup.tla
run_case rsync-partial-fixed pass \
    models/staging/ParslRsyncPartialCleanupFixed.cfg \
    models/staging/ParslRsyncPartialCleanup.tla
run_case stageout-future-separate pass \
    models/staging/ParslStageOutFuture.cfg \
    models/staging/ParslStageOutFuture.tla
run_case stageout-future-intask pass \
    models/staging/ParslStageOutInTask.cfg \
    models/staging/ParslStageOutFuture.tla
run_case stageout-future-none pass \
    models/staging/ParslStageOutNone.cfg \
    models/staging/ParslStageOutFuture.tla
run_case monitoring-db-core pass \
    models/monitoring/ParslMonitoringDB.cfg \
    models/monitoring/ParslMonitoringDB.tla
run_case monitoring-db-insert-current counterexample \
    models/monitoring/ParslMonitoringDBInsert.cfg \
    models/monitoring/ParslMonitoringDBInsert.tla
run_case monitoring-db-insert-fixed pass \
    models/monitoring/ParslMonitoringDBInsertFixed.cfg \
    models/monitoring/ParslMonitoringDBInsert.tla
run_case monitoring-db-insert-present pass \
    models/monitoring/ParslMonitoringDBInsertPresent.cfg \
    models/monitoring/ParslMonitoringDBInsert.tla
run_case executor-provider-core pass \
    models/executors/ParslExecutorProvider.cfg \
    models/executors/ParslExecutorProvider.tla
run_case provider-executor-bridge pass \
    models/executors/ParslProviderExecutorBridge.cfg \
    models/executors/ParslProviderExecutorBridge.tla
run_case executor-provider-lifecycle-current counterexample \
    models/executors/ParslExecutorProviderLifecycle.cfg \
    models/executors/ParslExecutorProviderLifecycle.tla
run_case executor-provider-lifecycle-fixed pass \
    models/executors/ParslExecutorProviderLifecycleFixed.cfg \
    models/executors/ParslExecutorProviderLifecycle.tla
run_case mpi-backlog-retry-current counterexample \
    models/executors/ParslMPIBacklogRetryCurrent.cfg \
    models/executors/ParslMPIBacklogRetry.tla
run_case mpi-backlog-retry-fixed pass \
    models/executors/ParslMPIBacklogRetryFixed.cfg \
    models/executors/ParslMPIBacklogRetry.tla
run_case mpi-no-resource-result-current counterexample \
    models/executors/ParslMPINoResourceResultCurrent.cfg \
    models/executors/ParslMPINoResourceResult.tla
run_case mpi-no-resource-result-fixed pass \
    models/executors/ParslMPINoResourceResultFixed.cfg \
    models/executors/ParslMPINoResourceResult.tla
run_case cluster-provider-unknown-job-current counterexample \
    models/providers/ParslClusterProviderUnknownJob.cfg \
    models/providers/ParslClusterProviderUnknownJob.tla
run_case cluster-provider-unknown-job-fixed pass \
    models/providers/ParslClusterProviderUnknownJobFixed.cfg \
    models/providers/ParslClusterProviderUnknownJob.tla
run_case lsf-resource-validation-current counterexample \
    models/providers/ParslLSFResourceValidationCurrent.cfg \
    models/providers/ParslLSFResourceValidation.tla
run_case lsf-resource-validation-fixed pass \
    models/providers/ParslLSFResourceValidationFixed.cfg \
    models/providers/ParslLSFResourceValidation.tla
run_case lsf-resource-validation-valid pass \
    models/providers/ParslLSFResourceValidationValid.cfg \
    models/providers/ParslLSFResourceValidation.tla
run_case flux-submission-failure pass \
    models/executors/ParslFluxSubmissionFailure.cfg \
    models/executors/ParslFluxSubmissionFailure.tla
run_case taskvine-results pass \
    models/executors/ParslTaskVineResults.cfg \
    models/executors/ParslTaskVineResults.tla
run_case workqueue-shutdown pass \
    models/executors/ParslWorkQueueShutdown.cfg \
    models/executors/ParslWorkQueueShutdown.tla
run_case taskvine-shutdown pass \
    models/executors/ParslTaskVineShutdown.cfg \
    models/executors/ParslTaskVineShutdown.tla
run_case join-full pass \
    models/dataflow/ParslJoinFull.cfg \
    models/dataflow/ParslJoinFull.tla
run_case join-end-to-end pass \
    models/dataflow/ParslJoinEndToEnd.cfg \
    models/dataflow/ParslJoinEndToEnd.tla
run_case join-monitoring pass \
    models/dataflow/ParslJoinMonitoring.cfg \
    models/dataflow/ParslJoinMonitoring.tla
run_case join-app-core pass \
    models/dataflow/ParslJoinApp.cfg \
    models/dataflow/ParslJoinApp.tla
run_case join-complete-current counterexample \
    models/dataflow/ParslJoinComplete.cfg \
    models/dataflow/ParslJoinComplete.tla
run_case join-complete-fixed pass \
    models/dataflow/ParslJoinCompleteFixed.cfg \
    models/dataflow/ParslJoinComplete.tla
run_case join-callback-race pass \
    models/dataflow/ParslJoinCallbackRace.cfg \
    models/dataflow/ParslJoinCallbackRace.tla
run_case join-immediate-callback pass \
    models/dataflow/ParslJoinImmediateCallback.cfg \
    models/dataflow/ParslJoinImmediateCallback.tla
run_case join-return-equality-current counterexample \
    models/dataflow/ParslJoinReturnEqualityCurrent.cfg \
    models/dataflow/ParslJoinReturnEquality.tla
run_case join-return-equality-fixed pass \
    models/dataflow/ParslJoinReturnEqualityFixed.cfg \
    models/dataflow/ParslJoinReturnEquality.tla
run_case join-failure-aggregation pass \
    models/dataflow/ParslJoinFailureAggregation.cfg \
    models/dataflow/ParslJoinFailureAggregation.tla
run_case join-error-root-cause pass \
    models/dataflow/ParslJoinErrorRootCause.cfg \
    models/dataflow/ParslJoinErrorRootCause.tla
run_case task-status-future-ordering-current counterexample \
    models/dataflow/ParslTaskStatusFutureOrderingCurrent.cfg \
    models/dataflow/ParslTaskStatusFutureOrdering.tla
run_case task-status-future-ordering-fixed pass \
    models/dataflow/ParslTaskStatusFutureOrderingFixed.cfg \
    models/dataflow/ParslTaskStatusFutureOrdering.tla
run_case task-status-future-ordering-valid pass \
    models/dataflow/ParslTaskStatusFutureOrderingValid.cfg \
    models/dataflow/ParslTaskStatusFutureOrdering.tla
run_case monitoring-malformed-worker-current counterexample \
    models/monitoring/ParslMonitoringMalformedWorkerMessageCurrent.cfg \
    models/monitoring/ParslMonitoringMalformedWorkerMessage.tla
run_case monitoring-malformed-worker-fixed pass \
    models/monitoring/ParslMonitoringMalformedWorkerMessageFixed.cfg \
    models/monitoring/ParslMonitoringMalformedWorkerMessage.tla
run_case monitoring-close-idempotence-current counterexample \
    models/monitoring/ParslMonitoringCloseIdempotenceCurrent.cfg \
    models/monitoring/ParslMonitoringCloseIdempotence.tla
run_case monitoring-close-idempotence-fixed pass \
    models/monitoring/ParslMonitoringCloseIdempotenceFixed.cfg \
    models/monitoring/ParslMonitoringCloseIdempotence.tla
run_case monitoring-shutdown-race-current counterexample \
    models/monitoring/ParslMonitoringShutdownRaceCurrent.cfg \
    models/monitoring/ParslMonitoringShutdownRace.tla
run_case monitoring-shutdown-race-fixed pass \
    models/monitoring/ParslMonitoringShutdownRaceFixed.cfg \
    models/monitoring/ParslMonitoringShutdownRace.tla
run_case monitoring-shutdown-drain pass \
    models/monitoring/ParslMonitoringShutdownDrain.cfg \
    models/monitoring/ParslMonitoringShutdownDrain.tla
run_case monitoring-deferred-multiplicity-current counterexample \
    models/monitoring/ParslMonitoringDeferredMultiplicityCurrent.cfg \
    models/monitoring/ParslMonitoringDeferredMultiplicity.tla
run_case monitoring-deferred-multiplicity-fixed pass \
    models/monitoring/ParslMonitoringDeferredMultiplicityFixed.cfg \
    models/monitoring/ParslMonitoringDeferredMultiplicity.tla
run_case monitoring-deferred pass \
    models/monitoring/ParslMonitoringDeferred.cfg \
    models/monitoring/ParslMonitoringDeferred.tla
run_case monitoring-dispatch-envelope-current counterexample \
    models/monitoring/ParslMonitoringDispatchEnvelopeCurrent.cfg \
    models/monitoring/ParslMonitoringDispatchEnvelope.tla
run_case monitoring-dispatch-envelope-fixed pass \
    models/monitoring/ParslMonitoringDispatchEnvelopeFixed.cfg \
    models/monitoring/ParslMonitoringDispatchEnvelope.tla
run_case monitoring-dispatch-envelope-valid pass \
    models/monitoring/ParslMonitoringDispatchEnvelopeValid.cfg \
    models/monitoring/ParslMonitoringDispatchEnvelope.tla
run_case monitoring-hub-close pass \
    models/monitoring/ParslMonitoringHubClose.cfg \
    models/monitoring/ParslMonitoringHubClose.tla
run_case worker-contact-timeout pass \
    models/clock/ParslWorkerContactTimeout.cfg \
    models/clock/ParslWorkerContactTimeout.tla
run_case timed-heartbeat-current counterexample \
    models/clock/ParslTimedHeartbeat.cfg \
    models/clock/ParslTimedHeartbeat.tla
run_case timed-heartbeat-fixed pass \
    models/clock/ParslTimedHeartbeatFixed.cfg \
    models/clock/ParslTimedHeartbeat.tla
run_case worker-contact-rollback-current counterexample \
    models/clock/ParslWorkerContactClockRollbackCurrent.cfg \
    models/clock/ParslWorkerContactClockRollback.tla
run_case worker-contact-rollback-fixed pass \
    models/clock/ParslWorkerContactClockRollbackFixed.cfg \
    models/clock/ParslWorkerContactClockRollback.tla
run_case htex-unknown-manager-heartbeat pass \
    models/executors/ParslHtexUnknownManagerHeartbeat.cfg \
    models/executors/ParslHtexUnknownManagerMessage.tla
run_case htex-unknown-manager-result pass \
    models/executors/ParslHtexUnknownManagerResult.cfg \
    models/executors/ParslHtexUnknownManagerMessage.tla
run_case htex-unknown-task-result-current counterexample \
    models/executors/ParslHtexUnknownTaskResultCurrent.cfg \
    models/executors/ParslHtexUnknownTaskResult.tla
run_case htex-unknown-task-result-fixed pass \
    models/executors/ParslHtexUnknownTaskResultFixed.cfg \
    models/executors/ParslHtexUnknownTaskResult.tla
run_case htex-manager-message-heartbeat pass \
    models/executors/ParslHtexManagerMessageHeartbeat.cfg \
    models/executors/ParslHtexManagerMessage.tla
run_case htex-manager-message-malformed pass \
    models/executors/ParslHtexManagerMessageMalformed.cfg \
    models/executors/ParslHtexManagerMessage.tla
run_case provider-status-batch pass \
    models/providers/ParslProviderStatusBatch.cfg \
    models/providers/ParslProviderStatusBatch.tla
run_case stage-in-ordering-current counterexample \
    models/staging/ParslDataManagerStageInOrderingCurrent.cfg \
    models/staging/ParslDataManagerStageInOrdering.tla
run_case stage-in-ordering-fixed pass \
    models/staging/ParslDataManagerStageInOrderingFixed.cfg \
    models/staging/ParslDataManagerStageInOrdering.tla
run_case stage-out-ordering-current counterexample \
    models/staging/ParslDataManagerStageOutOrderingCurrent.cfg \
    models/staging/ParslDataManagerStageOutOrdering.tla
run_case stage-out-ordering-fixed pass \
    models/staging/ParslDataManagerStageOutOrderingFixed.cfg \
    models/staging/ParslDataManagerStageOutOrdering.tla
run_case serialization-envelope-current counterexample \
    models/serialization/ParslSerializationEnvelopeMalformedCurrent.cfg \
    models/serialization/ParslSerializationEnvelopeMalformed.tla
run_case serialization-envelope-fixed pass \
    models/serialization/ParslSerializationEnvelopeMalformedFixed.cfg \
    models/serialization/ParslSerializationEnvelopeMalformed.tla
run_case serialization-binary-payload pass \
    models/serialization/ParslSerializationBinaryPayload.cfg \
    models/serialization/ParslSerializationBinaryPayload.tla
run_case serialization-frame-count-current counterexample \
    models/serialization/ParslSerializationFrameCountCurrent.cfg \
    models/serialization/ParslSerializationFrameCount.tla
run_case serialization-frame-count-fixed pass \
    models/serialization/ParslSerializationFrameCountFixed.cfg \
    models/serialization/ParslSerializationFrameCount.tla
run_case serialization-frame-count-normal pass \
    models/serialization/ParslSerializationFrameCountNormal.cfg \
    models/serialization/ParslSerializationFrameCount.tla
run_case serialization-short-frame-current counterexample \
    models/serialization/ParslSerializationShortFrameCountCurrent.cfg \
    models/serialization/ParslSerializationShortFrameCount.tla
run_case serialization-short-frame-fixed pass \
    models/serialization/ParslSerializationShortFrameCountFixed.cfg \
    models/serialization/ParslSerializationShortFrameCount.tla
run_case serialization-negative-length-current counterexample \
    models/serialization/ParslSerializationNegativeLengthCurrent.cfg \
    models/serialization/ParslSerializationNegativeLength.tla
run_case serialization-negative-length-fixed pass \
    models/serialization/ParslSerializationNegativeLengthFixed.cfg \
    models/serialization/ParslSerializationNegativeLength.tla
run_case serialization-negative-length-valid pass \
    models/serialization/ParslSerializationNegativeLengthValid.cfg \
    models/serialization/ParslSerializationNegativeLength.tla
run_case serialization-truncated-length-current counterexample \
    models/serialization/ParslSerializationTruncatedLengthCurrent.cfg \
    models/serialization/ParslSerializationTruncatedLength.tla
run_case serialization-truncated-length-fixed pass \
    models/serialization/ParslSerializationTruncatedLengthFixed.cfg \
    models/serialization/ParslSerializationTruncatedLength.tla
run_case serialization-length-current counterexample \
    models/serialization/ParslSerializationLength.cfg \
    models/serialization/ParslSerializationLength.tla
run_case serialization-length-fixed pass \
    models/serialization/ParslSerializationLengthFixed.cfg \
    models/serialization/ParslSerializationLength.tla
run_case serialization-snapshot pass \
    models/serialization/ParslSerializationSnapshot.cfg \
    models/serialization/ParslSerializationSnapshot.tla
run_case serialization-plugin-cache pass \
    models/serialization/ParslSerializationPluginCache.cfg \
    models/serialization/ParslSerializationPluginCache.tla
run_case serialization-plugin-failure-cache-current counterexample \
    models/serialization/ParslSerializationPluginFailureCacheCurrent.cfg \
    models/serialization/ParslSerializationPluginFailureCache.tla
run_case serialization-plugin-failure-cache-fixed pass \
    models/serialization/ParslSerializationPluginFailureCacheFixed.cfg \
    models/serialization/ParslSerializationPluginFailureCache.tla
run_case serialization-plugin-error-current counterexample \
    models/serialization/ParslSerializationPluginError.cfg \
    models/serialization/ParslSerializationPluginError.tla
run_case serialization-plugin-error-fixed pass \
    models/serialization/ParslSerializationPluginErrorFixed.cfg \
    models/serialization/ParslSerializationPluginError.tla
run_case serialization-fallback-primary pass \
    models/serialization/ParslSerializationFallbackPrimary.cfg \
    models/serialization/ParslSerializationFallback.tla
run_case serialization-fallback-secondary pass \
    models/serialization/ParslSerializationFallbackSecondary.cfg \
    models/serialization/ParslSerializationFallback.tla
run_case serialization-fallback-failure pass \
    models/serialization/ParslSerializationFallbackFailure.cfg \
    models/serialization/ParslSerializationFallback.tla
run_case nested-join pass \
    models/dataflow/ParslNestedJoin.cfg \
    models/dataflow/ParslNestedJoin.tla
