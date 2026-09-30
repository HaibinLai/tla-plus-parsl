#!/usr/bin/env bash

# Run representative Python probes for the foundational TLA+ abstractions.
# Keep this list deliberately small and deterministic; backend-specific suites
# remain documented next to their focused models.

set -euo pipefail

PYTHON_BIN=${PYTHON_BIN:-/tmp/parsl-venv/bin/python}
PARSL_SOURCE=${PARSL_SOURCE:-/tmp/parsl-source}
TEST_CASE_START=${TEST_CASE_START:-1}
TEST_CASE_LIMIT=${TEST_CASE_LIMIT:-0}
CASE_COUNT=0

if [[ ! -x "$PYTHON_BIN" ]]; then
    echo "Unable to locate Python: $PYTHON_BIN" >&2
    exit 2
fi

tests=(
    tests/test_end_to_end_runtime.py
    tests/test_zmq_serialization_runtime.py
    tests/test_zmq_ack_retry_runtime.py
    tests/test_function_object_contents_runtime.py
    tests/test_function_object_transport_runtime.py
    tests/test_callable_argument_alias_runtime.py
    tests/test_python_nested_alias_runtime.py
    tests/test_file_bytes_transfer_runtime.py
    tests/test_data_manager_stage_in_ordering_runtime.py
    tests/test_data_manager_stage_out_ordering_runtime.py
    tests/test_http_content_length_runtime.py
    tests/test_rsync_quoting_runtime.py
    tests/test_htex_heartbeat_runtime.py
    tests/test_heartbeat_clock_jump_runtime.py
    tests/test_htex_contact_timeout_starvation_runtime.py
    tests/test_monitoring_db_runtime.py
    tests/test_monitoring_batch_atomicity_runtime.py
    tests/test_monitoring_persistent_retry_runtime.py
    tests/test_join_runtime.py
    tests/test_join_retry_runtime.py
    tests/test_nested_join_retry_runtime.py
    tests/test_join_cancellation_end_to_end_runtime.py
    tests/test_join_list_cancellation_end_to_end_runtime.py
    tests/test_join_single_cancellation_runtime.py
    tests/test_join_failure_aggregation_runtime.py
    tests/test_join_duplicate_failure_aggregation_runtime.py
    tests/test_join_cleanup_lifecycle_runtime.py
    tests/test_join_return_shape_runtime.py
    tests/test_outer_join_cancellation_runtime.py
    tests/test_provider_worker_scaling_runtime.py
    tests/test_executor_selection_runtime.py
    tests/test_thread_executor_future_lifecycle_runtime.py
    tests/test_workqueue_submit_runtime.py
    tests/test_taskvine_submit_runtime.py
    tests/test_aws_submit_runtime.py
    tests/test_azure_submit_runtime.py
    tests/test_googlecloud_submit_runtime.py
    tests/test_memo_function_identity_runtime.py
    tests/test_task_status_future_ordering_runtime.py
)

for test_file in "${tests[@]}"; do
    CASE_COUNT=$((CASE_COUNT + 1))
    if [[ "$CASE_COUNT" -lt "$TEST_CASE_START" ]]; then
        continue
    fi
    if [[ "$TEST_CASE_LIMIT" -gt 0 && "$CASE_COUNT" -gt "$TEST_CASE_LIMIT" ]]; then
        break
    fi
    echo "RUN [$CASE_COUNT/${#tests[@]}] $test_file"
    PYTHONPATH="$PARSL_SOURCE${PYTHONPATH:+:$PYTHONPATH}" \
        "$PYTHON_BIN" -m unittest "$test_file" -v
done

echo "Foundational Python runtime smoke suite passed."
