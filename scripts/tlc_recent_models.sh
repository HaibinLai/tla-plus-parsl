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
run_case heartbeat-timeout-current counterexample \
    models/clock/ParslHeartbeatTimeoutPersistenceCurrent.cfg \
    models/clock/ParslHeartbeatTimeoutPersistence.tla
run_case heartbeat-timeout-fixed pass \
    models/clock/ParslHeartbeatTimeoutPersistenceFixed.cfg \
    models/clock/ParslHeartbeatTimeoutPersistence.tla
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
