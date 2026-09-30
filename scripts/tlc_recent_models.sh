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
run_case input-list-mutation-current counterexample \
    models/dataflow/ParslInputListMutationCurrent.cfg \
    models/dataflow/ParslInputListMutation.tla
run_case input-list-mutation-fixed pass \
    models/dataflow/ParslInputListMutationFixed.cfg \
    models/dataflow/ParslInputListMutation.tla
run_case output-list-mutation-current counterexample \
    models/dataflow/ParslOutputListMutationCurrent.cfg \
    models/dataflow/ParslOutputListMutation.tla
run_case output-list-mutation-fixed pass \
    models/dataflow/ParslOutputListMutationFixed.cfg \
    models/dataflow/ParslOutputListMutation.tla
run_case executor-kinds pass \
    models/executors/ParslExecutorKinds.cfg \
    models/executors/ParslExecutorKinds.tla
run_case negative-scale-in-current counterexample \
    models/executors/ParslNegativeScaleInCurrent.cfg \
    models/executors/ParslNegativeScaleIn.tla
run_case negative-scale-in-fixed pass \
    models/executors/ParslNegativeScaleInFixed.cfg \
    models/executors/ParslNegativeScaleIn.tla
run_case strategy pass \
    models/strategy/ParslStrategy.cfg \
    models/strategy/ParslStrategy.tla
run_case strategy-block-capacity-current counterexample \
    models/strategy/ParslStrategyBlockCapacityCurrent.cfg \
    models/strategy/ParslStrategyBlockCapacity.tla
run_case strategy-block-capacity-fixed pass \
    models/strategy/ParslStrategyBlockCapacityFixed.cfg \
    models/strategy/ParslStrategyBlockCapacity.tla
run_case strategy-block-capacity-success pass \
    models/strategy/ParslStrategyBlockCapacitySuccess.cfg \
    models/strategy/ParslStrategyBlockCapacity.tla
run_case aws-provider-cancel pass \
    models/providers/ParslAWSProviderCancel.cfg \
    models/providers/ParslAWSProviderCancel.tla
run_case aws-provider-cancel-linger pass \
    models/providers/ParslAWSProviderCancelLinger.cfg \
    models/providers/ParslAWSProviderCancel.tla
run_case local-provider-current counterexample \
    models/providers/ParslLocalProvider.cfg \
    models/providers/ParslLocalProvider.tla
run_case flux-cancel-submit-race-current counterexample \
    models/executors/ParslFluxCancelSubmitRaceCurrent.cfg \
    models/executors/ParslFluxCancelSubmitRace.tla
run_case flux-cancel-submit-race-fixed pass \
    models/executors/ParslFluxCancelSubmitRaceFixed.cfg \
    models/executors/ParslFluxCancelSubmitRace.tla
run_case flux-cancel-underlying-current counterexample \
    models/executors/ParslFluxCancelUnderlyingStateCurrent.cfg \
    models/executors/ParslFluxCancelUnderlyingState.tla
run_case flux-cancel-underlying-fixed pass \
    models/executors/ParslFluxCancelUnderlyingStateFixed.cfg \
    models/executors/ParslFluxCancelUnderlyingState.tla
run_case flux-provider-status-empty-current counterexample \
    models/executors/ParslFluxProviderStatusEmptyCurrent.cfg \
    models/executors/ParslFluxProviderStatusEmpty.tla
run_case flux-provider-status-empty-fixed pass \
    models/executors/ParslFluxProviderStatusEmptyFixed.cfg \
    models/executors/ParslFluxProviderStatusEmpty.tla
run_case flux-result-current counterexample \
    models/executors/ParslFluxResult.cfg \
    models/executors/ParslFluxResult.tla
run_case flux-result-fixed pass \
    models/executors/ParslFluxResultFixed.cfg \
    models/executors/ParslFluxResult.tla
run_case htex-address-probe-timeout-current counterexample \
    models/executors/ParslHtexAddressProbeTimeoutCurrent.cfg \
    models/executors/ParslHtexAddressProbeTimeout.tla
run_case htex-address-probe-timeout-fixed pass \
    models/executors/ParslHtexAddressProbeTimeoutFixed.cfg \
    models/executors/ParslHtexAddressProbeTimeout.tla
run_case htex-address-probe-timeout-valid pass \
    models/executors/ParslHtexAddressProbeTimeoutValid.cfg \
    models/executors/ParslHtexAddressProbeTimeout.tla
run_case htex-cores-per-worker-current counterexample \
    models/executors/ParslHtexCoresPerWorkerCurrent.cfg \
    models/executors/ParslHtexCoresPerWorker.tla
run_case htex-cores-per-worker-fixed pass \
    models/executors/ParslHtexCoresPerWorkerFixed.cfg \
    models/executors/ParslHtexCoresPerWorker.tla
run_case htex-cores-per-worker-valid pass \
    models/executors/ParslHtexCoresPerWorkerValid.cfg \
    models/executors/ParslHtexCoresPerWorker.tla
run_case htex-dispatch-priority pass \
    models/executors/ParslHtexDispatchPriority.cfg \
    models/executors/ParslHtexDispatchPriority.tla
run_case htex-version-mismatch-current counterexample \
    models/executors/ParslHtexVersionMismatch.cfg \
    models/executors/ParslHtexVersionMismatch.tla
run_case htex-version-mismatch-fixed pass \
    models/executors/ParslHtexVersionMismatchFixed.cfg \
    models/executors/ParslHtexVersionMismatch.tla
run_case htex-task-id-type-current counterexample \
    models/executors/ParslHtexTaskIdTypeCurrent.cfg \
    models/executors/ParslHtexTaskIdType.tla
run_case htex-task-id-type-fixed pass \
    models/executors/ParslHtexTaskIdTypeFixed.cfg \
    models/executors/ParslHtexTaskIdType.tla
run_case htex-task-context-type-current counterexample \
    models/executors/ParslHtexTaskContextTypeCurrent.cfg \
    models/executors/ParslHtexTaskContextType.tla
run_case htex-task-context-type-fixed pass \
    models/executors/ParslHtexTaskContextTypeFixed.cfg \
    models/executors/ParslHtexTaskContextType.tla
run_case htex-manager-loss-current counterexample \
    models/executors/ParslHtexManagerLossCurrent.cfg \
    models/executors/ParslHtexManagerLoss.tla
run_case htex-manager-loss-fixed pass \
    models/executors/ParslHtexManagerLossFixed.cfg \
    models/executors/ParslHtexManagerLoss.tla
run_case htex-manager-task-admission-current pass \
    models/executors/ParslHtexManagerTaskAdmissionCurrent.cfg \
    models/executors/ParslHtexManagerTaskAdmission.tla
run_case htex-manager-task-admission-fixed pass \
    models/executors/ParslHtexManagerTaskAdmissionFixed.cfg \
    models/executors/ParslHtexManagerTaskAdmission.tla
run_case htex-worker-task-batch-shape-current counterexample \
    models/executors/ParslHtexWorkerTaskBatchShapeCurrent.cfg \
    models/executors/ParslHtexWorkerTaskBatchShape.tla
run_case htex-worker-task-batch-shape-fixed pass \
    models/executors/ParslHtexWorkerTaskBatchShapeFixed.cfg \
    models/executors/ParslHtexWorkerTaskBatchShape.tla
run_case htex-worker-task-frame-current counterexample \
    models/executors/ParslHtexWorkerTaskFrameContinuationCurrent.cfg \
    models/executors/ParslHtexWorkerTaskFrameContinuation.tla
run_case htex-worker-task-frame-fixed pass \
    models/executors/ParslHtexWorkerTaskFrameContinuationFixed.cfg \
    models/executors/ParslHtexWorkerTaskFrameContinuation.tla
run_case htex-monitoring-message-current counterexample \
    models/executors/ParslHtexMonitoringMessageCurrent.cfg \
    models/executors/ParslHtexMonitoringMessage.tla
run_case htex-monitoring-message-enabled pass \
    models/executors/ParslHtexMonitoringMessageEnabled.cfg \
    models/executors/ParslHtexMonitoringMessage.tla
run_case htex-monitoring-message-fixed pass \
    models/executors/ParslHtexMonitoringMessageFixed.cfg \
    models/executors/ParslHtexMonitoringMessage.tla
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
run_case provider-polling pass \
    models/providers/ParslProviderPolling.cfg \
    models/providers/ParslProviderPolling.tla
run_case provider-status-shape-current counterexample \
    models/executors/ParslProviderStatusShapeCurrent.cfg \
    models/executors/ParslProviderStatusShape.tla
run_case provider-status-shape-fixed pass \
    models/executors/ParslProviderStatusShapeFixed.cfg \
    models/executors/ParslProviderStatusShape.tla
run_case poller-bad-state pass \
    models/providers/ParslPollerBadState.cfg \
    models/providers/ParslPollerBadState.tla
run_case provider-kinds pass \
    models/providers/ParslProviderKinds.cfg \
    models/providers/ParslProviderKinds.tla
