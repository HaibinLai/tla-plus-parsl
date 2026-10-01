#!/usr/bin/env bash

# Run the small, executable first-stage abstractions that span the main Parsl
# boundaries.  This is intentionally separate from tlc_recent_models.sh: it
# is a fast regression target for the foundational model set.

set -euo pipefail

JAVA_BIN=${JAVA_BIN:-java}
TLA_JAR=${TLA_JAR:-tla2tools.jar}
TLC_SIMULATE=${TLC_SIMULATE:-1000}
TLC_CASE_START=${TLC_CASE_START:-1}
TLC_CASE_LIMIT=${TLC_CASE_LIMIT:-0}
CASE_COUNT=0

if [[ "$JAVA_BIN" == "java" ]] && ! command -v java >/dev/null 2>&1; then
    JAVA_BIN=$(find /tmp -path '*/jdk-*/bin/java' -type f -perm -u+x -print -quit 2>/dev/null)
fi
if [[ "$TLA_JAR" == "tla2tools.jar" ]] && [[ ! -f "$TLA_JAR" ]]; then
    TLA_JAR=$(find /tmp -path '*/tla2tools.jar' -type f -print -quit 2>/dev/null)
fi
if [[ -z "$JAVA_BIN" || -z "$TLA_JAR" || ! -x "$JAVA_BIN" || ! -f "$TLA_JAR" ]]; then
    echo "Unable to locate Java/TLC. Set JAVA_BIN and TLA_JAR explicitly." >&2
    exit 2
fi

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

run_case() {
    local label=$1
    local config=$2
    local spec=$3
    local log="$WORK_DIR/${label}.log"

    CASE_COUNT=$((CASE_COUNT + 1))
    if [[ "$CASE_COUNT" -lt "$TLC_CASE_START" ]]; then
        return 0
    fi
    if [[ "$TLC_CASE_LIMIT" -gt 0 && "$CASE_COUNT" -gt "$TLC_CASE_LIMIT" ]]; then
        exit 0
    fi

    "$JAVA_BIN" -cp "$TLA_JAR" tlc2.TLC -simulate num="$TLC_SIMULATE" \
        -metadir "$WORK_DIR/meta-$label" \
        -config "$config" "$spec" >"$log" 2>&1

    local summary
    summary=$(grep -E '[0-9]+ states (generated|checked)' "$log" | tail -1 || true)
    printf 'PASS %-30s %s\n' "$label" "$summary"
}

run_case dag-retry \
    models/core/ParslEndToEndSmoke.cfg \
    models/core/ParslEndToEnd.tla
run_case pipeline-smoke \
    models/core/ParslPipelineSmoke.cfg \
    models/core/ParslPipeline.tla
run_case pipeline-timed \
    models/core/ParslPipelineTimedFixed.cfg \
    models/core/ParslPipelineTimed.tla
run_case content-file-pipeline \
    models/core/ParslContentFilePipeline.cfg \
    models/core/ParslContentFilePipeline.tla
run_case timeout-retry-stale-result \
    models/core/ParslTimeoutRetryStaleResult.cfg \
    models/core/ParslTimeoutRetryStaleResult.tla
run_case join-retry-stale-result \
    models/core/ParslJoinRetryStaleResultFixed.cfg \
    models/core/ParslJoinRetryStaleResult.tla
run_case join-provider-monitoring \
    models/core/ParslJoinProviderMonitoringFixed.cfg \
    models/core/ParslJoinProviderMonitoring.tla
run_case join-zmq-retry \
    models/core/ParslJoinZMQRetryFixed.cfg \
    models/core/ParslJoinZMQRetry.tla
run_case join-file-staging \
    models/core/ParslJoinFileStagingFixed.cfg \
    models/core/ParslJoinFileStaging.tla
run_case join-monitoring-db \
    models/core/ParslJoinMonitoringDBFixed.cfg \
    models/core/ParslJoinMonitoringDB.tla
run_case join-heartbeat-retry \
    models/core/ParslJoinHeartbeatRetryFixed.cfg \
    models/core/ParslJoinHeartbeatRetry.tla
run_case join-stage-retry \
    models/core/ParslJoinStageRetryFixed.cfg \
    models/core/ParslJoinStageRetry.tla
run_case join-timed-monitoring-cancel \
    models/dataflow/ParslJoinTimedMonitoringCancelFixed.cfg \
    models/dataflow/ParslJoinTimedMonitoring.tla
run_case integrated-abstract \
    models/core/ParslAbstractSmoke.cfg \
    models/core/ParslAbstract.tla
run_case integrated-abstract-full \
    models/core/ParslAbstractFullSmoke.cfg \
    models/core/ParslAbstract.tla
run_case integrated-abstract-join \
    models/core/ParslAbstractJoinSmoke.cfg \
    models/core/ParslAbstract.tla
run_case callable-object-snapshot \
    models/serialization/ParslFunctionObjectContents.cfg \
    models/serialization/ParslFunctionObjectContents.tla
run_case callable-object-transport \
    models/serialization/ParslFunctionObjectTransport.cfg \
    models/serialization/ParslFunctionObjectTransport.tla
run_case htex-result-forwarding \
    models/serialization/ParslHtexResultForwardingFixed.cfg \
    models/serialization/ParslHtexResultForwarding.tla
run_case htex-result-queue \
    models/executors/ParslHtexResultQueueFixed.cfg \
    models/executors/ParslHtexResultQueue.tla
run_case file-bytes-transfer \
    models/staging/ParslFileBytesSmoke.cfg \
    models/staging/ParslFileBytes.tla
run_case heartbeat \
    models/clock/ParslTimedHeartbeatSmokeFixed.cfg \
    models/clock/ParslTimedHeartbeat.tla
run_case heartbeat-full-horizon \
    models/clock/ParslTimedHeartbeatFixed.cfg \
    models/clock/ParslTimedHeartbeat.tla
run_case concurrent-timeouts \
    models/clock/ParslConcurrentTimeouts.cfg \
    models/clock/ParslConcurrentTimeouts.tla
run_case periodic-timer \
    models/clock/ParslPeriodicTimer.cfg \
    models/clock/ParslPeriodicTimer.tla
run_case htex-shutdown-timeout \
    models/clock/ParslHtexShutdownTimeout.cfg \
    models/clock/ParslHtexShutdownTimeout.tla
run_case heartbeat-parameter-validation \
    models/clock/ParslHeartbeatParameterValidationFixed.cfg \
    models/clock/ParslHeartbeatParameterValidation.tla
run_case worker-contact-timeout \
    models/clock/ParslWorkerContactTimeout.cfg \
    models/clock/ParslWorkerContactTimeout.tla
run_case timeout-monitoring \
    models/clock/ParslTimeoutMonitoringFixed.cfg \
    models/clock/ParslTimeoutMonitoring.tla
run_case timeout-timer-error \
    models/clock/ParslTimeoutTimerError.cfg \
    models/clock/ParslTimeoutTimer.tla
run_case monitoring-db \
    models/monitoring/ParslMonitoringDBSmoke.cfg \
    models/monitoring/ParslMonitoringDB.tla
run_case monitoring-resource-history \
    models/monitoring/ParslMonitoringResourceHistory.cfg \
    models/monitoring/ParslMonitoringResourceHistory.tla
run_case monitoring-internal-queue-drain \
    models/monitoring/ParslMonitoringInternalQueueDrainFixed.cfg \
    models/monitoring/ParslMonitoringInternalQueueDrain.tla
run_case join-app \
    models/dataflow/ParslJoinApp.cfg \
    models/dataflow/ParslJoinApp.tla
run_case zmq-serialization \
    models/serialization/ParslZMQSerializationEndToEndSmoke.cfg \
    models/serialization/ParslZMQSerializationEndToEnd.tla
run_case htex-submit-queue-cleanup \
    models/executors/ParslHtexSubmitLifecycleQueueFailureFixed.cfg \
    models/executors/ParslHtexSubmitLifecycle.tla
run_case htex-result-decode-cleanup \
    models/executors/ParslHtexResultDecodeFailureFixed.cfg \
    models/executors/ParslHtexResultDecodeFailure.tla
run_case htex-ambiguous-result-rejection \
    models/executors/ParslHtexAmbiguousResultFixed.cfg \
    models/executors/ParslHtexAmbiguousResult.tla
run_case htex-address-probe-timeout \
    models/executors/ParslHtexAddressProbeTimeoutFixed.cfg \
    models/executors/ParslHtexAddressProbeTimeout.tla
run_case htex-unknown-result-type \
    models/executors/ParslHtexUnknownResultTypeFixed.cfg \
    models/executors/ParslHtexUnknownResultType.tla
run_case htex-watchdog-result-race \
    models/executors/ParslHtexWatchdogResultRaceFixed.cfg \
    models/executors/ParslHtexWatchdogResultRace.tla
run_case heartbeat-clock-jump \
    models/executors/ParslHeartbeatClockJumpFixed.cfg \
    models/executors/ParslHeartbeatClockJump.tla
run_case kubernetes-admission \
    models/providers/ParslKubernetesAdmissionFixed.cfg \
    models/providers/ParslKubernetesAdmission.tla
run_case kubernetes-submit-state \
    models/providers/ParslKubernetesSubmitFixed.cfg \
    models/providers/ParslKubernetesSubmit.tla
run_case torque-submit-shape \
    models/providers/ParslTorqueSubmitShapeFixed.cfg \
    models/providers/ParslTorqueSubmitShape.tla
run_case torque-tasks-per-node \
    models/providers/ParslTorqueTasksPerNodeFixed.cfg \
    models/providers/ParslTorqueTasksPerNode.tla
