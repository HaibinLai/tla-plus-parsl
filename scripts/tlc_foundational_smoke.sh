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
run_case callable-object-snapshot \
    models/serialization/ParslFunctionObjectContents.cfg \
    models/serialization/ParslFunctionObjectContents.tla
run_case file-bytes-transfer \
    models/staging/ParslFileBytesSmoke.cfg \
    models/staging/ParslFileBytes.tla
run_case heartbeat \
    models/clock/ParslTimedHeartbeatSmokeFixed.cfg \
    models/clock/ParslTimedHeartbeat.tla
run_case monitoring-db \
    models/monitoring/ParslMonitoringDBSmoke.cfg \
    models/monitoring/ParslMonitoringDB.tla
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
run_case kubernetes-admission \
    models/providers/ParslKubernetesAdmissionFixed.cfg \
    models/providers/ParslKubernetesAdmission.tla
run_case torque-submit-shape \
    models/providers/ParslTorqueSubmitShapeFixed.cfg \
    models/providers/ParslTorqueSubmitShape.tla
run_case local-pid-admission \
    models/providers/ParslLocalPidAdmissionFixed.cfg \
    models/providers/ParslLocalPidAdmission.tla
run_case aws-status-shape \
    models/providers/ParslAwsStatusResponseShapeFixed.cfg \
    models/providers/ParslAwsStatusResponseShape.tla
run_case google-zone-response-shape \
    models/providers/ParslGoogleCloudZoneResponseShapeFixed.cfg \
    models/providers/ParslGoogleCloudZoneResponseShape.tla
run_case provider-executor-monitoring \
    models/executors/ParslProviderExecutorTimedMonitoringFixed.cfg \
    models/executors/ParslProviderExecutorTimedMonitoring.tla
run_case join-full \
    models/dataflow/ParslJoinFull.cfg \
    models/dataflow/ParslJoinFull.tla
run_case monitoring-batch-atomicity \
    models/monitoring/ParslMonitoringBatchAtomicityFixed.cfg \
    models/monitoring/ParslMonitoringBatchAtomicity.tla
run_case monitoring-persistent-retry \
    models/monitoring/ParslMonitoringPersistentRetryFixed.cfg \
    models/monitoring/ParslMonitoringPersistentRetry.tla
run_case monitoring-db-permanent-insert \
    models/monitoring/ParslMonitoringDBPermanentErrorFixed.cfg \
    models/monitoring/ParslMonitoringDBPermanentError.tla
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
run_case slurm-foreign-job \
    models/providers/ParslSlurmForeignJobFixed.cfg \
    models/providers/ParslSlurmForeignJob.tla
run_case slurm-malformed-line \
    models/providers/ParslSlurmMalformedLineFixed.cfg \
    models/providers/ParslSlurmMalformedLine.tla
run_case slurm-tasks-per-node \
    models/providers/ParslSlurmTasksPerNodeFixed.cfg \
    models/providers/ParslSlurmTasksPerNode.tla
run_case condor-empty-submit \
    models/providers/ParslCondorEmptySubmitFixed.cfg \
    models/providers/ParslCondorEmptySubmit.tla
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
run_case grid-engine-missing-status \
    models/providers/ParslGridEngineMissingStatusFixed.cfg \
    models/providers/ParslGridEngineMissingStatus.tla
run_case lsf-missing-job \
    models/providers/ParslLSFMissingJobFixed.cfg \
    models/providers/ParslLSFMissingJob.tla
run_case lsf-resource-validation \
    models/providers/ParslLSFResourceValidationFixed.cfg \
    models/providers/ParslLSFResourceValidation.tla
run_case thread-executor-resource-spec \
    models/executors/ParslThreadExecutorResourceSpecFixed.cfg \
    models/executors/ParslThreadExecutorResourceSpec.tla
run_case workqueue-submit \
    models/executors/ParslWorkQueueSubmitFixed.cfg \
    models/executors/ParslWorkQueueSubmit.tla
run_case workqueue-submit-serialization \
    models/executors/ParslWorkQueueSubmitSerializationFailureFixed.cfg \
    models/executors/ParslWorkQueueSubmit.tla