run_case aws-provider-status-current counterexample \
    models/providers/ParslAWSProviderStatus.cfg \
    models/providers/ParslAWSProviderStatus.tla
run_case aws-provider-status-fixed pass \
    models/providers/ParslAWSProviderStatusFixed.cfg \
    models/providers/ParslAWSProviderStatus.tla
run_case aws-provider-status-present pass \
    models/providers/ParslAWSProviderStatusPresent.cfg \
    models/providers/ParslAWSProviderStatus.tla
run_case azure-status-running pass \
    models/providers/ParslAzureStatus.cfg \
    models/providers/ParslAzureStatus.tla
run_case azure-status-short-view pass \
    models/providers/ParslAzureStatusShortView.cfg \
    models/providers/ParslAzureStatus.tla
run_case azure-status-unknown pass \
    models/providers/ParslAzureStatusUnknown.cfg \
    models/providers/ParslAzureStatus.tla
run_case azure-status-bookkeeping-current counterexample \
    models/providers/ParslAzureStatusBookkeepingCurrent.cfg \
    models/providers/ParslAzureStatusBookkeeping.tla
run_case azure-status-bookkeeping-fixed pass \
    models/providers/ParslAzureStatusBookkeepingFixed.cfg \
    models/providers/ParslAzureStatusBookkeeping.tla
run_case azure-submit-current counterexample \
    models/providers/ParslAzureProviderSubmit.cfg \
    models/providers/ParslAzureProviderSubmit.tla
run_case azure-submit-fixed pass \
    models/providers/ParslAzureProviderSubmitFixed.cfg \
    models/providers/ParslAzureProviderSubmit.tla
run_case azure-cancel-missing-current counterexample \
    models/providers/ParslAzureCancelMissingCurrent.cfg \
    models/providers/ParslAzureCancel.tla
run_case azure-cancel-missing-fixed pass \
    models/providers/ParslAzureCancelMissingFixed.cfg \
    models/providers/ParslAzureCancel.tla
run_case azure-cancel-normal pass \
    models/providers/ParslAzureCancel.cfg \
    models/providers/ParslAzureCancel.tla
run_case azure-cancel-linger pass \
    models/providers/ParslAzureCancelLinger.cfg \
    models/providers/ParslAzureCancel.tla
run_case google-zone-selection-current counterexample \
    models/providers/ParslGoogleCloudZoneSelectionCurrent.cfg \
    models/providers/ParslGoogleCloudZoneSelection.tla
run_case google-zone-selection-fixed pass \
    models/providers/ParslGoogleCloudZoneSelectionFixed.cfg \
    models/providers/ParslGoogleCloudZoneSelection.tla
run_case google-zone-selection-valid pass \
    models/providers/ParslGoogleCloudZoneSelectionValid.cfg \
    models/providers/ParslGoogleCloudZoneSelection.tla
run_case google-status-current counterexample \
    models/providers/ParslGoogleCloudStatus.cfg \
    models/providers/ParslGoogleCloudStatus.tla
run_case google-status-fixed pass \
    models/providers/ParslGoogleCloudStatusFixed.cfg \
    models/providers/ParslGoogleCloudStatus.tla
run_case google-status-present pass \
    models/providers/ParslGoogleCloudStatusPresent.cfg \
    models/providers/ParslGoogleCloudStatus.tla
run_case google-submit-current counterexample \
    models/providers/ParslGoogleCloudSubmit.cfg \
    models/providers/ParslGoogleCloudSubmit.tla
run_case google-submit-fixed pass \
    models/providers/ParslGoogleCloudSubmitFixed.cfg \
    models/providers/ParslGoogleCloudSubmit.tla
run_case google-cancel-current counterexample \
    models/providers/ParslGoogleCloudCancel.cfg \
    models/providers/ParslGoogleCloudCancel.tla
run_case google-cancel-failure pass \
    models/providers/ParslGoogleCloudCancelFailure.cfg \
    models/providers/ParslGoogleCloudCancel.tla
run_case google-cancel-fixed pass \
    models/providers/ParslGoogleCloudCancelFixed.cfg \
    models/providers/ParslGoogleCloudCancel.tla
run_case condor-cancel pass \
    models/providers/ParslCondorCancel.cfg \
    models/providers/ParslCondorCancel.tla
run_case condor-cancel-failure pass \
    models/providers/ParslCondorCancelFailure.cfg \
    models/providers/ParslCondorCancel.tla
run_case condor-chunk-size-current counterexample \
    models/providers/ParslCondorChunkSizeCurrent.cfg \
    models/providers/ParslCondorChunkSize.tla
run_case condor-chunk-size-fixed pass \
    models/providers/ParslCondorChunkSizeFixed.cfg \
    models/providers/ParslCondorChunkSize.tla
run_case condor-chunk-size-valid pass \
    models/providers/ParslCondorChunkSizeValid.cfg \
    models/providers/ParslCondorChunkSize.tla
run_case condor-malformed-line-current counterexample \
    models/providers/ParslCondorMalformedStatusLineCurrent.cfg \
    models/providers/ParslCondorMalformedStatusLine.tla
run_case condor-malformed-line-fixed pass \
    models/providers/ParslCondorMalformedStatusLineFixed.cfg \
    models/providers/ParslCondorMalformedStatusLine.tla
run_case condor-status-current counterexample \
    models/providers/ParslCondorStatus.cfg \
    models/providers/ParslCondorStatus.tla
run_case condor-status-fixed pass \
    models/providers/ParslCondorStatusFixed.cfg \
    models/providers/ParslCondorStatus.tla
run_case condor-status-present pass \
    models/providers/ParslCondorStatusPresent.cfg \
    models/providers/ParslCondorStatus.tla
run_case condor-status-failure-current-malformed counterexample \
    models/providers/ParslCondorStatusFailureCurrentMalformed.cfg \
    models/providers/ParslCondorStatusFailure.tla
run_case condor-status-failure-current-valid counterexample \
    models/providers/ParslCondorStatusFailureCurrentValid.cfg \
    models/providers/ParslCondorStatusFailure.tla
run_case condor-status-failure-fixed-malformed pass \
    models/providers/ParslCondorStatusFailureFixedMalformed.cfg \
    models/providers/ParslCondorStatusFailure.tla
run_case condor-status-failure-fixed-valid pass \
    models/providers/ParslCondorStatusFailureFixedValid.cfg \
    models/providers/ParslCondorStatusFailure.tla
run_case condor-status-failure-success pass \
    models/providers/ParslCondorStatusFailureSuccess.cfg \
    models/providers/ParslCondorStatusFailure.tla
run_case condor-submit-current counterexample \
    models/providers/ParslCondorSubmit.cfg \
    models/providers/ParslCondorSubmit.tla
run_case condor-submit-fixed pass \
    models/providers/ParslCondorSubmitFixed.cfg \
    models/providers/ParslCondorSubmit.tla
run_case condor-unknown-job-current counterexample \
    models/providers/ParslCondorUnknownJobCurrent.cfg \
    models/providers/ParslCondorUnknownJob.tla
run_case condor-unknown-job-fixed pass \
    models/providers/ParslCondorUnknownJobFixed.cfg \
    models/providers/ParslCondorUnknownJob.tla
run_case grid-cancel pass \
    models/providers/ParslGridEngineCancel.cfg \
    models/providers/ParslGridEngineCancel.tla
run_case grid-cancel-failure pass \
    models/providers/ParslGridEngineCancelFailure.cfg \
    models/providers/ParslGridEngineCancel.tla
run_case grid-cancel-fixed pass \
    models/providers/ParslGridEngineCancelFixed.cfg \
    models/providers/ParslGridEngineCancel.tla
run_case grid-cancel-unknown-current counterexample \
    models/providers/ParslGridEngineCancelUnknown.cfg \
    models/providers/ParslGridEngineCancel.tla
run_case grid-cancel-valid pass \
    models/providers/ParslGridEngineCancelValid.cfg \
    models/providers/ParslGridEngineCancel.tla
run_case grid-duplicate-status-current counterexample \
    models/providers/ParslGridEngineDuplicateStatusCurrent.cfg \
    models/providers/ParslGridEngineDuplicateStatus.tla
run_case grid-duplicate-status-fixed pass \
    models/providers/ParslGridEngineDuplicateStatusFixed.cfg \
    models/providers/ParslGridEngineDuplicateStatus.tla
run_case grid-duplicate-status-unique pass \
    models/providers/ParslGridEngineDuplicateStatusUnique.cfg \
    models/providers/ParslGridEngineDuplicateStatus.tla
run_case grid-status-current counterexample \
    models/providers/ParslGridEngineStatus.cfg \
    models/providers/ParslGridEngineStatus.tla
run_case grid-status-fixed pass \
    models/providers/ParslGridEngineStatusFixed.cfg \
    models/providers/ParslGridEngineStatus.tla
run_case grid-status-present pass \
    models/providers/ParslGridEngineStatusPresent.cfg \
    models/providers/ParslGridEngineStatus.tla
run_case grid-status-batch-current counterexample \
    models/providers/ParslGridEngineStatusBatchCurrent.cfg \
    models/providers/ParslGridEngineStatusBatch.tla