run_case local-pid-admission \
    models/providers/ParslLocalPidAdmissionFixed.cfg \
    models/providers/ParslLocalPidAdmission.tla
run_case local-tasks-per-node \
    models/providers/ParslLocalTasksPerNodeFixed.cfg \
    models/providers/ParslLocalTasksPerNode.tla
run_case aws-status-shape \
    models/providers/ParslAwsStatusResponseShapeFixed.cfg \
    models/providers/ParslAwsStatusResponseShape.tla
run_case aws-provider-status-missing \
    models/providers/ParslAWSProviderStatusFixed.cfg \
    models/providers/ParslAWSProviderStatus.tla
run_case aws-instance-state-shape \
    models/providers/ParslAwsInstanceStateShapeFixed.cfg \
    models/providers/ParslAwsInstanceStateShape.tla
run_case google-zone-response-shape \
    models/providers/ParslGoogleCloudZoneResponseShapeFixed.cfg \
    models/providers/ParslGoogleCloudZoneResponseShape.tla
run_case provider-executor-monitoring \
    models/executors/ParslProviderExecutorTimedMonitoringFixed.cfg \
    models/executors/ParslProviderExecutorTimedMonitoring.tla
run_case provider-task-scale-retry \
    models/executors/ParslProviderTaskScaleRetryFixed.cfg \
    models/executors/ParslProviderTaskScaleRetry.tla
run_case provider-staging-admission \
    models/core/ParslProviderStagingAdmissionFixed.cfg \
    models/core/ParslProviderStagingAdmission.tla
run_case provider-poll-clock-rollback \
    models/providers/ParslProviderPollClockRollbackFixed.cfg \
    models/providers/ParslProviderPollClockRollback.tla
run_case provider-polling \
    models/providers/ParslProviderPolling.cfg \
    models/providers/ParslProviderPolling.tla
run_case provider-result-retry-race \
    models/core/ParslProviderResultRetryRaceFixed.cfg \
    models/core/ParslProviderResultRetryRace.tla
run_case provider-cancel-future \
    models/core/ParslProviderCancelFutureFixed.cfg \
    models/core/ParslProviderCancelFuture.tla
run_case provider-cancel-retry-monitoring \
    models/core/ParslProviderCancelRetryMonitoringFixed.cfg \
    models/core/ParslProviderCancelRetryMonitoring.tla
run_case join-cancel-retry-generation \
    models/core/ParslJoinCancelRetryGenerationFixed.cfg \
    models/core/ParslJoinCancelRetryGeneration.tla
run_case join-future-propagation \
    models/dataflow/ParslJoinCompleteFixed.cfg \
    models/dataflow/ParslJoinComplete.tla
run_case triple-nested-join \
    models/dataflow/ParslTripleNestedJoinFixed.cfg \
    models/dataflow/ParslTripleNestedJoin.tla
run_case provider-result-monitoring-db \
    models/core/ParslProviderResultMonitoringDBFixed.cfg \
    models/core/ParslProviderResultMonitoringDB.tla
run_case join-provider-result-monitoring-db \
    models/core/ParslJoinProviderResultMonitoringDBFixed.cfg \
    models/core/ParslJoinProviderResultMonitoringDB.tla
run_case join-full \
    models/dataflow/ParslJoinFull.cfg \
    models/dataflow/ParslJoinFull.tla
run_case monitoring-batch-atomicity \
    models/monitoring/ParslMonitoringBatchAtomicityFixed.cfg \
    models/monitoring/ParslMonitoringBatchAtomicity.tla
run_case monitoring-persistent-retry \
    models/monitoring/ParslMonitoringPersistentRetryFixed.cfg \
    models/monitoring/ParslMonitoringPersistentRetry.tla
run_case monitoring-db-retry-operational \
    models/monitoring/ParslMonitoringDBRetry.cfg \
    models/monitoring/ParslMonitoringDBRetry.tla
run_case monitoring-db-retry-integrity \
    models/monitoring/ParslMonitoringDBRetryIntegrity.cfg \
    models/monitoring/ParslMonitoringDBRetry.tla
run_case monitoring-db-permanent-insert \
    models/monitoring/ParslMonitoringDBPermanentErrorFixed.cfg \
    models/monitoring/ParslMonitoringDBPermanentError.tla
run_case monitoring-db-insert \
    models/monitoring/ParslMonitoringDBInsertFixed.cfg \
    models/monitoring/ParslMonitoringDBInsert.tla
run_case monitoring-db-permanent-update \
    models/monitoring/ParslMonitoringDBUpdatePermanentErrorFixed.cfg \
    models/monitoring/ParslMonitoringDBUpdatePermanentError.tla
run_case stage-in-ordering \
    models/staging/ParslDataManagerStageInOrderingFixed.cfg \
    models/staging/ParslDataManagerStageInOrdering.tla
run_case stage-out-ordering \
    models/staging/ParslDataManagerStageOutOrderingFixed.cfg \
    models/staging/ParslDataManagerStageOutOrdering.tla
run_case http-content-length \
    models/staging/ParslHTTPContentLengthFixed.cfg \
    models/staging/ParslHTTPContentLength.tla
run_case rsync-path-quoting \
    models/staging/ParslRsyncQuotingFixed.cfg \
    models/staging/ParslRsyncQuoting.tla
run_case heartbeat-clock-rollback \
    models/clock/ParslHeartbeatClockRollbackFixed.cfg \
    models/clock/ParslHeartbeatClockRollback.tla
run_case htex-contact-timeout \
    models/clock/ParslHtexContactTimeoutStarvationFixed.cfg \
    models/clock/ParslHtexContactTimeoutStarvation.tla
run_case worker-contact-rollback \
    models/clock/ParslWorkerContactClockRollbackFixed.cfg \
    models/clock/ParslWorkerContactClockRollback.tla
run_case worker-initial-probe-timeout \
    models/clock/ParslWorkerInitialProbeTimeoutFixed.cfg \
    models/clock/ParslWorkerInitialProbeTimeout.tla
run_case command-deadline \
    models/executors/ParslCommandDeadlineFixed.cfg \
    models/executors/ParslCommandDeadline.tla
run_case callable-argument-alias \
    models/serialization/ParslCallableArgumentAliasFixed.cfg \
    models/serialization/ParslCallableArgumentAlias.tla
run_case python-nested-alias \
    models/serialization/ParslPythonNestedAliasFixed.cfg \
    models/serialization/ParslPythonNestedAlias.tla
run_case python-cyclic-object \
    models/serialization/ParslPythonCyclic.cfg \
    models/serialization/ParslPython.tla
run_case closure-memo-snapshot \
    models/serialization/ParslCallableClosureMemoFixed.cfg \
    models/serialization/ParslCallableClosureMemo.tla
run_case object-snapshot-retry \
    models/serialization/ParslObjectSnapshotRetryFixed.cfg \
    models/serialization/ParslObjectSnapshotRetry.tla
run_case message-correlation \
    models/serialization/ParslMessageCorrelationFixed.cfg \
    models/serialization/ParslMessageCorrelation.tla
run_case zmq-ack-retry \
    models/serialization/ParslZMQAckRetryFixed.cfg \
    models/serialization/ParslZMQAckRetry.tla
run_case serializer-header-consistency \
    models/serialization/ParslSerializerHeaderConsistencyFixed.cfg \
    models/serialization/ParslSerializerHeaderConsistency.tla
run_case serializer-fallback-primary \
    models/serialization/ParslSerializationFallbackPrimary.cfg \
    models/serialization/ParslSerializationFallback.tla
run_case serializer-fallback-failure \
    models/serialization/ParslSerializationFallbackFailure.cfg \
    models/serialization/ParslSerializationFallback.tla
run_case serializer-plugin-failure-cache \
    models/serialization/ParslSerializationPluginFailureCacheFixed.cfg \
    models/serialization/ParslSerializationPluginFailureCache.tla
run_case serializer-registry \
    models/serialization/ParslSerializerRegistryFixed.cfg \
    models/serialization/ParslSerializerRegistry.tla
run_case callable-deserialize-cache \
    models/serialization/ParslCallableDeserializeCacheFixed.cfg \
    models/serialization/ParslCallableDeserializeCache.tla
run_case callable-serializer-cache \
    models/serialization/ParslCallableSerializerCacheFixed.cfg \
    models/serialization/ParslCallableSerializerCache.tla
run_case callable-equal-cache \
    models/serialization/ParslCallableEqualCacheFixed.cfg \
    models/serialization/ParslCallableEqualCache.tla
run_case callable-mutation-cache \
    models/serialization/ParslCallableMutationCacheFixed.cfg \
    models/serialization/ParslCallableMutationCache.tla
run_case serialization-empty-registry \
    models/serialization/ParslSerializationEmptyRegistryFixed.cfg \
    models/serialization/ParslSerializationEmptyRegistry.tla
run_case serialization-envelope-malformed \
    models/serialization/ParslSerializationEnvelopeMalformedFixed.cfg \
    models/serialization/ParslSerializationEnvelopeMalformed.tla
run_case serialization-plugin-cache \
    models/serialization/ParslSerializationPluginCache.cfg \
    models/serialization/ParslSerializationPluginCache.tla
run_case serialization-plugin-error \
    models/serialization/ParslSerializationPluginErrorFixed.cfg \
    models/serialization/ParslSerializationPluginError.tla
run_case task-transport-close-race \
    models/serialization/ParslTaskTransportCloseRaceFixed.cfg \
    models/serialization/ParslTaskTransportCloseRace.tla
run_case zmq-callable-retry \
    models/serialization/ParslZMQCallableRetryFixed.cfg \
    models/serialization/ParslZMQCallableRetry.tla
