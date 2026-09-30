#!/usr/bin/env bash

# Run the small, executable first-stage abstractions that span the main Parsl
# boundaries.  This is intentionally separate from tlc_recent_models.sh: it
# is a fast regression target for the foundational model set.

set -euo pipefail

JAVA_BIN=${JAVA_BIN:-java}
TLA_JAR=${TLA_JAR:-tla2tools.jar}
TLC_SIMULATE=${TLC_SIMULATE:-1000}

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

echo "Foundational TLC smoke suite passed."