run_case grid-status-batch-fixed pass \
    models/providers/ParslGridEngineStatusBatchFixed.cfg \
    models/providers/ParslGridEngineStatusBatch.tla
run_case grid-submit-empty pass \
    models/providers/ParslGridEngineSubmitEmpty.cfg \
    models/providers/ParslGridEngineSubmit.tla
run_case grid-submit-failure pass \
    models/providers/ParslGridEngineSubmitFailure.cfg \
    models/providers/ParslGridEngineSubmit.tla
run_case grid-submit-job pass \
    models/providers/ParslGridEngineSubmitJob.cfg \
    models/providers/ParslGridEngineSubmit.tla
run_case lsf-cancel pass \
    models/providers/ParslLSFCancel.cfg \
    models/providers/ParslLSFCancel.tla
run_case lsf-cancel-failure pass \
    models/providers/ParslLSFCancelFailure.cfg \
    models/providers/ParslLSFCancel.tla
run_case lsf-cancel-fixed pass \
    models/providers/ParslLSFCancelFixed.cfg \
    models/providers/ParslLSFCancel.tla
run_case lsf-cancel-unknown-current counterexample \
    models/providers/ParslLSFCancelUnknown.cfg \
    models/providers/ParslLSFCancel.tla
run_case lsf-cancel-valid pass \
    models/providers/ParslLSFCancelValid.cfg \
    models/providers/ParslLSFCancel.tla
run_case lsf-duplicate-status-current counterexample \
    models/providers/ParslLSFDuplicateStatusCurrent.cfg \
    models/providers/ParslLSFDuplicateStatus.tla
run_case lsf-duplicate-status-fixed pass \
    models/providers/ParslLSFDuplicateStatusFixed.cfg \
    models/providers/ParslLSFDuplicateStatus.tla
run_case lsf-duplicate-status-unique pass \
    models/providers/ParslLSFDuplicateStatusUnique.cfg \
    models/providers/ParslLSFDuplicateStatus.tla
run_case lsf-missing-job-current counterexample \
    models/providers/ParslLSFMissingJobCurrent.cfg \
    models/providers/ParslLSFMissingJob.tla
run_case lsf-missing-job-fixed pass \
    models/providers/ParslLSFMissingJobFixed.cfg \
    models/providers/ParslLSFMissingJob.tla
run_case lsf-resource-current counterexample \
    models/providers/ParslLSFResourceValidationCurrent.cfg \
    models/providers/ParslLSFResourceValidation.tla
run_case lsf-resource-fixed pass \
    models/providers/ParslLSFResourceValidationFixed.cfg \
    models/providers/ParslLSFResourceValidation.tla
run_case lsf-resource-valid pass \
    models/providers/ParslLSFResourceValidationValid.cfg \
    models/providers/ParslLSFResourceValidation.tla
run_case lsf-submit pass \
    models/providers/ParslLSFSubmit.cfg \
    models/providers/ParslLSFSubmit.tla
run_case lsf-submit-failure pass \
    models/providers/ParslLSFSubmitFailure.cfg \
    models/providers/ParslLSFSubmit.tla
run_case lsf-submit-malformed pass \
    models/providers/ParslLSFSubmitMalformed.cfg \
    models/providers/ParslLSFSubmit.tla
run_case slurm-batch-strict-current counterexample \
    models/providers/ParslSlurmBatchStrictCurrent.cfg \
    models/providers/ParslSlurmBatchStrict.tla
run_case slurm-batch-strict-fixed pass \
    models/providers/ParslSlurmBatchStrictFixed.cfg \
    models/providers/ParslSlurmBatchStrict.tla
run_case slurm-batch-strict-valid pass \
    models/providers/ParslSlurmBatchStrictValid.cfg \
    models/providers/ParslSlurmBatchStrict.tla
run_case slurm-cancel-current counterexample \
    models/providers/ParslSlurmCancel.cfg \
    models/providers/ParslSlurmCancel.tla
run_case slurm-cancel-failure pass \
    models/providers/ParslSlurmCancelFailure.cfg \
    models/providers/ParslSlurmCancel.tla
run_case slurm-cancel-fixed pass \
    models/providers/ParslSlurmCancelFixed.cfg \
    models/providers/ParslSlurmCancel.tla
run_case slurm-duplicate-status-current counterexample \
    models/providers/ParslSlurmDuplicateStatusCurrent.cfg \
    models/providers/ParslSlurmDuplicateStatus.tla
run_case slurm-duplicate-status-fixed pass \
    models/providers/ParslSlurmDuplicateStatusFixed.cfg \
    models/providers/ParslSlurmDuplicateStatus.tla
run_case slurm-duplicate-status-unique pass \
    models/providers/ParslSlurmDuplicateStatusUnique.cfg \
    models/providers/ParslSlurmDuplicateStatus.tla
run_case slurm-foreign-job-current counterexample \
    models/providers/ParslSlurmForeignJobCurrent.cfg \
    models/providers/ParslSlurmForeignJob.tla
run_case slurm-foreign-job-fixed pass \
    models/providers/ParslSlurmForeignJobFixed.cfg \
    models/providers/ParslSlurmForeignJob.tla
run_case slurm-malformed-line-current counterexample \
    models/providers/ParslSlurmMalformedLineCurrent.cfg \
    models/providers/ParslSlurmMalformedLine.tla
run_case slurm-malformed-line-fixed pass \
    models/providers/ParslSlurmMalformedLineFixed.cfg \
    models/providers/ParslSlurmMalformedLine.tla
run_case slurm-status-current counterexample \
    models/providers/ParslSlurmStatusCurrent.cfg \
    models/providers/ParslSlurmStatus.tla
run_case slurm-status-fixed pass \
    models/providers/ParslSlurmStatusFixed.cfg \
    models/providers/ParslSlurmStatus.tla
run_case slurm-submit-current counterexample \
    models/providers/ParslSlurmSubmit.cfg \
    models/providers/ParslSlurmSubmit.tla
run_case slurm-submit-fixed pass \
    models/providers/ParslSlurmSubmitFixed.cfg \
    models/providers/ParslSlurmSubmit.tla
run_case pbspro-job-alias-current counterexample \
    models/providers/ParslPBSProJobIdAliasCurrent.cfg \
    models/providers/ParslPBSProJobIdAlias.tla
run_case pbspro-job-alias-fixed pass \
    models/providers/ParslPBSProJobIdAliasFixed.cfg \
    models/providers/ParslPBSProJobIdAlias.tla
run_case pbspro-job-alias-unique pass \
    models/providers/ParslPBSProJobIdAliasUnique.cfg \
    models/providers/ParslPBSProJobIdAlias.tla
run_case pbspro-malformed-json-current counterexample \
    models/providers/ParslPBSProMalformedJSONCurrent.cfg \
    models/providers/ParslPBSProMalformedJSON.tla
run_case pbspro-malformed-json-fixed pass \
    models/providers/ParslPBSProMalformedJSONFixed.cfg \
    models/providers/ParslPBSProMalformedJSON.tla
run_case pbspro-status-current counterexample \
    models/providers/ParslPBSProStatus.cfg \
    models/providers/ParslPBSProStatus.tla
run_case pbspro-status-fixed pass \
    models/providers/ParslPBSProStatusFixed.cfg \
    models/providers/ParslPBSProStatus.tla
run_case pbspro-status-known pass \
    models/providers/ParslPBSProStatusKnown.cfg \
    models/providers/ParslPBSProStatus.tla
run_case pbspro-submit-current counterexample \
    models/providers/ParslPBSProSubmit.cfg \
    models/providers/ParslPBSProSubmit.tla
run_case pbspro-submit-fixed pass \
    models/providers/ParslPBSProSubmitFixed.cfg \
    models/providers/ParslPBSProSubmit.tla
run_case pbspro-submit-present pass \
    models/providers/ParslPBSProSubmitPresent.cfg \
    models/providers/ParslPBSProSubmit.tla
run_case torque-cancel-current counterexample \
    models/providers/ParslTorqueCancel.cfg \
    models/providers/ParslTorqueCancel.tla
run_case torque-cancel-failure pass \
    models/providers/ParslTorqueCancelFailure.cfg \
    models/providers/ParslTorqueCancel.tla
run_case torque-cancel-fixed pass \
    models/providers/ParslTorqueCancelFixed.cfg \
    models/providers/ParslTorqueCancel.tla
run_case torque-duplicate-status-current counterexample \
    models/providers/ParslTorqueDuplicateStatusCurrent.cfg \
    models/providers/ParslTorqueDuplicateStatus.tla
run_case torque-duplicate-status-fixed pass \
    models/providers/ParslTorqueDuplicateStatusFixed.cfg \
    models/providers/ParslTorqueDuplicateStatus.tla
run_case torque-duplicate-status-unique pass \
    models/providers/ParslTorqueDuplicateStatusUnique.cfg \
    models/providers/ParslTorqueDuplicateStatus.tla