run_case message-correlation-three \
    models/serialization/ParslMessageCorrelationThree.cfg \
    models/serialization/ParslMessageCorrelationThree.tla
run_case zmq-object-snapshot \
    models/serialization/ParslZMQObjectSnapshotFixed.cfg \
    models/serialization/ParslZMQObjectSnapshot.tla
run_case command-receive-failure \
    models/serialization/ParslCommandReceiveFailureFixed.cfg \
    models/serialization/ParslCommandReceiveFailure.tla
run_case command-send-failure \
    models/serialization/ParslCommandSendFailureFixed.cfg \
    models/serialization/ParslCommandSendFailure.tla
run_case command-client-concurrent-close \
    models/serialization/ParslCommandClientConcurrentCloseFixed.cfg \
    models/serialization/ParslCommandClientConcurrentClose.tla
run_case command-client-send-timeout \
    models/executors/ParslCommandClientSendTimeout.cfg \
    models/executors/ParslCommandClientSendTimeout.tla
run_case command-client-lock-timeout \
    models/executors/ParslCommandClientLockTimeoutFixed.cfg \
    models/executors/ParslCommandClientLockTimeout.tla
run_case worker-pool-control-frame \
    models/serialization/ParslWorkerPoolControlFrameFixed.cfg \
    models/serialization/ParslWorkerPoolControlFrame.tla
run_case htex-registration-state-poisoning \
    models/serialization/ParslHtexRegistrationStatePoisoningFixed.cfg \
    models/serialization/ParslHtexRegistrationStatePoisoning.tla
run_case htex-registration-block-id \
    models/executors/ParslHtexRegistrationBlockIdFixed.cfg \
    models/executors/ParslHtexRegistrationBlockId.tla
run_case htex-registration-types \
    models/serialization/ParslHtexRegistrationTypesFixed.cfg \
    models/serialization/ParslHtexRegistrationTypes.tla
run_case htex-monitoring-batch-continuation \
    models/executors/ParslHtexMonitoringBatchContinuationFixed.cfg \
    models/executors/ParslHtexMonitoringBatchContinuation.tla
run_case htex-result-batch-continuation \
    models/executors/ParslHtexResultBatchContinuationFixed.cfg \
    models/executors/ParslHtexResultBatchContinuation.tla
run_case htex-manager-eligibility \
    models/executors/ParslHtexManagerEligibility.cfg \
    models/executors/ParslHtexManagerEligibility.tla
run_case htex-manager-selection \
    models/executors/ParslHtexManagerSelection.cfg \
    models/executors/ParslHtexManagerSelection.tla
run_case htex-manager-selection-block \
    models/executors/ParslHtexManagerSelectionBlock.cfg \
    models/executors/ParslHtexManagerSelection.tla
run_case pool-executor-callable-cache \
    models/serialization/ParslPoolExecutorCallableCacheFixed.cfg \
    models/serialization/ParslPoolExecutorCallableCache.tla
run_case results-incoming-close-race \
    models/executors/ParslResultsIncomingCloseRaceFixed.cfg \
    models/executors/ParslResultsIncomingCloseRace.tla
run_case tasks-outgoing-close-race \
    models/executors/ParslTasksOutgoingCloseRaceFixed.cfg \
    models/executors/ParslTasksOutgoingCloseRace.tla
run_case workqueue-malformed-report \
    models/executors/ParslWorkQueueMalformedReportFixed.cfg \
    models/executors/ParslWorkQueueMalformedReport.tla
run_case taskvine-malformed-report \
    models/executors/ParslTaskVineMalformedReportFixed.cfg \
    models/executors/ParslTaskVineMalformedReport.tla
run_case workqueue-start-timeout-cleanup \
    models/executors/ParslWorkQueueStartTimeoutCleanupFixed.cfg \
    models/executors/ParslWorkQueueStartTimeoutCleanup.tla
run_case workqueue-duplicate-report \
    models/executors/ParslWorkQueueDuplicateReportFixed.cfg \
    models/executors/ParslWorkQueueDuplicateReport.tla
run_case taskvine-duplicate-report \
    models/executors/ParslTaskVineDuplicateReportFixed.cfg \
    models/executors/ParslTaskVineDuplicateReport.tla
run_case slurm-foreign-job \
    models/providers/ParslSlurmForeignJobFixed.cfg \
    models/providers/ParslSlurmForeignJob.tla
run_case slurm-malformed-line \
    models/providers/ParslSlurmMalformedLineFixed.cfg \
    models/providers/ParslSlurmMalformedLine.tla
run_case slurm-tasks-per-node \
    models/providers/ParslSlurmTasksPerNodeFixed.cfg \
    models/providers/ParslSlurmTasksPerNode.tla
run_case slurm-cancel \
    models/providers/ParslSlurmCancelFixed.cfg \
    models/providers/ParslSlurmCancel.tla
run_case condor-submit-count \
    models/providers/ParslCondorSubmitCountFixed.cfg \
    models/providers/ParslCondorSubmitCount.tla
run_case condor-submit-whitespace \
    models/providers/ParslCondorSubmitWhitespaceFixed.cfg \
    models/providers/ParslCondorSubmitWhitespace.tla
run_case condor-empty-submit \
    models/providers/ParslCondorEmptySubmitFixed.cfg \
    models/providers/ParslCondorEmptySubmit.tla
run_case condor-submit-boundary \
    models/providers/ParslCondorSubmitFixed.cfg \
    models/providers/ParslCondorSubmit.tla
run_case condor-unknown-job \
    models/providers/ParslCondorUnknownJobFixed.cfg \
    models/providers/ParslCondorUnknownJob.tla
run_case condor-malformed-status \
    models/providers/ParslCondorMalformedStatusLineFixed.cfg \
    models/providers/ParslCondorMalformedStatusLine.tla
run_case condor-status-unknown \
    models/providers/ParslCondorStatusUnknownFixed.cfg \
    models/providers/ParslCondorStatusUnknown.tla
run_case pbspro-job-id-alias \
    models/providers/ParslPBSProJobIdAliasFixed.cfg \
    models/providers/ParslPBSProJobIdAlias.tla
run_case pbspro-malformed-json \
    models/providers/ParslPBSProMalformedJSONFixed.cfg \
    models/providers/ParslPBSProMalformedJSON.tla
run_case grid-engine-duplicate-status \
    models/providers/ParslGridEngineDuplicateStatusFixed.cfg \
    models/providers/ParslGridEngineDuplicateStatus.tla
run_case grid-engine-status-batch \
    models/providers/ParslGridEngineStatusBatchFixed.cfg \
    models/providers/ParslGridEngineStatusBatch.tla
run_case grid-engine-status-line \
    models/providers/ParslGridEngineStatusFixed.cfg \
    models/providers/ParslGridEngineStatus.tla
run_case grid-engine-cancel-unknown \
    models/providers/ParslGridEngineCancelFixed.cfg \
    models/providers/ParslGridEngineCancel.tla
run_case lsf-duplicate-status \
    models/providers/ParslLSFDuplicateStatusFixed.cfg \
    models/providers/ParslLSFDuplicateStatus.tla
run_case aws-unknown-instance \
    models/providers/ParslAwsUnknownInstanceFixed.cfg \
    models/providers/ParslAwsUnknownInstance.tla
run_case local-unknown-job-status \
    models/providers/ParslLocalUnknownJobStatusFixed.cfg \
    models/providers/ParslLocalUnknownJobStatus.tla
run_case local-provider-status-scope \
    models/providers/ParslLocalProviderStatusScopeFixed.cfg \
    models/providers/ParslLocalProviderStatusScope.tla
run_case local-provider-lifecycle \
    models/providers/ParslLocalProviderFixed.cfg \
    models/providers/ParslLocalProvider.tla
run_case grid-engine-missing-status \
    models/providers/ParslGridEngineMissingStatusFixed.cfg \
    models/providers/ParslGridEngineMissingStatus.tla
run_case grid-engine-empty-submit \
    models/providers/ParslGridEngineEmptySubmitFixed.cfg \
    models/providers/ParslGridEngineEmptySubmit.tla
run_case grid-engine-submit-shape \
    models/providers/ParslGridEngineSubmitShapeFixed.cfg \
    models/providers/ParslGridEngineSubmitShape.tla
run_case lsf-missing-job \
    models/providers/ParslLSFMissingJobFixed.cfg \
    models/providers/ParslLSFMissingJob.tla
run_case lsf-resource-validation \
    models/providers/ParslLSFResourceValidationFixed.cfg \
    models/providers/ParslLSFResourceValidation.tla
run_case lsf-submit-job-id \
    models/providers/ParslLsfSubmitJobIdFixed.cfg \
    models/providers/ParslLsfSubmitJobId.tla
run_case lsf-cancel-unknown \
    models/providers/ParslLSFCancelFixed.cfg \
    models/providers/ParslLSFCancel.tla
run_case pbspro-submit-shape \
    models/providers/ParslPbsproSubmitShapeFixed.cfg \
    models/providers/ParslPbsproSubmitShape.tla
run_case pbspro-submit-boundary \
    models/providers/ParslPBSProSubmitFixed.cfg \
    models/providers/ParslPBSProSubmit.tla
run_case torque-malformed-status \
    models/providers/ParslTorqueMalformedStatusLineFixed.cfg \
    models/providers/ParslTorqueMalformedStatusLine.tla
run_case torque-missing-status \
    models/providers/ParslTorqueMissingStatusFixed.cfg \
    models/providers/ParslTorqueMissingStatus.tla