run_case workqueue-cancelled-result \
    models/executors/ParslWorkQueueCancelledResultFixed.cfg \
    models/executors/ParslWorkQueueCancelledResult.tla
run_case taskvine-submit \
    models/executors/ParslTaskVineSubmitFixed.cfg \
    models/executors/ParslTaskVineSubmit.tla
run_case taskvine-submit-serialization \
    models/executors/ParslTaskVineSubmitSerializationFailureFixed.cfg \
    models/executors/ParslTaskVineSubmit.tla
run_case taskvine-cancelled-result \
    models/executors/ParslTaskVineCancelledResultFixed.cfg \
    models/executors/ParslTaskVineCancelledResult.tla
run_case flux-error-cleanup \
    models/executors/ParslFluxErrorCleanupCancellationFixed.cfg \
    models/executors/ParslFluxErrorCleanupCancellation.tla
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
run_case azure-submit \
    models/providers/ParslAzureProviderSubmitFixed.cfg \
    models/providers/ParslAzureProviderSubmit.tla
run_case azure-cancel \
    models/providers/ParslAzureCancelBookkeepingFixed.cfg \
    models/providers/ParslAzureCancelBookkeeping.tla
run_case azure-status-bookkeeping \
    models/providers/ParslAzureStatusBookkeepingFixed.cfg \
    models/providers/ParslAzureStatusBookkeeping.tla
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
run_case mpi-no-resource-result \
    models/executors/ParslMPINoResourceResultFixed.cfg \
    models/executors/ParslMPINoResourceResult.tla
run_case radical-failure-payload \
    models/executors/ParslRadicalPilotFailurePayloadFixed.cfg \
    models/executors/ParslRadicalPilotFailurePayload.tla
run_case radical-failure-fanout \
    models/executors/ParslRadicalFailureFanoutFixed.cfg \
    models/executors/ParslRadicalFailureFanout.tla
run_case radical-late-callback \
    models/executors/ParslRadicalPilotLateCallbackFixed.cfg \
    models/executors/ParslRadicalPilotLateCallback.tla
run_case radical-unknown-callback \
    models/executors/ParslRadicalPilotUnknownCallbackFixed.cfg \
    models/executors/ParslRadicalPilotUnknownCallback.tla
run_case radical-bulk-shutdown \
    models/executors/ParslRadicalPilotBulkShutdownFixed.cfg \
    models/executors/ParslRadicalPilotBulkShutdown.tla
run_case dynamic-task-chain \
    models/dataflow/ParslDynamicTaskChain.cfg \
    models/dataflow/ParslDynamicTaskChain.tla
run_case dynamic-task-creation \
    models/dataflow/ParslDynamicTaskCreation.cfg \
    models/dataflow/ParslDynamicTaskCreation.tla
run_case dynamic-task-fanout \
    models/dataflow/ParslDynamicTaskFanout.cfg \
    models/dataflow/ParslDynamicTaskFanout.tla
run_case memo-function-identity \
    models/dataflow/ParslMemoFunctionIdentityFixed.cfg \
    models/dataflow/ParslMemoFunctionIdentity.tla
run_case memo-dict-ordering \
    models/dataflow/ParslMemoDictOrderingFixed.cfg \
    models/dataflow/ParslMemoDictOrdering.tla
run_case memo-ignore-key \
    models/dataflow/ParslMemoIgnoreKeyFixed.cfg \
    models/dataflow/ParslMemoIgnoreKey.tla
run_case task-status-future-ordering \
    models/dataflow/ParslTaskStatusFutureOrderingFixed.cfg \
    models/dataflow/ParslTaskStatusFutureOrdering.tla
run_case block-provider-bad-state-ordering \
    models/executors/ParslBlockProviderBadStateOrderingFixed.cfg \
    models/executors/ParslBlockProviderBadStateOrdering.tla
run_case block-provider-bad-state-mutation \
    models/executors/ParslBlockProviderBadStateMutationFixed.cfg \
    models/executors/ParslBlockProviderBadStateMutation.tla
