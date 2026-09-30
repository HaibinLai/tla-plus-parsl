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
run_case htex-priority-current counterexample \
    models/executors/ParslHtexTaskPriorityTypeCurrent.cfg \
    models/executors/ParslHtexTaskPriorityType.tla
run_case htex-priority-fixed pass \
    models/executors/ParslHtexTaskPriorityTypeFixed.cfg \
    models/executors/ParslHtexTaskPriorityType.tla
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
run_case condor-malformed-line-current counterexample \
    models/providers/ParslCondorMalformedStatusLineCurrent.cfg \
    models/providers/ParslCondorMalformedStatusLine.tla
run_case condor-malformed-line-fixed pass \
    models/providers/ParslCondorMalformedStatusLineFixed.cfg \
    models/providers/ParslCondorMalformedStatusLine.tla
run_case gridengine-duplicate-current counterexample \
    models/providers/ParslGridEngineDuplicateStatusCurrent.cfg \
    models/providers/ParslGridEngineDuplicateStatus.tla
run_case gridengine-duplicate-fixed pass \
    models/providers/ParslGridEngineDuplicateStatusFixed.cfg \
    models/providers/ParslGridEngineDuplicateStatus.tla
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
run_case radical-bulk-shutdown-current counterexample \
    models/executors/ParslRadicalPilotBulkShutdownCurrent.cfg \
    models/executors/ParslRadicalPilotBulkShutdown.tla
run_case radical-bulk-shutdown-fixed pass \
    models/executors/ParslRadicalPilotBulkShutdownFixed.cfg \
    models/executors/ParslRadicalPilotBulkShutdown.tla
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
run_case globus-transfer-timeout-current counterexample \
    models/staging/ParslGlobusTransferTimeoutCurrent.cfg \
    models/staging/ParslGlobusTransferTimeout.tla
run_case globus-transfer-timeout-fixed pass \
    models/staging/ParslGlobusTransferTimeoutFixed.cfg \
    models/staging/ParslGlobusTransferTimeout.tla
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
run_case file-transfer-retry-current counterexample \
    models/staging/ParslFileTransferRetryCurrent.cfg \
    models/staging/ParslFileTransferRetry.tla
run_case file-transfer-retry-fixed pass \
    models/staging/ParslFileTransferRetryFixed.cfg \
    models/staging/ParslFileTransferRetry.tla
run_case monitoring-db-core pass \
    models/monitoring/ParslMonitoringDB.cfg \
    models/monitoring/ParslMonitoringDB.tla
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
run_case join-full pass \
    models/dataflow/ParslJoinFull.cfg \
    models/dataflow/ParslJoinFull.tla
run_case join-end-to-end pass \
    models/dataflow/ParslJoinEndToEnd.cfg \
    models/dataflow/ParslJoinEndToEnd.tla
run_case join-monitoring pass \
    models/dataflow/ParslJoinMonitoring.cfg \
    models/dataflow/ParslJoinMonitoring.tla