run_case torque-status-failure \
    models/providers/ParslTorqueStatusFailureFixed.cfg \
    models/providers/ParslTorqueStatusFailure.tla
run_case torque-duplicate-status \
    models/providers/ParslTorqueDuplicateStatusFixed.cfg \
    models/providers/ParslTorqueDuplicateStatus.tla
run_case torque-foreign-status \
    models/providers/ParslTorqueStatusFixed.cfg \
    models/providers/ParslTorqueStatus.tla
run_case thread-executor-resource-spec \
    models/executors/ParslThreadExecutorResourceSpecFixed.cfg \
    models/executors/ParslThreadExecutorResourceSpec.tla
run_case thread-executor-empty-resource-spec \
    models/executors/ParslThreadExecutorEmptyResourceSpecFixed.cfg \
    models/executors/ParslThreadExecutorEmptyResourceSpec.tla
run_case flux-serialization-error-name \
    models/executors/ParslFluxSerializationErrorNameFixed.cfg \
    models/executors/ParslFluxSerializationErrorName.tla
run_case workqueue-submit \
    models/executors/ParslWorkQueueSubmitFixed.cfg \
    models/executors/ParslWorkQueueSubmit.tla
run_case workqueue-submit-serialization \
    models/executors/ParslWorkQueueSubmitSerializationFailureFixed.cfg \
    models/executors/ParslWorkQueueSubmit.tla
run_case workqueue-resource-category \
    models/executors/ParslWorkQueueResourceCategoryFixed.cfg \
    models/executors/ParslWorkQueueResourceCategory.tla
run_case workqueue-resource-spec-shape \
    models/executors/ParslWorkQueueResourceSpecShapeFixed.cfg \
    models/executors/ParslWorkQueueResourceSpecShape.tla
run_case workqueue-cancelled-result \
    models/executors/ParslWorkQueueCancelledResultFixed.cfg \
    models/executors/ParslWorkQueueCancelledResult.tla
run_case workqueue-cancelled-failure-result \
    models/executors/ParslWorkQueueCancelledFailureResultFixed.cfg \
    models/executors/ParslWorkQueueCancelledFailureResult.tla
run_case taskvine-submit \
    models/executors/ParslTaskVineSubmitFixed.cfg \
    models/executors/ParslTaskVineSubmit.tla
run_case taskvine-factory \
    models/executors/ParslTaskVineFactory.cfg \
    models/executors/ParslTaskVineFactory.tla
run_case taskvine-start-failure-cleanup \
    models/executors/ParslTaskVineStartFailureCleanupFixed.cfg \
    models/executors/ParslTaskVineStartFailureCleanup.tla
run_case taskvine-submit-serialization \
    models/executors/ParslTaskVineSubmitSerializationFailureFixed.cfg \
    models/executors/ParslTaskVineSubmit.tla
run_case taskvine-cancelled-result \
    models/executors/ParslTaskVineCancelledResultFixed.cfg \
    models/executors/ParslTaskVineCancelledResult.tla
run_case taskvine-cancelled-failure-result \
    models/executors/ParslTaskVineCancelledFailureResultFixed.cfg \
    models/executors/ParslTaskVineCancelledFailureResult.tla
run_case taskvine-resource-spec-shape \
    models/executors/ParslTaskVineResourceSpecShapeFixed.cfg \
    models/executors/ParslTaskVineResourceSpecShape.tla
run_case flux-error-cleanup \
    models/executors/ParslFluxErrorCleanupCancellationFixed.cfg \
    models/executors/ParslFluxErrorCleanupCancellation.tla
run_case flux-result \
    models/executors/ParslFluxResultFixed.cfg \
    models/executors/ParslFluxResult.tla
run_case flux-late-failure-cancelled-future \
    models/executors/ParslFluxLateFailureCancelledFutureFixed.cfg \
    models/executors/ParslFluxLateFailureCancelledFuture.tla
run_case flux-late-result-cancelled-future \
    models/executors/ParslFluxLateResultCancelledFutureFixed.cfg \
    models/executors/ParslFluxLateResultCancelledFuture.tla
run_case flux-cancel-running-race \
    models/executors/ParslFluxCancelRunningRaceFixed.cfg \
    models/executors/ParslFluxCancelRunningRace.tla
run_case flux-cancel-submit-race \
    models/executors/ParslFluxCancelSubmitRaceFixed.cfg \
    models/executors/ParslFluxCancelSubmitRace.tla
run_case scale-in-result-shape \
    models/executors/ParslScaleInResultShapeFixed.cfg \
    models/executors/ParslScaleInResultShape.tla
run_case flux-submission-failure \
    models/executors/ParslFluxSubmissionFailure.cfg \
    models/executors/ParslFluxSubmissionFailure.tla
run_case flux-inflight-submission-failure \
    models/executors/ParslFluxInflightSubmissionFailureFixed.cfg \
    models/executors/ParslFluxInflightSubmissionFailure.tla
run_case globus-compute-result \
    models/executors/ParslGlobusComputeResult.cfg \
    models/executors/ParslGlobusComputeResult.tla
run_case radical-pilot-results \
    models/executors/ParslRadicalPilotResultsFixed.cfg \
    models/executors/ParslRadicalPilotResults.tla
run_case mpi-backlog-retry \
    models/executors/ParslMPIBacklogRetryFixed.cfg \
    models/executors/ParslMPIBacklogRetry.tla
run_case workqueue-shutdown \
    models/executors/ParslWorkQueueShutdown.cfg \
    models/executors/ParslWorkQueueShutdown.tla
run_case thread-executor-nonblocking \
    models/executors/ParslThreadExecutorNonBlocking.cfg \
    models/executors/ParslThreadExecutor.tla
run_case thread-executor-future-lifecycle \
    models/executors/ParslThreadExecutorFutureLifecycle.cfg \
    models/executors/ParslThreadExecutorFutureLifecycle.tla
run_case globus-submit-race \
    models/executors/ParslGlobusComputeSubmitRaceFixed.cfg \
    models/executors/ParslGlobusComputeSubmitRace.tla
run_case globus-resource-spec \
    models/executors/ParslGlobusComputeResourceSpecTypeFixed.cfg \
    models/executors/ParslGlobusComputeResourceSpecType.tla
run_case globus-shutdown-cleanup \
    models/executors/ParslGlobusComputeShutdownCleanupFixed.cfg \
    models/executors/ParslGlobusComputeShutdownCleanup.tla
run_case aws-submit \
    models/providers/ParslAWSProviderSubmitFixed.cfg \
    models/providers/ParslAWSProviderSubmit.tla
run_case aws-cancel \
    models/providers/ParslAWSProviderCancelMissingFixed.cfg \
    models/providers/ParslAWSProviderCancel.tla
run_case aws-cancel-duplicates \
    models/providers/ParslAwsCancelDuplicatesFixed.cfg \
    models/providers/ParslAwsCancelDuplicates.tla
run_case aws-empty-submit \
    models/providers/ParslAwsSubmitEmptyResponseFixed.cfg \
    models/providers/ParslAwsSubmitEmptyResponse.tla
run_case aws-reservation-shape \
    models/providers/ParslAwsStatusReservationShapeFixed.cfg \
    models/providers/ParslAwsStatusReservationShape.tla
run_case aws-status-missing-result \
    models/providers/ParslAwsStatusMissingResultFixed.cfg \
    models/providers/ParslAwsStatusMissingResult.tla
run_case aws-status-ordering \
    models/providers/ParslAwsStatusOrderingFixed.cfg \
    models/providers/ParslAwsStatusOrdering.tla
run_case azure-cancel-missing-local \
    models/providers/ParslAzureCancelMissingFixed.cfg \
    models/providers/ParslAzureCancel.tla
run_case azure-submit \
    models/providers/ParslAzureProviderSubmitFixed.cfg \
    models/providers/ParslAzureProviderSubmit.tla
run_case azure-cancel \
    models/providers/ParslAzureCancelBookkeepingFixed.cfg \
    models/providers/ParslAzureCancelBookkeeping.tla
run_case azure-status-bookkeeping \
    models/providers/ParslAzureStatusBookkeepingFixed.cfg \
    models/providers/ParslAzureStatusBookkeeping.tla
run_case azure-status-ordering \
    models/providers/ParslAzureStatusOrderingFixed.cfg \
    models/providers/ParslAzureStatusOrdering.tla
run_case azure-status-remote-failure \
    models/providers/ParslAzureStatusRemoteFailureFixed.cfg \
    models/providers/ParslAzureStatusRemoteFailure.tla
run_case azure-status-shape \
    models/providers/ParslAzureStatusShapeFixed.cfg \
    models/providers/ParslAzureStatusShape.tla
run_case azure-status-translation \
    models/providers/ParslAzureStatus.cfg \
    models/providers/ParslAzureStatus.tla
run_case google-submit \
    models/providers/ParslGoogleCloudSubmitFixed.cfg \
    models/providers/ParslGoogleCloudSubmit.tla
run_case google-submit-state \
    models/providers/ParslGoogleCloudSubmitStateFixed.cfg \
    models/providers/ParslGoogleCloudSubmitState.tla
run_case google-cancel \
    models/providers/ParslGoogleCloudCancelFixed.cfg \
    models/providers/ParslGoogleCloudCancel.tla
run_case google-status \
    models/providers/ParslGoogleCloudStatusFixed.cfg \
    models/providers/ParslGoogleCloudStatus.tla
run_case google-status-remote-failure \
    models/providers/ParslGoogleCloudStatusRemoteFailureFixed.cfg \
    models/providers/ParslGoogleCloudStatusRemoteFailure.tla