run_case torque-status-current counterexample \
    models/providers/ParslTorqueStatus.cfg \
    models/providers/ParslTorqueStatus.tla
run_case torque-status-fixed pass \
    models/providers/ParslTorqueStatusFixed.cfg \
    models/providers/ParslTorqueStatus.tla
run_case torque-status-present pass \
    models/providers/ParslTorqueStatusPresent.cfg \
    models/providers/ParslTorqueStatus.tla
run_case torque-status-failure-current counterexample \
    models/providers/ParslTorqueStatusFailureCurrent.cfg \
    models/providers/ParslTorqueStatusFailure.tla
run_case torque-status-failure-fixed pass \
    models/providers/ParslTorqueStatusFailureFixed.cfg \
    models/providers/ParslTorqueStatusFailure.tla
run_case torque-submit pass \
    models/providers/ParslTorqueSubmit.cfg \
    models/providers/ParslTorqueSubmit.tla
run_case torque-submit-empty pass \
    models/providers/ParslTorqueSubmitEmpty.cfg \
    models/providers/ParslTorqueSubmit.tla
run_case torque-submit-failure pass \
    models/providers/ParslTorqueSubmitFailure.cfg \
    models/providers/ParslTorqueSubmit.tla
run_case torque-tasks-current counterexample \
    models/providers/ParslTorqueTasksPerNodeCurrent.cfg \
    models/providers/ParslTorqueTasksPerNode.tla
run_case torque-tasks-fixed pass \
    models/providers/ParslTorqueTasksPerNodeFixed.cfg \
    models/providers/ParslTorqueTasksPerNode.tla
run_case torque-tasks-valid pass \
    models/providers/ParslTorqueTasksPerNodeValid.cfg \
    models/providers/ParslTorqueTasksPerNode.tla
run_case local-exit-file-current counterexample \
    models/providers/ParslLocalExitFileMissingCurrent.cfg \
    models/providers/ParslLocalExitFileMissing.tla
run_case local-exit-file-fixed pass \
    models/providers/ParslLocalExitFileMissingFixed.cfg \
    models/providers/ParslLocalExitFileMissing.tla
run_case local-provider-current counterexample \
    models/providers/ParslLocalProviderCurrent.cfg \
    models/providers/ParslLocalProvider.tla
run_case local-provider-fixed pass \
    models/providers/ParslLocalProviderFixed.cfg \
    models/providers/ParslLocalProvider.tla
run_case local-exit-status pass \
    models/providers/ParslLocalProviderExitStatus.cfg \
    models/providers/ParslLocalProviderExitStatus.tla
run_case local-cancel-unknown-current counterexample \
    models/providers/ParslLocalProviderCancelUnknownCurrent.cfg \
    models/providers/ParslLocalProviderCancelUnknown.tla
run_case local-cancel-unknown-fixed pass \
    models/providers/ParslLocalProviderCancelUnknownFixed.cfg \
    models/providers/ParslLocalProviderCancelUnknown.tla
run_case local-status-scope-current counterexample \
    models/providers/ParslLocalProviderStatusScope.cfg \
    models/providers/ParslLocalProviderStatusScope.tla
run_case local-status-scope-fixed pass \
    models/providers/ParslLocalProviderStatusScopeFixed.cfg \
    models/providers/ParslLocalProviderStatusScope.tla
run_case local-submit-cleanup-current counterexample \
    models/providers/ParslLocalProviderSubmitCleanupCurrent.cfg \
    models/providers/ParslLocalProviderSubmitCleanup.tla
run_case local-submit-cleanup-fixed pass \
    models/providers/ParslLocalProviderSubmitCleanupFixed.cfg \
    models/providers/ParslLocalProviderSubmitCleanup.tla
run_case local-submit-cleanup-success pass \
    models/providers/ParslLocalProviderSubmitCleanupSuccess.cfg \
    models/providers/ParslLocalProviderSubmitCleanup.tla
run_case local-tasks-current counterexample \
    models/providers/ParslLocalTasksPerNodeCurrent.cfg \
    models/providers/ParslLocalTasksPerNode.tla
run_case local-tasks-fixed pass \
    models/providers/ParslLocalTasksPerNodeFixed.cfg \
    models/providers/ParslLocalTasksPerNode.tla
run_case local-tasks-valid pass \
    models/providers/ParslLocalTasksPerNodeValid.cfg \
    models/providers/ParslLocalTasksPerNode.tla
run_case local-unknown-job-current counterexample \
    models/providers/ParslLocalUnknownJobStatusCurrent.cfg \
    models/providers/ParslLocalUnknownJobStatus.tla
run_case local-unknown-job-fixed pass \
    models/providers/ParslLocalUnknownJobStatusFixed.cfg \
    models/providers/ParslLocalUnknownJobStatus.tla
run_case kubernetes-admission-current counterexample \
    models/providers/ParslKubernetesAdmissionCurrent.cfg \
    models/providers/ParslKubernetesAdmission.tla
run_case kubernetes-admission-fixed pass \
    models/providers/ParslKubernetesAdmissionFixed.cfg \
    models/providers/ParslKubernetesAdmission.tla
run_case kubernetes-cancel-current counterexample \
    models/providers/ParslKubernetesCancel.cfg \
    models/providers/ParslKubernetesCancel.tla
run_case kubernetes-cancel-fixed pass \
    models/providers/ParslKubernetesCancelFixed.cfg \
    models/providers/ParslKubernetesCancel.tla
run_case kubernetes-cancel-unknown-current counterexample \
    models/providers/ParslKubernetesCancelUnknownJobCurrent.cfg \
    models/providers/ParslKubernetesCancelUnknownJob.tla
run_case kubernetes-cancel-unknown-fixed pass \
    models/providers/ParslKubernetesCancelUnknownJobFixed.cfg \
    models/providers/ParslKubernetesCancelUnknownJob.tla
run_case kubernetes-polling-current counterexample \
    models/providers/ParslKubernetesPolling.cfg \
    models/providers/ParslKubernetesPolling.tla
run_case kubernetes-polling-fixed pass \
    models/providers/ParslKubernetesPollingFixed.cfg \
    models/providers/ParslKubernetesPolling.tla
run_case kubernetes-submit-current counterexample \
    models/providers/ParslKubernetesSubmit.cfg \
    models/providers/ParslKubernetesSubmit.tla
run_case kubernetes-submit-fixed pass \
    models/providers/ParslKubernetesSubmitFixed.cfg \
    models/providers/ParslKubernetesSubmit.tla
run_case kubernetes-unknown-job-current counterexample \
    models/providers/ParslKubernetesUnknownJobCurrent.cfg \
    models/providers/ParslKubernetesUnknownJob.tla
run_case kubernetes-unknown-job-fixed pass \
    models/providers/ParslKubernetesUnknownJobFixed.cfg \
    models/providers/ParslKubernetesUnknownJob.tla
run_case duplicate-job-id-current counterexample \
    models/providers/ParslDuplicateJobIdCurrent.cfg \
    models/providers/ParslDuplicateJobId.tla
run_case duplicate-job-id-fixed pass \
    models/providers/ParslDuplicateJobIdFixed.cfg \
    models/providers/ParslDuplicateJobId.tla
run_case poller-duplicate-executor-current counterexample \
    models/providers/ParslPollerDuplicateExecutorCurrent.cfg \
    models/providers/ParslPollerDuplicateExecutor.tla
run_case poller-duplicate-executor-fixed pass \
    models/providers/ParslPollerDuplicateExecutorFixed.cfg \
    models/providers/ParslPollerDuplicateExecutor.tla
run_case provider-poll-clock-current counterexample \
    models/providers/ParslProviderPollClockRollbackCurrent.cfg \
    models/providers/ParslProviderPollClockRollback.tla
run_case provider-poll-clock-fixed pass \
    models/providers/ParslProviderPollClockRollbackFixed.cfg \
    models/providers/ParslProviderPollClockRollback.tla
run_case walltime-parsing-current counterexample \
    models/providers/ParslWalltimeParsingCurrent.cfg \
    models/providers/ParslWalltimeParsing.tla
run_case walltime-parsing-fixed pass \
    models/providers/ParslWalltimeParsingFixed.cfg \
    models/providers/ParslWalltimeParsing.tla
run_case walltime-parsing-valid pass \
    models/providers/ParslWalltimeParsingValid.cfg \
    models/providers/ParslWalltimeParsing.tla
run_case thread-executor pass \
    models/executors/ParslThreadExecutor.cfg \
    models/executors/ParslThreadExecutor.tla
run_case thread-executor-invalid-resource pass \
    models/executors/ParslThreadExecutorInvalidResource.cfg \
    models/executors/ParslThreadExecutor.tla
run_case thread-executor-nonblocking pass \
    models/executors/ParslThreadExecutorNonBlocking.cfg \
    models/executors/ParslThreadExecutor.tla
run_case thread-executor-future-lifecycle pass \
    models/executors/ParslThreadExecutorFutureLifecycle.cfg \
    models/executors/ParslThreadExecutorFutureLifecycle.tla