run_case cluster-provider-unknown-job \
    models/providers/ParslClusterProviderUnknownJobFixed.cfg \
    models/providers/ParslClusterProviderUnknownJob.tla
run_case local-provider-submit-cleanup \
    models/providers/ParslLocalProviderSubmitCleanupFixed.cfg \
    models/providers/ParslLocalProviderSubmitCleanup.tla
run_case local-provider-cancel-unknown \
    models/providers/ParslLocalProviderCancelUnknownFixed.cfg \
    models/providers/ParslLocalProviderCancelUnknown.tla
run_case local-submit-pid-shape \
    models/providers/ParslLocalSubmitPidShapeFixed.cfg \
    models/providers/ParslLocalSubmitPidShape.tla
run_case poller-close-scale-in \
    models/providers/ParslPollerCloseScaleInRaceFixed.cfg \
    models/providers/ParslPollerCloseScaleInRace.tla
run_case poller-duplicate-executor \
    models/providers/ParslPollerDuplicateExecutorFixed.cfg \
    models/providers/ParslPollerDuplicateExecutor.tla
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
run_case join-return-shape \
    models/dataflow/ParslJoinReturnShapeFuture.cfg \
    models/dataflow/ParslJoinReturnShape.tla
run_case htex-cancelled-result \
    models/executors/ParslHtexCancelledResultFixed.cfg \
    models/executors/ParslHtexCancelledResult.tla
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
run_case monitoring-lifecycle-bookkeeping \
    models/monitoring/ParslMonitoringLifecycleBookkeepingFixed.cfg \
    models/monitoring/ParslMonitoringLifecycleBookkeeping.tla
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
run_case globus-transfer-timeout \
    models/staging/ParslGlobusTransferTimeoutFixed.cfg \
    models/staging/ParslGlobusTransferTimeout.tla
run_case http-connection-cleanup \
    models/staging/ParslHTTPConnectionCleanupFixed.cfg \
    models/staging/ParslHTTPConnectionCleanup.tla
run_case http-separate-task-cleanup \
    models/staging/ParslHTTPSeparateTaskCleanupFixed.cfg \
    models/staging/ParslHTTPSeparateTaskCleanup.tla
run_case http-status-validation \
    models/staging/ParslHTTPStatusValidationFixed.cfg \
    models/staging/ParslHTTPStatusValidation.tla
run_case rsync-partial-cleanup \
    models/staging/ParslRsyncPartialCleanupFixed.cfg \
    models/staging/ParslRsyncPartialCleanup.tla
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
run_case kubernetes-empty-phase \
    models/providers/ParslKubernetesEmptyPhaseFixed.cfg \
    models/providers/ParslKubernetesEmptyPhase.tla
run_case kubernetes-cancel-response \
    models/providers/ParslKubernetesCancelResponseFixed.cfg \
    models/providers/ParslKubernetesCancelResponse.tla
run_case kubernetes-cancel-unknown-job \
    models/providers/ParslKubernetesCancelUnknownJobFixed.cfg \
    models/providers/ParslKubernetesCancelUnknownJob.tla
run_case condor-chunk-size \
    models/providers/ParslCondorChunkSizeFixed.cfg \
    models/providers/ParslCondorChunkSize.tla
run_case condor-status-failure \
    models/providers/ParslCondorStatusFailureFixedMalformed.cfg \
    models/providers/ParslCondorStatusFailure.tla
run_case slurm-batch-strict \
    models/providers/ParslSlurmBatchStrictFixed.cfg \
    models/providers/ParslSlurmBatchStrict.tla
run_case slurm-cancel-batch \
    models/providers/ParslSlurmCancelBatchFixed.cfg \
    models/providers/ParslSlurmCancelBatch.tla
run_case slurm-duplicate-status \
    models/providers/ParslSlurmDuplicateStatusFixed.cfg \
    models/providers/ParslSlurmDuplicateStatus.tla
run_case slurm-empty-job-id \
    models/providers/ParslSlurmEmptyJobIdFixed.cfg \
    models/providers/ParslSlurmEmptyJobId.tla

echo "Foundational TLC smoke suite passed."