run_case google-unknown-local-status \
    models/providers/ParslGoogleCloudUnknownLocalStatusFixed.cfg \
    models/providers/ParslGoogleCloudUnknownLocalStatus.tla
run_case google-zone-selection \
    models/providers/ParslGoogleCloudZoneSelectionFixed.cfg \
    models/providers/ParslGoogleCloudZoneSelection.tla
run_case provider-provisioning-lifecycle \
    models/executors/ParslProviderProvisioningLifecycle.cfg \
    models/executors/ParslProviderProvisioningLifecycle.tla
run_case provider-multi-block-ownership \
    models/executors/ParslProviderMultiBlockOwnership.cfg \
    models/executors/ParslProviderMultiBlockOwnership.tla
run_case provider-worker-scaling \
    models/executors/ParslProviderWorkerScaling.cfg \
    models/executors/ParslProviderWorkerScaling.tla
run_case provider-three-block-ownership \
    models/executors/ParslProviderThreeBlockOwnershipFixed.cfg \
    models/executors/ParslProviderThreeBlockOwnership.tla
run_case scale-in-retry-monitoring \
    models/executors/ParslScaleInRetryMonitoringFixed.cfg \
    models/executors/ParslScaleInRetryMonitoring.tla
run_case negative-scale-in \
    models/executors/ParslNegativeScaleInFixed.cfg \
    models/executors/ParslNegativeScaleIn.tla
run_case mpi-nonpositive-resources \
    models/executors/ParslMPINonPositiveResourcesFixed.cfg \
    models/executors/ParslMPINonPositiveResources.tla
run_case mpi-nondivisible-ranks \
    models/executors/ParslMPINonDivisibleRanksFixed.cfg \
    models/executors/ParslMPINonDivisibleRanks.tla
run_case htex-worker-restart-failure \
    models/executors/ParslHtexWorkerRestartFailureFixed.cfg \
    models/executors/ParslHtexWorkerRestartFailure.tla
run_case mpi-no-resource-result \
    models/executors/ParslMPINoResourceResultFixed.cfg \
    models/executors/ParslMPINoResourceResult.tla
run_case mpi-malformed-result-cleanup \
    models/executors/ParslMPIMalformedResultCleanupFixed.cfg \
    models/executors/ParslMPIMalformedResultCleanup.tla
run_case join-return-equality-truthy \
    models/dataflow/ParslJoinReturnEqualityTruthyFixed.cfg \
    models/dataflow/ParslJoinReturnEqualityTruthy.tla
run_case join-partial-cancellation \
    models/dataflow/ParslJoinPartialCancellationFixed.cfg \
    models/dataflow/ParslJoinPartialCancellation.tla
run_case radical-failure-payload \
    models/executors/ParslRadicalPilotFailurePayloadFixed.cfg \
    models/executors/ParslRadicalPilotFailurePayload.tla
run_case radical-failure-fanout \
    models/executors/ParslRadicalFailureFanoutFixed.cfg \
    models/executors/ParslRadicalFailureFanout.tla
run_case radical-late-callback \
    models/executors/ParslRadicalPilotLateCallbackFixed.cfg \
    models/executors/ParslRadicalPilotLateCallback.tla
run_case radical-late-failure-callback \
    models/executors/ParslRadicalPilotLateFailureCallbackFixed.cfg \
    models/executors/ParslRadicalPilotLateFailureCallback.tla
run_case radical-unknown-callback \
    models/executors/ParslRadicalPilotUnknownCallbackFixed.cfg \
    models/executors/ParslRadicalPilotUnknownCallback.tla
run_case radical-bulk-shutdown \
    models/executors/ParslRadicalPilotBulkShutdownFixed.cfg \
    models/executors/ParslRadicalPilotBulkShutdown.tla
run_case resource-admission \
    models/dataflow/ParslResourceAdmission.cfg \
    models/dataflow/ParslResourceAdmission.tla
run_case resource-admission-autolabel \
    models/dataflow/ParslResourceAdmissionAutolabel.cfg \
    models/dataflow/ParslResourceAdmission.tla
run_case resource-scaling \
    models/dataflow/ParslResourceScaling.cfg \
    models/dataflow/ParslResourceScaling.tla
run_case dynamic-task-chain \
    models/dataflow/ParslDynamicTaskChain.cfg \
    models/dataflow/ParslDynamicTaskChain.tla
run_case dynamic-task-creation \
    models/dataflow/ParslDynamicTaskCreation.cfg \
    models/dataflow/ParslDynamicTaskCreation.tla
run_case dynamic-task-fanout \
    models/dataflow/ParslDynamicTaskFanout.cfg \
    models/dataflow/ParslDynamicTaskFanout.tla
run_case dependency-traversal-deep-dict \
    models/dataflow/ParslDependencyTraversalDeepDict.cfg \
    models/dataflow/ParslDependencyTraversal.tla
run_case dependency-traversal-deep-dict-key \
    models/dataflow/ParslDependencyTraversalDeepDictKey.cfg \
    models/dataflow/ParslDependencyTraversal.tla
run_case dependency-traversal-deep-set \
    models/dataflow/ParslDependencyTraversalDeepSet.cfg \
    models/dataflow/ParslDependencyTraversal.tla
run_case dependency-traversal-deep-tuple \
    models/dataflow/ParslDependencyTraversalDeepTuple.cfg \
    models/dataflow/ParslDependencyTraversal.tla
run_case future-cancellation-app \
    models/dataflow/ParslFutureCancellationApp.cfg \
    models/dataflow/ParslFutureCancellation.tla
run_case future-cancellation-data \
    models/dataflow/ParslFutureCancellationData.cfg \
    models/dataflow/ParslFutureCancellation.tla
run_case future-cancellation-underlying \
    models/dataflow/ParslFutureCancellationUnderlying.cfg \
    models/dataflow/ParslFutureCancellation.tla
run_case future-projection-invalid \
    models/dataflow/ParslFutureProjectionInvalid.cfg \
    models/dataflow/ParslFutureProjection.tla
run_case future-projection-valid \
    models/dataflow/ParslFutureProjectionValid.cfg \
    models/dataflow/ParslFutureProjection.tla
run_case future-wait-timeout \
    models/dataflow/ParslFutureWaitTimeout.cfg \
    models/dataflow/ParslFutureWaitTimeout.tla
run_case memo-function-identity \
    models/dataflow/ParslMemoFunctionIdentityFixed.cfg \
    models/dataflow/ParslMemoFunctionIdentity.tla
run_case memo-dict-ordering \
    models/dataflow/ParslMemoDictOrderingFixed.cfg \
    models/dataflow/ParslMemoDictOrdering.tla
run_case memo-dict-ordering-homogeneous \
    models/dataflow/ParslMemoDictOrderingHomogeneous.cfg \
    models/dataflow/ParslMemoDictOrdering.tla
run_case memo-function-identity-stable \
    models/dataflow/ParslMemoFunctionIdentityStable.cfg \
    models/dataflow/ParslMemoFunctionIdentity.tla
run_case memo-ignore-key \
    models/dataflow/ParslMemoIgnoreKeyFixed.cfg \
    models/dataflow/ParslMemoIgnoreKey.tla
run_case memo-ignore-outputs \
    models/dataflow/ParslMemoIgnoreOutputsFixed.cfg \
    models/dataflow/ParslMemoIgnoreOutputs.tla
run_case memo-checkpoint-order \
    models/dataflow/ParslMemoCheckpointOrderFixed.cfg \
    models/dataflow/ParslMemoCheckpointOrder.tla
run_case memo-checkpoint-result-failure \
    models/dataflow/ParslMemoCheckpointResultFailureFixed.cfg \
    models/dataflow/ParslMemoCheckpointResultFailure.tla
run_case memo-exception-checkpoint \
    models/dataflow/ParslMemoExceptionCheckpointFixed.cfg \
    models/dataflow/ParslMemoExceptionCheckpoint.tla
run_case last-checkpoint-uuid \
    models/dataflow/ParslLastCheckpointUUIDFixed.cfg \
    models/dataflow/ParslLastCheckpointUUID.tla
run_case task-status-future-ordering \
    models/dataflow/ParslTaskStatusFutureOrderingFixed.cfg \
    models/dataflow/ParslTaskStatusFutureOrdering.tla
run_case block-provider-bad-state-ordering \
    models/executors/ParslBlockProviderBadStateOrderingFixed.cfg \
    models/executors/ParslBlockProviderBadStateOrdering.tla
run_case block-provider-bad-state-mutation \
    models/executors/ParslBlockProviderBadStateMutationFixed.cfg \
    models/executors/ParslBlockProviderBadStateMutation.tla
run_case bad-state-terminal-future \
    models/executors/ParslBadStateTerminalFutureFixed.cfg \
    models/executors/ParslBadStateTerminalFuture.tla
run_case cluster-provider-unknown-job \
    models/providers/ParslClusterProviderUnknownJobFixed.cfg \
    models/providers/ParslClusterProviderUnknownJob.tla
run_case cluster-status-request \
    models/providers/ParslClusterStatusRequest.cfg \
    models/providers/ParslClusterStatusRequest.tla
run_case cluster-status-unknown \
    models/providers/ParslClusterStatusUnknownFixed.cfg \
    models/providers/ParslClusterStatusUnknown.tla
run_case local-provider-submit-cleanup \
    models/providers/ParslLocalProviderSubmitCleanupFixed.cfg \
    models/providers/ParslLocalProviderSubmitCleanup.tla
run_case local-cancel-failure \
    models/providers/ParslLocalCancelFailureFixed.cfg \
    models/providers/ParslLocalCancelFailure.tla
run_case local-exit-file-missing \
    models/providers/ParslLocalExitFileMissingFixed.cfg \
    models/providers/ParslLocalExitFileMissing.tla