run_case thread-executor-resource-current counterexample \
    models/executors/ParslThreadExecutorResourceSpecCurrent.cfg \
    models/executors/ParslThreadExecutorResourceSpec.tla
run_case thread-executor-resource-fixed pass \
    models/executors/ParslThreadExecutorResourceSpecFixed.cfg \
    models/executors/ParslThreadExecutorResourceSpec.tla
run_case thread-executor-count-current counterexample \
    models/executors/ParslThreadExecutorThreadCountCurrent.cfg \
    models/executors/ParslThreadExecutorThreadCount.tla
run_case thread-executor-count-fixed pass \
    models/executors/ParslThreadExecutorThreadCountFixed.cfg \
    models/executors/ParslThreadExecutorThreadCount.tla
run_case thread-executor-count-valid pass \
    models/executors/ParslThreadExecutorThreadCountValid.cfg \
    models/executors/ParslThreadExecutorThreadCount.tla
run_case execute-task-malformed pass \
    models/executors/ParslExecuteTaskMalformed.cfg \
    models/executors/ParslExecuteTask.tla
run_case execute-task-value pass \
    models/executors/ParslExecuteTaskValue.cfg \
    models/executors/ParslExecuteTask.tla
run_case execute-task-exception pass \
    models/executors/ParslExecuteTaskException.cfg \
    models/executors/ParslExecuteTask.tla
run_case execute-wait-timeout-current counterexample \
    models/executors/ParslExecuteWaitTimeoutCurrent.cfg \
    models/executors/ParslExecuteWaitTimeout.tla
run_case execute-wait-timeout-fixed pass \
    models/executors/ParslExecuteWaitTimeoutFixed.cfg \
    models/executors/ParslExecuteWaitTimeout.tla
run_case execute-wait-timeout-success pass \
    models/executors/ParslExecuteWaitTimeoutSuccess.cfg \
    models/executors/ParslExecuteWaitTimeout.tla
run_case bash-timeout-cleanup-current counterexample \
    models/executors/ParslBashTimeoutCleanupCurrent.cfg \
    models/executors/ParslBashTimeoutCleanup.tla
run_case bash-timeout-cleanup-fixed pass \
    models/executors/ParslBashTimeoutCleanupFixed.cfg \
    models/executors/ParslBashTimeoutCleanup.tla
run_case pool-executor-map pass \
    models/executors/ParslPoolExecutorMap.cfg \
    models/executors/ParslPoolExecutorMap.tla
run_case htex-submit-counter-current counterexample \
    models/executors/ParslHtexSubmitCounterRaceCurrent.cfg \
    models/executors/ParslHtexSubmitCounterRace.tla
run_case htex-submit-counter-fixed pass \
    models/executors/ParslHtexSubmitCounterRaceFixed.cfg \
    models/executors/ParslHtexSubmitCounterRace.tla
run_case htex-submit-failure-current counterexample \
    models/executors/ParslHtexSubmitFailure.cfg \
    models/executors/ParslHtexSubmitFailure.tla
run_case htex-submit-failure-fixed pass \
    models/executors/ParslHtexSubmitFailureFixed.cfg \
    models/executors/ParslHtexSubmitFailure.tla
run_case htex-submit-lifecycle-current counterexample \
    models/executors/ParslHtexSubmitLifecycleQueueFailure.cfg \
    models/executors/ParslHtexSubmitLifecycle.tla
run_case htex-submit-lifecycle-fixed pass \
    models/executors/ParslHtexSubmitLifecycleQueueFailureFixed.cfg \
    models/executors/ParslHtexSubmitLifecycle.tla
run_case htex-submit-lifecycle-serialization-failure pass \
    models/executors/ParslHtexSubmitLifecycleSerializationFailure.cfg \
    models/executors/ParslHtexSubmitLifecycle.tla
run_case bad-state-task-mutation-current counterexample \
    models/executors/ParslBadStateTaskMutationCurrent.cfg \
    models/executors/ParslBadStateTaskMutation.tla
run_case bad-state-task-mutation-fixed pass \
    models/executors/ParslBadStateTaskMutationFixed.cfg \
    models/executors/ParslBadStateTaskMutation.tla
run_case block-provider-bad-state pass \
    models/executors/ParslBlockProviderBadState.cfg \
    models/executors/ParslBlockProviderBadState.tla
run_case block-provider-bad-state-mutation-current counterexample \
    models/executors/ParslBlockProviderBadStateMutationCurrent.cfg \
    models/executors/ParslBlockProviderBadStateMutation.tla
run_case block-provider-bad-state-mutation-fixed pass \
    models/executors/ParslBlockProviderBadStateMutationFixed.cfg \
    models/executors/ParslBlockProviderBadStateMutation.tla
run_case block-provider-bad-state-order-current counterexample \
    models/executors/ParslBlockProviderBadStateOrderingCurrent.cfg \
    models/executors/ParslBlockProviderBadStateOrdering.tla
run_case block-provider-bad-state-order-fixed pass \
    models/executors/ParslBlockProviderBadStateOrderingFixed.cfg \
    models/executors/ParslBlockProviderBadStateOrdering.tla
run_case command-client-reply pass \
    models/executors/ParslCommandClientReply.cfg \
    models/executors/ParslCommandClient.tla
run_case command-client-timeout pass \
    models/executors/ParslCommandClientTimeout.cfg \
    models/executors/ParslCommandClient.tla
run_case command-client-close-current counterexample \
    models/executors/ParslCommandClientCloseRaceCurrent.cfg \
    models/executors/ParslCommandClientCloseRace.tla
run_case command-client-close-fixed pass \
    models/executors/ParslCommandClientCloseRaceFixed.cfg \
    models/executors/ParslCommandClientCloseRace.tla
run_case command-client-lock-current counterexample \
    models/executors/ParslCommandClientLockTimeoutCurrent.cfg \
    models/executors/ParslCommandClientLockTimeout.tla
run_case command-client-lock-fixed pass \
    models/executors/ParslCommandClientLockTimeoutFixed.cfg \
    models/executors/ParslCommandClientLockTimeout.tla
run_case command-client-retries-current counterexample \
    models/executors/ParslCommandClientMaxRetriesCurrent.cfg \
    models/executors/ParslCommandClientMaxRetries.tla
run_case command-client-retries-fixed pass \
    models/executors/ParslCommandClientMaxRetriesFixed.cfg \
    models/executors/ParslCommandClientMaxRetries.tla
run_case command-client-send-timeout pass \
    models/executors/ParslCommandClientSendTimeout.cfg \
    models/executors/ParslCommandClientSendTimeout.tla
run_case command-deadline-current counterexample \
    models/executors/ParslCommandDeadlineCurrent.cfg \
    models/executors/ParslCommandDeadline.tla
run_case command-deadline-fixed pass \
    models/executors/ParslCommandDeadlineFixed.cfg \
    models/executors/ParslCommandDeadline.tla
run_case command-deadline-normal pass \
    models/executors/ParslCommandDeadlineNormal.cfg \
    models/executors/ParslCommandDeadline.tla
run_case heartbeat-boundary pass \
    models/executors/ParslHeartbeatBoundary.cfg \
    models/executors/ParslHeartbeatBoundary.tla
run_case heartbeat-clock-current counterexample \
    models/executors/ParslHeartbeatClockJumpCurrent.cfg \
    models/executors/ParslHeartbeatClockJump.tla
run_case heartbeat-clock-fixed pass \
    models/executors/ParslHeartbeatClockJumpFixed.cfg \
    models/executors/ParslHeartbeatClockJump.tla
run_case heartbeat-clock-normal pass \
    models/executors/ParslHeartbeatClockJumpNormal.cfg \
    models/executors/ParslHeartbeatClockJump.tla
run_case heartbeat-late-ack-current counterexample \
    models/executors/ParslHeartbeatLateAck.cfg \
    models/executors/ParslHeartbeatLateAck.tla
run_case heartbeat-late-ack-fixed pass \
    models/executors/ParslHeartbeatLateAckFixed.cfg \
    models/executors/ParslHeartbeatLateAck.tla
run_case heartbeat-provider pass \
    models/executors/ParslHeartbeatProvider.cfg \
    models/executors/ParslHeartbeatProvider.tla
run_case file-transfer-monitoring-current counterexample \
    models/monitoring/ParslFileTransferMonitoringCurrent.cfg \
    models/monitoring/ParslFileTransferMonitoring.tla
run_case file-transfer-monitoring-fixed pass \
    models/monitoring/ParslFileTransferMonitoringFixed.cfg \
    models/monitoring/ParslFileTransferMonitoring.tla
run_case filesystem-radio-current counterexample \
    models/monitoring/ParslFilesystemRadioAtomicityCurrent.cfg \
    models/monitoring/ParslFilesystemRadioAtomicity.tla
run_case filesystem-radio-fixed pass \
    models/monitoring/ParslFilesystemRadioAtomicityFixed.cfg \
    models/monitoring/ParslFilesystemRadioAtomicity.tla
run_case monitoring-batch-current counterexample \
    models/monitoring/ParslMonitoringBatchCurrent.cfg \
    models/monitoring/ParslMonitoringBatch.tla