run_case local-provider-cancel-unknown \
    models/providers/ParslLocalProviderCancelUnknownFixed.cfg \
    models/providers/ParslLocalProviderCancelUnknown.tla
run_case provider-status-shape \
    models/executors/ParslProviderStatusShapeFixed.cfg \
    models/executors/ParslProviderStatusShape.tla
run_case torque-cancel-unknown \
    models/providers/ParslTorqueCancelUnknownFixed.cfg \
    models/providers/ParslTorqueCancelUnknown.tla
run_case torque-cancel-state \
    models/providers/ParslTorqueCancelFixed.cfg \
    models/providers/ParslTorqueCancel.tla
run_case azure-cancel-bookkeeping \
    models/providers/ParslAzureCancelBookkeepingFixed.cfg \
    models/providers/ParslAzureCancelBookkeeping.tla
run_case pbspro-status-shape \
    models/providers/ParslPbsproStatusShapeFixed.cfg \
    models/providers/ParslPbsproStatusShape.tla
run_case pbspro-status-batch-isolation \
    models/providers/ParslPbsproStatusBatchIsolationFixed.cfg \
    models/providers/ParslPbsproStatusBatchIsolation.tla
run_case pbspro-status-foreign-job \
    models/providers/ParslPBSProStatusFixed.cfg \
    models/providers/ParslPBSProStatus.tla
run_case local-submit-pid-shape \
    models/providers/ParslLocalSubmitPidShapeFixed.cfg \
    models/providers/ParslLocalSubmitPidShape.tla
run_case poller-close-scale-in \
    models/providers/ParslPollerCloseScaleInRaceFixed.cfg \
    models/providers/ParslPollerCloseScaleInRace.tla
run_case poller-duplicate-executor \
    models/providers/ParslPollerDuplicateExecutorFixed.cfg \
    models/providers/ParslPollerDuplicateExecutor.tla
run_case poller-executor-isolation \
    models/providers/ParslPollerExecutorIsolationFixed.cfg \
    models/providers/ParslPollerExecutorIsolation.tla
run_case executor-kinds \
    models/executors/ParslExecutorKindsSmoke.cfg \
    models/executors/ParslExecutorKinds.tla
run_case executor-provider-bridge \
    models/executors/ParslProviderExecutorBridgeSmoke.cfg \
    models/executors/ParslProviderExecutorBridge.tla
run_case executor-provider-lifecycle \
    models/executors/ParslExecutorProviderLifecycleFixed.cfg \
    models/executors/ParslExecutorProviderLifecycle.tla
run_case executor-selection \
    models/executors/ParslExecutorSelectionFixed.cfg \
    models/executors/ParslExecutorSelection.tla
run_case executor-shutdown \
    models/executors/ParslExecutorShutdown.cfg \
    models/executors/ParslExecutorShutdown.tla
run_case provider-executor-timed \
    models/executors/ParslProviderExecutorTimedFixed.cfg \
    models/executors/ParslProviderExecutorTimed.tla
run_case join-cancellation \
    models/dataflow/ParslJoinCancellationFixed.cfg \
    models/dataflow/ParslJoinCancellation.tla
run_case join-cleanup-lifecycle \
    models/dataflow/ParslJoinCleanupLifecycleFixed.cfg \
    models/dataflow/ParslJoinCleanupLifecycle.tla
run_case join-duplicate-failure-aggregation \
    models/dataflow/ParslJoinDuplicateFailureAggregationFixed.cfg \
    models/dataflow/ParslJoinDuplicateFailureAggregation.tla
run_case join-failure-aggregation \
    models/dataflow/ParslJoinFailureAggregation.cfg \
    models/dataflow/ParslJoinFailureAggregation.tla
run_case join-immediate-cancellation \
    models/dataflow/ParslJoinImmediateCancellationFixed.cfg \
    models/dataflow/ParslJoinImmediateCancellation.tla
run_case join-list-cancellation \
    models/dataflow/ParslJoinListCancellationFixed.cfg \
    models/dataflow/ParslJoinListCancellation.tla
run_case join-callback-multiplicity \
    models/dataflow/ParslJoinCallbackMultiplicity.cfg \
    models/dataflow/ParslJoinCallbackMultiplicity.tla
run_case join-immediate-callback \
    models/dataflow/ParslJoinImmediateCallback.cfg \
    models/dataflow/ParslJoinImmediateCallback.tla
run_case join-return-shape \
    models/dataflow/ParslJoinReturnShapeFuture.cfg \
    models/dataflow/ParslJoinReturnShape.tla
run_case join-body-retry \
    models/dataflow/ParslJoinBodyRetry.cfg \
    models/dataflow/ParslJoinBodyRetry.tla
run_case join-callback-race \
    models/dataflow/ParslJoinCallbackRace.cfg \
    models/dataflow/ParslJoinCallbackRace.tla
run_case join-callable-transport \
    models/dataflow/ParslJoinCallableTransport.cfg \
    models/dataflow/ParslJoinCallableTransport.tla
run_case join-mixed-list \
    models/dataflow/ParslJoinMixedList.cfg \
    models/dataflow/ParslJoinMixedList.tla
run_case join-memo-data \
    models/dataflow/ParslJoinMemoData.cfg \
    models/dataflow/ParslJoinMemoData.tla
run_case nested-join-failure \
    models/dataflow/ParslNestedJoinFailure.cfg \
    models/dataflow/ParslNestedJoinFailure.tla
run_case nested-join-retry \
    models/dataflow/ParslNestedJoinRetry.cfg \
    models/dataflow/ParslNestedJoinRetry.tla
run_case htex-cancelled-result \
    models/executors/ParslHtexCancelledResultFixed.cfg \
    models/executors/ParslHtexCancelledResult.tla
run_case htex-cancelled-failure-result \
    models/executors/ParslHtexCancelledFailureResultFixed.cfg \
    models/executors/ParslHtexCancelledFailureResult.tla
run_case htex-duplicate-result \
    models/executors/ParslHtexDuplicateResultFixed.cfg \
    models/executors/ParslHtexDuplicateResult.tla
run_case htex-result-frame-continuation \
    models/executors/ParslHtexExecutorResultFrameContinuationFixed.cfg \
    models/executors/ParslHtexExecutorResultFrameContinuation.tla
run_case htex-malformed-result-frame \
    models/executors/ParslHtexResultMessageMalformedFixed.cfg \
    models/executors/ParslHtexResultMessageMalformed.tla
run_case htex-worker-batch-shape \
    models/executors/ParslHtexWorkerTaskBatchShapeFixed.cfg \
    models/executors/ParslHtexWorkerTaskBatchShape.tla
run_case htex-worker-frame-continuation \
    models/executors/ParslHtexWorkerTaskFrameContinuationFixed.cfg \
    models/executors/ParslHtexWorkerTaskFrameContinuation.tla
run_case htex-manager-task-admission \
    models/executors/ParslHtexManagerTaskAdmissionFixed.cfg \
    models/executors/ParslHtexManagerTaskAdmission.tla
run_case htex-manager-loss \
    models/executors/ParslHtexManagerLossFixed.cfg \
    models/executors/ParslHtexManagerLoss.tla
run_case htex-capacity-fallback \
    models/executors/ParslHtexCapacityFallback.cfg \
    models/executors/ParslHtexCapacityFallback.tla
run_case htex-cores-per-worker \
    models/executors/ParslHtexCoresPerWorkerFixed.cfg \
    models/executors/ParslHtexCoresPerWorker.tla
run_case htex-dispatch-priority \
    models/executors/ParslHtexDispatchPriority.cfg \
    models/executors/ParslHtexDispatchPriority.tla
run_case htex-scale-in-race \
    models/executors/ParslHtexScaleInRaceFixed.cfg \
    models/executors/ParslHtexScaleInRace.tla
run_case htex-force-scale-in \
    models/executors/ParslHtexForceScaleInFixed.cfg \
    models/executors/ParslHtexForceScaleIn.tla
run_case htex-negative-scale-in-idle \
    models/executors/ParslHtexNegativeScaleInIdleFixed.cfg \
    models/executors/ParslHtexNegativeScaleInIdle.tla
run_case provisioning-admission-monitoring \
    models/executors/ParslProvisioningAdmissionMonitoringFixed.cfg \
    models/executors/ParslProvisioningAdmissionMonitoring.tla
run_case scale-out-failure-monitoring \
    models/executors/ParslScaleOutFailureMonitoringFixed.cfg \
    models/executors/ParslScaleOutFailureMonitoring.tla
run_case htex-shutdown-reap \
    models/executors/ParslHtexShutdownReapFixed.cfg \
    models/executors/ParslHtexShutdownReap.tla
run_case htex-unknown-manager-heartbeat \
    models/executors/ParslHtexUnknownManagerHeartbeat.cfg \
    models/executors/ParslHtexUnknownManagerMessage.tla
run_case htex-unknown-manager-result \
    models/executors/ParslHtexUnknownManagerResult.cfg \
    models/executors/ParslHtexUnknownManagerMessage.tla
run_case htex-unknown-task-result \
    models/executors/ParslHtexUnknownTaskResultFixed.cfg \
    models/executors/ParslHtexUnknownTaskResult.tla
run_case htex-worker-capacity-cpu \
    models/executors/ParslHtexWorkerCapacityCpu.cfg \
    models/executors/ParslHtexWorkerCapacity.tla
run_case htex-worker-capacity-memory \
    models/executors/ParslHtexWorkerCapacityMemory.cfg \
    models/executors/ParslHtexWorkerCapacity.tla
run_case htex-worker-capacity-accelerator \
    models/executors/ParslHtexWorkerCapacityAccelerator.cfg \
    models/executors/ParslHtexWorkerCapacity.tla
run_case htex-registration-shape \
    models/serialization/ParslHtexRegistrationShapeFixed.cfg \
    models/serialization/ParslHtexRegistrationShape.tla
run_case htex-registration-types \
    models/serialization/ParslHtexRegistrationTypesFixed.cfg \
    models/serialization/ParslHtexRegistrationTypes.tla
run_case htex-task-context-type \
    models/executors/ParslHtexTaskContextTypeFixed.cfg \
    models/executors/ParslHtexTaskContextType.tla
run_case htex-task-id-type \
    models/executors/ParslHtexTaskIdTypeFixed.cfg \
    models/executors/ParslHtexTaskIdType.tla
run_case htex-task-message-shape \
    models/executors/ParslHtexTaskMessageMalformedFixed.cfg \
    models/executors/ParslHtexTaskMessageMalformed.tla
run_case htex-task-ingress-continuation \
    models/serialization/ParslHtexTaskIngressContinuationFixed.cfg \
    models/serialization/ParslHtexTaskIngressContinuation.tla
run_case htex-serialization-failure \
    models/serialization/ParslHtexSerializationFailureFixed.cfg \
    models/serialization/ParslHtexSerializationFailure.tla
run_case htex-serialization-error-name \
    models/serialization/ParslHtexSerializationErrorNameFixed.cfg \
    models/serialization/ParslHtexSerializationErrorName.tla
run_case htex-result-decode-continuation \
    models/serialization/ParslHtexResultDecodeContinuationFixed.cfg \
    models/serialization/ParslHtexResultDecodeContinuation.tla
run_case htex-task-priority-type \
    models/executors/ParslHtexTaskPriorityTypeFixed.cfg \
    models/executors/ParslHtexTaskPriorityType.tla
run_case htex-task-resource-spec-type \
    models/executors/ParslHtexTaskResourceSpecTypeFixed.cfg \
    models/executors/ParslHtexTaskResourceSpecType.tla
run_case htex-version-mismatch \
    models/executors/ParslHtexVersionMismatchFixed.cfg \
    models/executors/ParslHtexVersionMismatch.tla
run_case monitoring-hub-close \
    models/monitoring/ParslMonitoringHubClose.cfg \
    models/monitoring/ParslMonitoringHubClose.tla
run_case monitoring-hub-close-before-start \
    models/monitoring/ParslMonitoringHubCloseBeforeStartFixed.cfg \
    models/monitoring/ParslMonitoringHubCloseBeforeStart.tla
run_case monitoring-hub-start-failure-cleanup \
    models/monitoring/ParslMonitoringHubStartFailureCleanupFixed.cfg \
    models/monitoring/ParslMonitoringHubStartFailureCleanup.tla
run_case monitoring-hub-repeated-start \
    models/monitoring/ParslMonitoringHubRepeatedStartFixed.cfg \
    models/monitoring/ParslMonitoringHubRepeatedStart.tla
run_case monitoring-close-idempotence \
    models/monitoring/ParslMonitoringCloseIdempotenceFixed.cfg \
    models/monitoring/ParslMonitoringCloseIdempotence.tla
run_case monitoring-shutdown-drain \
    models/monitoring/ParslMonitoringShutdownDrain.cfg \
    models/monitoring/ParslMonitoringShutdownDrain.tla
run_case monitoring-shutdown-race \
    models/monitoring/ParslMonitoringShutdownRaceFixed.cfg \
    models/monitoring/ParslMonitoringShutdownRace.tla
run_case monitoring-event-stream \
    models/monitoring/ParslMonitoringEventStreamFixed.cfg \
    models/monitoring/ParslMonitoringEventStream.tla
run_case monitoring-status-history \
    models/monitoring/ParslMonitoringStatusHistory.cfg \
    models/monitoring/ParslMonitoringStatusHistory.tla
run_case monitoring-malformed-worker-message \
    models/monitoring/ParslMonitoringMalformedWorkerMessageFixed.cfg \
    models/monitoring/ParslMonitoringMalformedWorkerMessage.tla
run_case monitoring-dispatch-envelope \
    models/monitoring/ParslMonitoringDispatchEnvelopeFixed.cfg \
    models/monitoring/ParslMonitoringDispatchEnvelope.tla
run_case monitoring-zmq-tuple-shape \
    models/monitoring/ParslMonitoringZMQTupleShapeValid.cfg \
    models/monitoring/ParslMonitoringZMQTupleShape.tla
run_case monitoring-worker-status-atomicity \
    models/monitoring/ParslMonitoringWorkerStatusAtomicityFixed.cfg \
    models/monitoring/ParslMonitoringWorkerStatusAtomicity.tla
run_case monitoring-worker-try-atomicity \
    models/monitoring/ParslMonitoringWorkerTryAtomicityFixed.cfg \
    models/monitoring/ParslMonitoringWorkerTryAtomicity.tla
run_case monitoring-lifecycle-bookkeeping \
    models/monitoring/ParslMonitoringLifecycleBookkeepingFixed.cfg \
    models/monitoring/ParslMonitoringLifecycleBookkeeping.tla
run_case monitoring-deferred-multiplicity \
    models/monitoring/ParslMonitoringDeferredMultiplicityFixed.cfg \
    models/monitoring/ParslMonitoringDeferredMultiplicity.tla
run_case monitoring-last-message-race \
    models/monitoring/ParslMonitoringLastMessageRaceFixed.cfg \
    models/monitoring/ParslMonitoringLastMessageRace.tla
run_case monitoring-task-insert-bookkeeping \
    models/monitoring/ParslMonitoringTaskInsertBookkeepingFixed.cfg \
    models/monitoring/ParslMonitoringTaskInsertBookkeeping.tla
run_case monitoring-try-insert-bookkeeping \
    models/monitoring/ParslMonitoringTryInsertBookkeepingFixed.cfg \
    models/monitoring/ParslMonitoringTryInsertBookkeeping.tla
run_case monitoring-workflow-insert-bookkeeping \
    models/monitoring/ParslMonitoringWorkflowInsertBookkeepingFixed.cfg \
    models/monitoring/ParslMonitoringWorkflowInsertBookkeeping.tla
run_case monitoring-workflow-end-bookkeeping \
    models/monitoring/ParslMonitoringWorkflowEndBookkeepingFixed.cfg \
    models/monitoring/ParslMonitoringWorkflowEndBookkeeping.tla
run_case monitoring-foreign-key \
    models/monitoring/ParslMonitoringForeignKeyFixed.cfg \
    models/monitoring/ParslMonitoringForeignKey.tla
run_case monitoring-update-persistent-retry \
    models/monitoring/ParslMonitoringUpdatePersistentRetryFixed.cfg \
    models/monitoring/ParslMonitoringUpdatePersistentRetry.tla
run_case monitoring-external-queue-empty \
    models/monitoring/ParslMonitoringExternalQueueEmptyRaceFixed.cfg \
    models/monitoring/ParslMonitoringExternalQueueEmptyRace.tla
run_case monitoring-udp-drain-clock \
    models/clock/ParslMonitoringUDPDrainClockFixed.cfg \
    models/clock/ParslMonitoringUDPDrainClock.tla
run_case ftp-stage \
    models/staging/ParslFTPStageFixed.cfg \
    models/staging/ParslFTPStage.tla
run_case ftp-partial-cleanup \
    models/staging/ParslFTPPartialCleanupFixed.cfg \
    models/staging/ParslFTPPartialCleanup.tla
run_case ftp-connection-cleanup \
    models/staging/ParslFTPConnectionCleanupFixed.cfg \
    models/staging/ParslFTPConnectionCleanup.tla
run_case globus-endpoint-path \
    models/staging/ParslGlobusEndpointPathFixed.cfg \
    models/staging/ParslGlobusEndpointPath.tla
run_case globus-failure-event \
    models/staging/ParslGlobusFailureEventFixed.cfg \
    models/staging/ParslGlobusFailureEvent.tla
run_case globus-token-file-atomicity \
    models/staging/ParslGlobusTokenFileAtomicityFixed.cfg \
    models/staging/ParslGlobusTokenFileAtomicity.tla
run_case globus-token-schema \
    models/staging/ParslGlobusTokenSchemaFixed.cfg \
    models/staging/ParslGlobusTokenSchema.tla
run_case globus-init-race \
    models/staging/ParslGlobusInitRaceFixed.cfg \
    models/staging/ParslGlobusInitRace.tla
run_case globus-transfer-timeout \
    models/staging/ParslGlobusTransferTimeoutFixed.cfg \
    models/staging/ParslGlobusTransferTimeout.tla
run_case http-connection-cleanup \
    models/staging/ParslHTTPConnectionCleanupFixed.cfg \
    models/staging/ParslHTTPConnectionCleanup.tla
run_case http-partial-cleanup \
    models/staging/ParslHTTPPartialCleanupFixed.cfg \
    models/staging/ParslHTTPPartialCleanup.tla
run_case http-separate-task-cleanup \
    models/staging/ParslHTTPSeparateTaskCleanupFixed.cfg \
    models/staging/ParslHTTPSeparateTaskCleanup.tla
run_case http-status-validation \
    models/staging/ParslHTTPStatusValidationFixed.cfg \
    models/staging/ParslHTTPStatusValidation.tla
run_case rsync-partial-cleanup \
    models/staging/ParslRsyncPartialCleanupFixed.cfg \
    models/staging/ParslRsyncPartialCleanup.tla