run_case monitoring-batch-fixed pass \
    models/monitoring/ParslMonitoringBatchFixed.cfg \
    models/monitoring/ParslMonitoringBatch.tla
run_case monitoring-batch-positive pass \
    models/monitoring/ParslMonitoringBatchPositive.cfg \
    models/monitoring/ParslMonitoringBatch.tla
run_case monitoring-batch-clock-current counterexample \
    models/monitoring/ParslMonitoringBatchClockCurrent.cfg \
    models/monitoring/ParslMonitoringBatchClock.tla
run_case monitoring-batch-clock-fixed pass \
    models/monitoring/ParslMonitoringBatchClockFixed.cfg \
    models/monitoring/ParslMonitoringBatchClock.tla
run_case monitoring-close-abnormal pass \
    models/monitoring/ParslMonitoringCloseAbnormal.cfg \
    models/monitoring/ParslMonitoringClose.tla
run_case monitoring-close-normal pass \
    models/monitoring/ParslMonitoringCloseNormal.cfg \
    models/monitoring/ParslMonitoringClose.tla
run_case monitoring-close-idempotence-current counterexample \
    models/monitoring/ParslMonitoringCloseIdempotenceCurrent.cfg \
    models/monitoring/ParslMonitoringCloseIdempotence.tla
run_case monitoring-close-idempotence-fixed pass \
    models/monitoring/ParslMonitoringCloseIdempotenceFixed.cfg \
    models/monitoring/ParslMonitoringCloseIdempotence.tla
run_case monitoring-db-permanent-current counterexample \
    models/monitoring/ParslMonitoringDBPermanentErrorCurrent.cfg \
    models/monitoring/ParslMonitoringDBPermanentError.tla
run_case monitoring-db-permanent-fixed pass \
    models/monitoring/ParslMonitoringDBPermanentErrorFixed.cfg \
    models/monitoring/ParslMonitoringDBPermanentError.tla
run_case monitoring-db-retry pass \
    models/monitoring/ParslMonitoringDBRetry.cfg \
    models/monitoring/ParslMonitoringDBRetry.tla
run_case monitoring-db-retry-integrity pass \
    models/monitoring/ParslMonitoringDBRetryIntegrity.cfg \
    models/monitoring/ParslMonitoringDBRetry.tla
run_case monitoring-delivery-current counterexample \
    models/monitoring/ParslMonitoringDelivery.cfg \
    models/monitoring/ParslMonitoringDelivery.tla
run_case monitoring-delivery-fixed pass \
    models/monitoring/ParslMonitoringDeliveryFixed.cfg \
    models/monitoring/ParslMonitoringDelivery.tla
run_case monitoring-threshold-current counterexample \
    models/monitoring/ParslMonitoringThreshold.cfg \
    models/monitoring/ParslMonitoringThreshold.tla
run_case monitoring-threshold-fixed pass \
    models/monitoring/ParslMonitoringThresholdFixed.cfg \
    models/monitoring/ParslMonitoringThreshold.tla
run_case ftp-connection-current counterexample \
    models/staging/ParslFTPConnectionCleanupCurrent.cfg \
    models/staging/ParslFTPConnectionCleanup.tla
run_case ftp-connection-fixed pass \
    models/staging/ParslFTPConnectionCleanupFixed.cfg \
    models/staging/ParslFTPConnectionCleanup.tla
run_case ftp-connection-success pass \
    models/staging/ParslFTPConnectionCleanupSuccess.cfg \
    models/staging/ParslFTPConnectionCleanup.tla
run_case ftp-partial-current counterexample \
    models/staging/ParslFTPPartialCleanupCurrent.cfg \
    models/staging/ParslFTPPartialCleanup.tla
run_case ftp-partial-fixed pass \
    models/staging/ParslFTPPartialCleanupFixed.cfg \
    models/staging/ParslFTPPartialCleanup.tla
run_case ftp-stage-current counterexample \
    models/staging/ParslFTPStageCurrent.cfg \
    models/staging/ParslFTPStage.tla
run_case ftp-stage-fixed pass \
    models/staging/ParslFTPStageFixed.cfg \
    models/staging/ParslFTPStage.tla
run_case ftp-stage-success pass \
    models/staging/ParslFTPStageSuccess.cfg \
    models/staging/ParslFTPStage.tla
run_case http-connection-current counterexample \
    models/staging/ParslHTTPConnectionCleanupCurrent.cfg \
    models/staging/ParslHTTPConnectionCleanup.tla
run_case http-connection-fixed pass \
    models/staging/ParslHTTPConnectionCleanupFixed.cfg \
    models/staging/ParslHTTPConnectionCleanup.tla
run_case http-existing-current counterexample \
    models/staging/ParslHTTPExistingDestinationCurrent.cfg \
    models/staging/ParslHTTPExistingDestination.tla
run_case http-existing-fixed pass \
    models/staging/ParslHTTPExistingDestinationFixed.cfg \
    models/staging/ParslHTTPExistingDestination.tla
run_case http-partial-current counterexample \
    models/staging/ParslHTTPPartialCleanupCurrent.cfg \
    models/staging/ParslHTTPPartialCleanup.tla
run_case http-partial-fixed pass \
    models/staging/ParslHTTPPartialCleanupFixed.cfg \
    models/staging/ParslHTTPPartialCleanup.tla
run_case http-partial-success pass \
    models/staging/ParslHTTPPartialCleanupSuccess.cfg \
    models/staging/ParslHTTPPartialCleanup.tla
run_case http-stage-current counterexample \
    models/staging/ParslHTTPStageCurrent.cfg \
    models/staging/ParslHTTPStage.tla
run_case http-stage-fixed pass \
    models/staging/ParslHTTPStageFixed.cfg \
    models/staging/ParslHTTPStage.tla
run_case http-stage-success pass \
    models/staging/ParslHTTPStageSuccess.cfg \
    models/staging/ParslHTTPStage.tla
run_case rsync-quoting-current counterexample \
    models/staging/ParslRsyncQuotingCurrent.cfg \
    models/staging/ParslRsyncQuoting.tla
run_case rsync-quoting-fixed pass \
    models/staging/ParslRsyncQuotingFixed.cfg \
    models/staging/ParslRsyncQuoting.tla
run_case rsync-quoting-normal pass \
    models/staging/ParslRsyncQuotingNormal.cfg \
    models/staging/ParslRsyncQuoting.tla
run_case rsync-stage-in-failure pass \
    models/staging/ParslRsyncStageInFail.cfg \
    models/staging/ParslRsyncStage.tla
run_case rsync-stage-out-failure pass \
    models/staging/ParslRsyncStageOutFail.cfg \
    models/staging/ParslRsyncStage.tla
run_case rsync-stage-success pass \
    models/staging/ParslRsyncStageSuccess.cfg \
    models/staging/ParslRsyncStage.tla
run_case file-clean-copy-current counterexample \
    models/staging/ParslFileCleanCopyCurrent.cfg \
    models/staging/ParslFileCleanCopy.tla
run_case file-clean-copy-fixed pass \
    models/staging/ParslFileCleanCopyFixed.cfg \
    models/staging/ParslFileCleanCopy.tla
run_case file-path-resolution pass \
    models/staging/ParslFilePathResolution.cfg \
    models/staging/ParslFilePathResolution.tla
run_case zip-path-current counterexample \
    models/staging/ParslZipPathValidationCurrent.cfg \
    models/staging/ParslZipPathValidation.tla
run_case zip-path-fixed pass \
    models/staging/ParslZipPathValidationFixed.cfg \
    models/staging/ParslZipPathValidation.tla
run_case globus-endpoint-current counterexample \
    models/staging/ParslGlobusEndpointPathCurrent.cfg \
    models/staging/ParslGlobusEndpointPath.tla
run_case globus-endpoint-fixed pass \
    models/staging/ParslGlobusEndpointPathFixed.cfg \
    models/staging/ParslGlobusEndpointPath.tla
run_case globus-endpoint-valid pass \
    models/staging/ParslGlobusEndpointPathValid.cfg \
    models/staging/ParslGlobusEndpointPath.tla
run_case globus-stage-dependency pass \
    models/staging/ParslGlobusStageDependency.cfg \
    models/staging/ParslGlobusStageDependency.tla
run_case globus-token-current counterexample \
    models/staging/ParslGlobusTokenFileAtomicityCurrent.cfg \
    models/staging/ParslGlobusTokenFileAtomicity.tla
run_case globus-token-fixed pass \
    models/staging/ParslGlobusTokenFileAtomicityFixed.cfg \
    models/staging/ParslGlobusTokenFileAtomicity.tla
run_case globus-token-valid pass \
    models/staging/ParslGlobusTokenFileAtomicityValid.cfg \
    models/staging/ParslGlobusTokenFileAtomicity.tla
run_case globus-compute-config-current counterexample \
    models/staging/ParslGlobusComputeConfig.cfg \
    models/staging/ParslGlobusComputeConfig.tla
run_case globus-compute-config-fixed pass \
    models/staging/ParslGlobusComputeConfigFixed.cfg \
    models/staging/ParslGlobusComputeConfig.tla
run_case datafuture-cancel-current counterexample \
    models/staging/ParslDataFutureCancellationPropagationCurrent.cfg \
    models/staging/ParslDataFutureCancellationPropagation.tla
run_case datafuture-cancel-fixed pass \
    models/staging/ParslDataFutureCancellationPropagationFixed.cfg \
    models/staging/ParslDataFutureCancellationPropagation.tla
run_case multi-output-stageout pass \
    models/staging/ParslMultiOutputStageOutCurrent.cfg \
    models/staging/ParslMultiOutputStageOut.tla
run_case multi-output-stageout-early counterexample \
    models/staging/ParslMultiOutputStageOutEarly.cfg \
    models/staging/ParslMultiOutputStageOut.tla
run_case staging-provider-dispatch pass \
    models/staging/ParslStagingProviderDispatchCurrent.cfg \
    models/staging/ParslStagingProviderDispatch.tla
run_case zip-stageout pass \
    models/staging/ParslZipStageOut.cfg \
    models/staging/ParslZipStageOut.tla
run_case zip-stageout-retry-current counterexample \
    models/staging/ParslZipStageOutRetry.cfg \
    models/staging/ParslZipStageOut.tla
run_case zip-stageout-retry-fixed pass \
    models/staging/ParslZipStageOutRetryFixed.cfg \
    models/staging/ParslZipStageOut.tla
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
run_case serialization-zmq-bridge pass \
    models/serialization/ParslSerializationZMQBridge.cfg \
    models/serialization/ParslSerializationZMQBridge.tla
run_case curvezmq-certificate-invalid pass \
    models/serialization/ParslCurveZMQCertificateModeInvalid.cfg \
    models/serialization/ParslCurveZMQCertificateMode.tla
run_case curvezmq-certificate-valid pass \
    models/serialization/ParslCurveZMQCertificateModeValid.cfg \
    models/serialization/ParslCurveZMQCertificateMode.tla
run_case worker-pool-control-frame-current counterexample \
    models/serialization/ParslWorkerPoolControlFrameCurrent.cfg \
    models/serialization/ParslWorkerPoolControlFrame.tla
run_case worker-pool-control-frame-fixed pass \
    models/serialization/ParslWorkerPoolControlFrameFixed.cfg \
    models/serialization/ParslWorkerPoolControlFrame.tla
run_case htex-result-decode-current counterexample \
    models/executors/ParslHtexResultDecodeFailureCurrent.cfg \
    models/executors/ParslHtexResultDecodeFailure.tla
run_case htex-result-decode-fixed pass \
    models/executors/ParslHtexResultDecodeFailureFixed.cfg \
    models/executors/ParslHtexResultDecodeFailure.tla
run_case htex-result-decode-normal pass \
    models/executors/ParslHtexResultDecodeFailureNormal.cfg \
    models/executors/ParslHtexResultDecodeFailure.tla
run_case htex-ambiguous-result-current counterexample \
    models/executors/ParslHtexAmbiguousResultCurrent.cfg \
    models/executors/ParslHtexAmbiguousResult.tla
run_case htex-ambiguous-result-fixed pass \
    models/executors/ParslHtexAmbiguousResultFixed.cfg \
    models/executors/ParslHtexAmbiguousResult.tla
run_case htex-cancelled-result-current counterexample \
    models/executors/ParslHtexCancelledResultCurrent.cfg \
    models/executors/ParslHtexCancelledResult.tla
run_case htex-cancelled-result-fixed pass \
    models/executors/ParslHtexCancelledResultFixed.cfg \
    models/executors/ParslHtexCancelledResult.tla
run_case htex-duplicate-result-current counterexample \
    models/executors/ParslHtexDuplicateResultCurrent.cfg \
    models/executors/ParslHtexDuplicateResult.tla
run_case htex-duplicate-result-fixed pass \
    models/executors/ParslHtexDuplicateResultFixed.cfg \
    models/executors/ParslHtexDuplicateResult.tla
run_case workqueue-cancelled-result-current counterexample \
    models/executors/ParslWorkQueueCancelledResultCurrent.cfg \
    models/executors/ParslWorkQueueCancelledResult.tla
run_case workqueue-cancelled-result-fixed pass \
    models/executors/ParslWorkQueueCancelledResultFixed.cfg \
    models/executors/ParslWorkQueueCancelledResult.tla
run_case workqueue-duplicate-report-current counterexample \
    models/executors/ParslWorkQueueDuplicateReport.cfg \
    models/executors/ParslWorkQueueDuplicateReport.tla
run_case workqueue-duplicate-report-fixed pass \
    models/executors/ParslWorkQueueDuplicateReportFixed.cfg \
    models/executors/ParslWorkQueueDuplicateReport.tla
run_case workqueue-resource-category-current counterexample \
    models/executors/ParslWorkQueueResourceCategoryCurrent.cfg \
    models/executors/ParslWorkQueueResourceCategory.tla
run_case workqueue-resource-category-fixed pass \
    models/executors/ParslWorkQueueResourceCategoryFixed.cfg \
    models/executors/ParslWorkQueueResourceCategory.tla
run_case workqueue-results pass \
    models/executors/ParslWorkQueueResults.cfg \
    models/executors/ParslWorkQueueResults.tla
run_case workqueue-shutdown pass \
    models/executors/ParslWorkQueueShutdown.cfg \
    models/executors/ParslWorkQueueShutdown.tla
run_case workqueue-submit-failure-current counterexample \
    models/executors/ParslWorkQueueSubmitFailure.cfg \
    models/executors/ParslWorkQueueSubmit.tla
run_case workqueue-submit-failure-fixed pass \
    models/executors/ParslWorkQueueSubmitFixed.cfg \
    models/executors/ParslWorkQueueSubmit.tla
run_case workqueue-submit-serialization-current counterexample \
    models/executors/ParslWorkQueueSubmitSerializationFailure.cfg \
    models/executors/ParslWorkQueueSubmit.tla
run_case workqueue-submit-serialization-fixed pass \
    models/executors/ParslWorkQueueSubmitSerializationFailureFixed.cfg \
    models/executors/ParslWorkQueueSubmit.tla
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
run_case serialization-apply-message-arity-current counterexample \
    models/serialization/ParslApplyMessageArity.cfg \
    models/serialization/ParslApplyMessageArity.tla
run_case serialization-apply-message-arity-fixed pass \
    models/serialization/ParslApplyMessageArityFixed.cfg \
    models/serialization/ParslApplyMessageArity.tla
run_case serialization-callable-argument-alias-current counterexample \
    models/serialization/ParslCallableArgumentAliasCurrent.cfg \
    models/serialization/ParslCallableArgumentAlias.tla
run_case serialization-callable-argument-alias-fixed pass \
    models/serialization/ParslCallableArgumentAliasFixed.cfg \
    models/serialization/ParslCallableArgumentAlias.tla
run_case serialization-callable-deserialize-cache-current counterexample \
    models/serialization/ParslCallableDeserializeCacheCurrent.cfg \
    models/serialization/ParslCallableDeserializeCache.tla
run_case serialization-callable-deserialize-cache-fixed pass \
    models/serialization/ParslCallableDeserializeCacheFixed.cfg \
    models/serialization/ParslCallableDeserializeCache.tla
run_case serialization-callable-serializer-cache-current counterexample \
    models/serialization/ParslCallableSerializerCache.cfg \
    models/serialization/ParslCallableSerializerCache.tla
run_case serialization-callable-serializer-cache-fixed pass \
    models/serialization/ParslCallableSerializerCacheFixed.cfg \
    models/serialization/ParslCallableSerializerCache.tla
run_case serialization-pool-executor-callable-cache-current counterexample \
    models/serialization/ParslPoolExecutorCallableCacheCurrent.cfg \
    models/serialization/ParslPoolExecutorCallableCache.tla
run_case serialization-pool-executor-callable-cache-fixed pass \
    models/serialization/ParslPoolExecutorCallableCacheFixed.cfg \
    models/serialization/ParslPoolExecutorCallableCache.tla
run_case serialization-empty-registry-current counterexample \
    models/serialization/ParslSerializationEmptyRegistryCurrent.cfg \
    models/serialization/ParslSerializationEmptyRegistry.tla
run_case serialization-empty-registry-fixed pass \
    models/serialization/ParslSerializationEmptyRegistryFixed.cfg \
    models/serialization/ParslSerializationEmptyRegistry.tla
run_case serialization-registry-collision-current counterexample \
    models/serialization/ParslSerializerRegistry.cfg \
    models/serialization/ParslSerializerRegistry.tla
run_case serialization-registry-collision-fixed pass \
    models/serialization/ParslSerializerRegistryFixed.cfg \
    models/serialization/ParslSerializerRegistry.tla
run_case serialization-registry-normal pass \
    models/serialization/ParslSerializerRegistryNormal.cfg \
    models/serialization/ParslSerializerRegistry.tla