run_case file-transfer-retry \
    models/staging/ParslFileTransferRetryFixed.cfg \
    models/staging/ParslFileTransferRetry.tla
run_case file-clean-copy \
    models/staging/ParslFileCleanCopyFixed.cfg \
    models/staging/ParslFileCleanCopy.tla
run_case http-existing-destination \
    models/staging/ParslHTTPExistingDestinationFixed.cfg \
    models/staging/ParslHTTPExistingDestination.tla
run_case http-separate-content-length \
    models/staging/ParslHTTPSeparateContentLengthFixed.cfg \
    models/staging/ParslHTTPSeparateContentLength.tla
run_case http-separate-content-length-normal \
    models/staging/ParslHTTPSeparateContentLengthNormal.cfg \
    models/staging/ParslHTTPSeparateContentLength.tla
run_case http-separate-status \
    models/staging/ParslHTTPSeparateStatusFixed.cfg \
    models/staging/ParslHTTPSeparateStatus.tla
run_case multi-output-versioned-stageout \
    models/staging/ParslMultiOutputVersionedStageOut.cfg \
    models/staging/ParslMultiOutputVersionedStageOut.tla
run_case three-output-versioned-stageout \
    models/staging/ParslThreeOutputVersionedStageOutFixed.cfg \
    models/staging/ParslThreeOutputVersionedStageOut.tla
run_case zip-member-selection \
    models/staging/ParslZipMemberSelectionFixed.cfg \
    models/staging/ParslZipMemberSelection.tla
run_case zip-path-first-match \
    models/staging/ParslZipPathFirstMatchFixed.cfg \
    models/staging/ParslZipPathFirstMatch.tla
run_case zip-path-validation \
    models/staging/ParslZipPathValidationFixed.cfg \
    models/staging/ParslZipPathValidation.tla
run_case zip-stage-in \
    models/staging/ParslZipStageInFixed.cfg \
    models/staging/ParslZipStageIn.tla
run_case zip-traversal \
    models/staging/ParslZipTraversalFixed.cfg \
    models/staging/ParslZipTraversal.tla
run_case kubernetes-polling \
    models/providers/ParslKubernetesPollingFixed.cfg \
    models/providers/ParslKubernetesPolling.tla
run_case kubernetes-lifecycle \
    models/providers/ParslKubernetesLifecycleFixed.cfg \
    models/providers/ParslKubernetesLifecycle.tla
run_case kubernetes-empty-phase \
    models/providers/ParslKubernetesEmptyPhaseFixed.cfg \
    models/providers/ParslKubernetesEmptyPhase.tla
run_case kubernetes-cancel-response \
    models/providers/ParslKubernetesCancelResponseFixed.cfg \
    models/providers/ParslKubernetesCancelResponse.tla
run_case kubernetes-cancel-unknown-job \
    models/providers/ParslKubernetesCancelUnknownJobFixed.cfg \
    models/providers/ParslKubernetesCancelUnknownJob.tla
run_case kubernetes-cancel-boundary \
    models/providers/ParslKubernetesCancelFixed.cfg \
    models/providers/ParslKubernetesCancel.tla
run_case kubernetes-unknown-status \
    models/providers/ParslKubernetesUnknownJobFixed.cfg \
    models/providers/ParslKubernetesUnknownJob.tla
run_case condor-chunk-size \
    models/providers/ParslCondorChunkSizeFixed.cfg \
    models/providers/ParslCondorChunkSize.tla
run_case condor-status-failure \
    models/providers/ParslCondorStatusFailureFixedMalformed.cfg \
    models/providers/ParslCondorStatusFailure.tla
run_case condor-status-malformed-line \
    models/providers/ParslCondorStatusFixed.cfg \
    models/providers/ParslCondorStatus.tla
run_case slurm-batch-strict \
    models/providers/ParslSlurmBatchStrictFixed.cfg \
    models/providers/ParslSlurmBatchStrict.tla
run_case slurm-cancel-batch \
    models/providers/ParslSlurmCancelBatchFixed.cfg \
    models/providers/ParslSlurmCancelBatch.tla
run_case slurm-duplicate-status \
    models/providers/ParslSlurmDuplicateStatusFixed.cfg \
    models/providers/ParslSlurmDuplicateStatus.tla
run_case slurm-foreign-status \
    models/providers/ParslSlurmStatusFixed.cfg \
    models/providers/ParslSlurmStatus.tla
run_case slurm-empty-job-id \
    models/providers/ParslSlurmEmptyJobIdFixed.cfg \
    models/providers/ParslSlurmEmptyJobId.tla
run_case slurm-submit-boundary \
    models/providers/ParslSlurmSubmitFixed.cfg \
    models/providers/ParslSlurmSubmit.tla
run_case pbspro-missing-status \
    models/providers/ParslPbsproMissingStatusFixed.cfg \
    models/providers/ParslPbsproMissingStatus.tla
run_case data-ready-execution \
    models/core/ParslDataReadyExecutionFixed.cfg \
    models/core/ParslDataReadyExecution.tla
run_case data-transfer-dependency-failure \
    models/core/ParslDataTransferDependencyFailureFixed.cfg \
    models/core/ParslDataTransferDependencyFailure.tla
run_case datafuture-transfer \
    models/staging/ParslDataFutureTransferFixed.cfg \
    models/staging/ParslDataFutureTransfer.tla
run_case datafuture-cancellation-propagation \
    models/staging/ParslDataFutureCancellationPropagationFixed.cfg \
    models/staging/ParslDataFutureCancellationPropagation.tla
run_case datafuture-copy \
    models/dataflow/ParslDataFutureCopy.cfg \
    models/dataflow/ParslDataFutureCopy.tla
run_case input-list-mutation \
    models/dataflow/ParslInputListMutationFixed.cfg \
    models/dataflow/ParslInputListMutation.tla
run_case output-list-mutation \
    models/dataflow/ParslOutputListMutationFixed.cfg \
    models/dataflow/ParslOutputListMutation.tla
run_case dependency-identity-dedup \
    models/dataflow/ParslDependencyIdentityDedupFixed.cfg \
    models/dataflow/ParslDependencyIdentityDedup.tla
run_case task-staging-monitoring \
    models/core/ParslTaskStagingMonitoringFixed.cfg \
    models/core/ParslTaskStagingMonitoring.tla
run_case app-future-output-streams-none \
    models/dataflow/ParslAppFutureOutputStreamsNone.cfg \
    models/dataflow/ParslAppFutureOutputStreams.tla
run_case app-future-output-streams-staged \
    models/dataflow/ParslAppFutureOutputStreamsStaged.cfg \
    models/dataflow/ParslAppFutureOutputStreams.tla
run_case app-future-output-streams-string \
    models/dataflow/ParslAppFutureOutputStreamsString.cfg \
    models/dataflow/ParslAppFutureOutputStreams.tla
run_case app-future-output-streams-tuple \
    models/dataflow/ParslAppFutureOutputStreamsTuple.cfg \
    models/dataflow/ParslAppFutureOutputStreams.tla
run_case data-manager-cache \
    models/staging/ParslDataManagerCacheFixed.cfg \
    models/staging/ParslDataManagerCache.tla
run_case data-manager-stage-out-return \
    models/staging/ParslDataManagerStageOutReturnFuture.cfg \
    models/staging/ParslDataManagerStageOutReturn.tla
run_case data-manager-stage-out-return-none \
    models/staging/ParslDataManagerStageOutReturnNone.cfg \
    models/staging/ParslDataManagerStageOutReturn.tla
run_case apply-message-arity \
    models/serialization/ParslApplyMessageArityFixed.cfg \
    models/serialization/ParslApplyMessageArity.tla
run_case serialization-short-frame-count \
    models/serialization/ParslSerializationShortFrameCountFixed.cfg \
    models/serialization/ParslSerializationShortFrameCount.tla
run_case serialization-truncated-length \
    models/serialization/ParslSerializationTruncatedLengthFixed.cfg \
    models/serialization/ParslSerializationTruncatedLength.tla
run_case serialization-negative-length \
    models/serialization/ParslSerializationNegativeLengthFixed.cfg \
    models/serialization/ParslSerializationNegativeLength.tla
run_case serialization-binary-payload \
    models/serialization/ParslSerializationBinaryPayload.cfg \
    models/serialization/ParslSerializationBinaryPayload.tla
run_case serialized-result-file \
    models/core/ParslSerializedResultFileFixed.cfg \
    models/core/ParslSerializedResultFile.tla
run_case result-decode-retry \
    models/core/ParslResultDecodeRetryFixed.cfg \
    models/core/ParslResultDecodeRetry.tla
run_case provider-failure-retry \
    models/core/ParslProviderFailureRetryFixed.cfg \
    models/core/ParslProviderFailureRetry.tla
run_case retry-handler-negative-cost \
    models/dataflow/ParslRetryHandlerNegativeCostFixed.cfg \
    models/dataflow/ParslRetryHandlerNegativeCost.tla
run_case retry-handler-nonnumeric-cost \
    models/dataflow/ParslRetryHandlerNonNumericCostFixed.cfg \
    models/dataflow/ParslRetryHandlerNonNumericCost.tla
run_case dataflow-cleanup \
    models/core/ParslDataFlowCleanup.cfg \
    models/core/ParslDataFlowCleanup.tla
run_case dataflow-wait-snapshot \
    models/core/ParslDataFlowWaitSnapshotFixed.cfg \
    models/core/ParslDataFlowWaitSnapshot.tla
run_case dependency-failure-propagation \
    models/dataflow/ParslDependencyFailurePropagationFixed.cfg \
    models/dataflow/ParslDependencyFailurePropagation.tla

echo "Foundational TLC smoke suite passed."