run_case serialization-task-transport pass \
    models/serialization/ParslTaskTransport.cfg \
    models/serialization/ParslTaskTransport.tla
run_case serialization-task-transport-failure pass \
    models/serialization/ParslTaskTransportFailure.cfg \
    models/serialization/ParslTaskTransport.tla
run_case serialization-zmq pass \
    models/serialization/ParslZMQ.cfg \
    models/serialization/ParslZMQ.tla
run_case heartbeat-parameter-validation-current counterexample \
    models/clock/ParslHeartbeatParameterValidationCurrent.cfg \
    models/clock/ParslHeartbeatParameterValidation.tla
run_case heartbeat-parameter-validation-fixed pass \
    models/clock/ParslHeartbeatParameterValidationFixed.cfg \
    models/clock/ParslHeartbeatParameterValidation.tla
run_case heartbeat-parameter-validation-valid pass \
    models/clock/ParslHeartbeatParameterValidationValid.cfg \
    models/clock/ParslHeartbeatParameterValidation.tla
run_case python-timeout-parameter-current counterexample \
    models/clock/ParslPythonTimeoutParameterCurrent.cfg \
    models/clock/ParslPythonTimeoutParameter.tla
run_case python-timeout-parameter-fixed pass \
    models/clock/ParslPythonTimeoutParameterFixed.cfg \
    models/clock/ParslPythonTimeoutParameter.tla
run_case python-timeout-parameter-valid pass \
    models/clock/ParslPythonTimeoutParameterValid.cfg \
    models/clock/ParslPythonTimeoutParameter.tla
run_case resource-monitor-clock-current counterexample \
    models/clock/ParslResourceMonitorClockCurrent.cfg \
    models/clock/ParslResourceMonitorClock.tla
run_case resource-monitor-clock-fixed pass \
    models/clock/ParslResourceMonitorClockFixed.cfg \
    models/clock/ParslResourceMonitorClock.tla
run_case timeout-timer-error pass \
    models/clock/ParslTimeoutTimerError.cfg \
    models/clock/ParslTimeoutTimer.tla
run_case timeout-timer-success pass \
    models/clock/ParslTimeoutTimerSuccess.cfg \
    models/clock/ParslTimeoutTimer.tla
run_case timer-interval-validation-current counterexample \
    models/clock/ParslTimerIntervalValidationCurrent.cfg \
    models/clock/ParslTimerIntervalValidation.tla
run_case timer-interval-validation-fixed pass \
    models/clock/ParslTimerIntervalValidationFixed.cfg \
    models/clock/ParslTimerIntervalValidation.tla
run_case timer-interval-validation-valid pass \
    models/clock/ParslTimerIntervalValidationValid.cfg \
    models/clock/ParslTimerIntervalValidation.tla
run_case datafuture-copy pass \
    models/dataflow/ParslDataFutureCopy.cfg \
    models/dataflow/ParslDataFutureCopy.tla
run_case datafuture-falsey-exception-current counterexample \
    models/dataflow/ParslDataFutureFalseyExceptionCurrent.cfg \
    models/dataflow/ParslDataFutureFalseyException.tla
run_case datafuture-falsey-exception-fixed pass \
    models/dataflow/ParslDataFutureFalseyExceptionFixed.cfg \
    models/dataflow/ParslDataFutureFalseyException.tla
run_case datafuture-falsey-exception-normal pass \
    models/dataflow/ParslDataFutureFalseyExceptionNormal.cfg \
    models/dataflow/ParslDataFutureFalseyException.tla
run_case future-cancellation-app pass \
    models/dataflow/ParslFutureCancellationApp.cfg \
    models/dataflow/ParslFutureCancellation.tla
run_case future-cancellation-data pass \
    models/dataflow/ParslFutureCancellationData.cfg \
    models/dataflow/ParslFutureCancellation.tla
run_case future-cancellation-underlying pass \
    models/dataflow/ParslFutureCancellationUnderlying.cfg \
    models/dataflow/ParslFutureCancellation.tla
run_case future-projection-invalid pass \
    models/dataflow/ParslFutureProjectionInvalid.cfg \
    models/dataflow/ParslFutureProjection.tla
run_case future-projection-valid pass \
    models/dataflow/ParslFutureProjectionValid.cfg \
    models/dataflow/ParslFutureProjection.tla
run_case future-wait-timeout pass \
    models/dataflow/ParslFutureWaitTimeout.cfg \
    models/dataflow/ParslFutureWaitTimeout.tla
run_case join-duplicates pass \
    models/dataflow/ParslJoinDuplicates.cfg \
    models/dataflow/ParslJoinDuplicates.tla
run_case join-mixed-list-current pass \
    models/dataflow/ParslJoinMixedList.cfg \
    models/dataflow/ParslJoinMixedList.tla
run_case join-mixed-list-valid pass \
    models/dataflow/ParslJoinMixedListValid.cfg \
    models/dataflow/ParslJoinMixedList.tla
run_case join-none-result-list pass \
    models/dataflow/ParslJoinNoneResultList.cfg \
    models/dataflow/ParslJoinNoneResult.tla
run_case join-none-result-single pass \
    models/dataflow/ParslJoinNoneResultSingle.cfg \
    models/dataflow/ParslJoinNoneResult.tla
run_case join-retry pass \
    models/dataflow/ParslJoinRetry.cfg \
    models/dataflow/ParslJoinRetry.tla
run_case join-retry-cancellation-current counterexample \
    models/dataflow/ParslJoinRetryCancellationCurrent.cfg \
    models/dataflow/ParslJoinRetryCancellation.tla
run_case join-retry-cancellation-fixed pass \
    models/dataflow/ParslJoinRetryCancellationFixed.cfg \
    models/dataflow/ParslJoinRetryCancellation.tla
run_case join-return-shape-empty pass \
    models/dataflow/ParslJoinReturnShapeEmpty.cfg \
    models/dataflow/ParslJoinReturnShape.tla
run_case join-return-shape-future pass \
    models/dataflow/ParslJoinReturnShapeFuture.cfg \
    models/dataflow/ParslJoinReturnShape.tla
run_case join-return-shape-list pass \
    models/dataflow/ParslJoinReturnShapeList.cfg \
    models/dataflow/ParslJoinReturnShape.tla
run_case join-return-shape-mixed pass \
    models/dataflow/ParslJoinReturnShapeMixed.cfg \
    models/dataflow/ParslJoinReturnShape.tla
run_case join-return-shape-tuple pass \
    models/dataflow/ParslJoinReturnShapeTuple.cfg \
    models/dataflow/ParslJoinReturnShape.tla
run_case join-single-cancellation-current counterexample \
    models/dataflow/ParslJoinSingleCancellationCurrent.cfg \
    models/dataflow/ParslJoinSingleCancellation.tla
run_case join-single-cancellation-fixed pass \
    models/dataflow/ParslJoinSingleCancellationFixed.cfg \
    models/dataflow/ParslJoinSingleCancellation.tla
run_case memo-dict-ordering-current counterexample \
    models/dataflow/ParslMemoDictOrderingCurrent.cfg \
    models/dataflow/ParslMemoDictOrdering.tla
run_case memo-dict-ordering-fixed pass \
    models/dataflow/ParslMemoDictOrderingFixed.cfg \
    models/dataflow/ParslMemoDictOrdering.tla
run_case memo-dict-ordering-homogeneous pass \
    models/dataflow/ParslMemoDictOrderingHomogeneous.cfg \
    models/dataflow/ParslMemoDictOrdering.tla
run_case memo-ignore-key-current counterexample \
    models/dataflow/ParslMemoIgnoreKeyCurrent.cfg \
    models/dataflow/ParslMemoIgnoreKey.tla
run_case memo-ignore-key-fixed pass \
    models/dataflow/ParslMemoIgnoreKeyFixed.cfg \
    models/dataflow/ParslMemoIgnoreKey.tla
run_case memo-ignore-outputs-current counterexample \
    models/dataflow/ParslMemoIgnoreOutputsCurrent.cfg \
    models/dataflow/ParslMemoIgnoreOutputs.tla
run_case memo-ignore-outputs-fixed pass \
    models/dataflow/ParslMemoIgnoreOutputsFixed.cfg \
    models/dataflow/ParslMemoIgnoreOutputs.tla
run_case memo-checkpoint-order-current counterexample \
    models/dataflow/ParslMemoCheckpointOrderCurrent.cfg \
    models/dataflow/ParslMemoCheckpointOrder.tla
run_case memo-checkpoint-order-fixed pass \
    models/dataflow/ParslMemoCheckpointOrderFixed.cfg \
    models/dataflow/ParslMemoCheckpointOrder.tla
run_case memo-exception-checkpoint-current counterexample \
    models/dataflow/ParslMemoExceptionCheckpointCurrent.cfg \
    models/dataflow/ParslMemoExceptionCheckpoint.tla
run_case memo-exception-checkpoint-fixed pass \
    models/dataflow/ParslMemoExceptionCheckpointFixed.cfg \
    models/dataflow/ParslMemoExceptionCheckpoint.tla
