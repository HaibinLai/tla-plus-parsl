# Serialization and ZMQ model map

The serialization abstraction is layered rather than treating a task as one opaque message.
The models distinguish serializer bytes, multipart framing, ZMQ queueing, route validation,
worker decode/dispatch, and result correlation.

`ParslRemoteExceptionTransport.tla` adds the exception-object boundary: a worker-side
`RemoteExceptionWrapper` with a nested `__cause__` is serialized, decoded by the result worker,
and reraised into a terminal Future failure.  The runtime bridge uses the installed HTEX result
worker and verifies that the leaf cause survives the real serializer.

## Source-to-model mapping

| Parsl source | Model |
| --- | --- |
| parsl/serialize/facade.py::pack_apply_message | ParslApplyMessageArity and ParslFunctionObjectContents |
| parsl/serialize/facade.py::serialize | ParslSerializationWire, serializer registry/cache, fallback, and plugin models |
| parsl/serialize/facade.py::unpack_and_deserialize | frame-count, declared-length, malformed-envelope, and truncated-payload models |
| parsl/executors/high_throughput/executor.py::submit_payload | ParslTaskTransport and ParslZMQSerializationEndToEnd task path |
| parsl/executors/high_throughput/executor.py result worker | result decode/retry, duplicate/unknown result, and stale-correlation models |
| parsl/executors/high_throughput/process_worker_pool.py | callable/object snapshot, worker result serialization, and failure payload models |
| parsl/executors/high_throughput/interchange.py::process_manager_socket_message | manager-message, registration-envelope, heartbeat, and result-frame models |
| parsl/executors/high_throughput/zmq_pipes.py::CommandClient.run | command deadline, retry, close, send-failure, and receive-failure models |

In ParslZMQSerializationEndToEnd, a task or result message has a serializer identifier,
sender/receiver route, multipart frame state, and attempt number. The abstract transitions are:

1. serialize the payload;
2. construct the multipart frame;
3. enqueue and deliver through a bounded ZMQ-like queue;
4. receive and validate the route;
5. decode and dispatch;
6. resolve only the current physical attempt, or classify the frame as stale.

The integrated model also flips a bounded result payload's integrity bit after framing. The
current branch still decodes and can resolve that corrupted frame, violating `PayloadIntegritySafety`;
the fixed branch rejects it before dispatch. TLC finds the current counterexample after 9,800
generated / 2,213 distinct states. The fixed full configuration passes all eight invariants with
1,397,137 generated / 302,560 distinct states at depth 59. The smoke fixed configuration passes
with 3,981 generated / 1,192 distinct states at depth 31.

`ParslZMQCallableRetry.tla` combines the callable/object snapshot with the physical task/result
wire and retry generation. A failed attempt can deliver a complete, valid payload after a retry
has captured a newer object version. The current branch resolves that old payload into the logical
Future, violating `CurrentResultSafety` after 139 generated / 84 distinct states; the fixed branch
classifies it as stale and passes all seven invariants with 222 generated / 84 distinct states at
depth 13.

`ParslMessageCorrelation` makes the correlation key explicit. Each result carries an
`origin` logical-task ID and a physical `attempt` number, while the abstract transport also
tracks the Future selected by its route. The model permits bounded queue reordering, a late
result from an earlier attempt, duplicate delivery, and a misrouted frame. The current
configuration demonstrates that checking only the attempt number can resolve a result into the
wrong task Future; the fixed configuration requires both `origin = target` and the current
attempt before resolution.

`ParslMessageCorrelationThree` extends this protocol to four concurrent logical tasks and
bounded four-frame queues. It combines out-of-order delivery, late retry generations, duplicate
frames, and cross-task retargeting; the fixed configuration checks 106,145 simulated states while
the Current configuration reproduces the correlation counterexample.

`ParslZMQAckRetry.tla` isolates the sender acknowledgement boundary. A missing ACK permits a
second transmission of the same logical envelope; the current branch dispatches both deliveries,
while the fixed branch treats the second delivery as a duplicate before worker invocation. The
model checks single-dispatch, ACK-after-completion, and Future consistency.
`tests/test_zmq_ack_retry_runtime.py` connects the same abstraction to a real in-process
ROUTER/DEALER pair: pyzmq delivers both retransmissions, while a receiver identity set executes
the serialized callable only once.

`ParslZMQSerializedAck.tla` composes the ACK race with the Python object snapshot boundary. The
envelope captures the callable/object version before the source mutates; a retransmission reuses
those bytes rather than re-encoding the changed source. The Current branch dispatches the
duplicate envelope twice, while the Fixed branch deduplicates by task/attempt identity. The
runtime bridge is `tests/test_zmq_serialized_ack_runtime.py` and uses Parsl's real serializer.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslZMQSerializationEndToEndSmoke.cfg models/serialization/ParslZMQSerializationEndToEnd.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslZMQAckRetryCurrent.cfg models/serialization/ParslZMQAckRetry.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslZMQAckRetryFixed.cfg models/serialization/ParslZMQAckRetry.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslZMQSerializedAckCurrent.cfg models/serialization/ParslZMQSerializedAck.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslZMQSerializedAckFixed.cfg models/serialization/ParslZMQSerializedAck.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_zmq_serialized_ack_runtime.py -v
```

`ParslZMQMultipartAck.tla` adds multipart validation to the same path. A valid three-buffer
envelope can be retransmitted after ACK loss and remains at-most-once at dispatch. A malformed
four-buffer envelope is rejected before the Fixed branch decodes it; the Current configuration
keeps the decode-before-reject behavior represented by `ParslSerializationFrameCount`. The
runtime bridge is `tests/test_zmq_multipart_ack_runtime.py`.

The runtime probe also reproduces BUG-314: the current `unpack_and_deserialize` path invokes the
deserializer for a fourth buffer before its final count assertion. The Fixed protocol validates
frame count and lengths before invoking any payload deserializer.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslZMQMultipartAckCurrent.cfg models/serialization/ParslZMQMultipartAck.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslZMQMultipartAckFixed.cfg models/serialization/ParslZMQMultipartAck.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslZMQMultipartAckMalformedCurrent.cfg models/serialization/ParslZMQMultipartAck.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslZMQMultipartAckMalformedFixed.cfg models/serialization/ParslZMQMultipartAck.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_zmq_multipart_ack_runtime.py -v
```

`ParslZMQResultAttempt.tla` connects the result envelope to physical-attempt generations. A
late result from attempt 0 cannot resolve the Future after attempt 1 becomes current; malformed
result payloads are rejected before resolution, and duplicate valid results are consumed only
once. The runtime bridge serializes real Flux `TaskResult` values and keeps attempt identity in
the outer message envelope.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslZMQResultAttemptCurrent.cfg models/serialization/ParslZMQResultAttempt.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslZMQResultAttemptFixed.cfg models/serialization/ParslZMQResultAttempt.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslZMQResultAttemptMalformedCurrent.cfg models/serialization/ParslZMQResultAttempt.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslZMQResultAttemptMalformedFixed.cfg models/serialization/ParslZMQResultAttempt.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_zmq_result_attempt_runtime.py -v
```

`ParslCallableAliasRetry.tla` combines Python object aliasing with retry snapshots. A mutable
object is both captured by a callable and passed as an argument; if it mutates while an encoded
attempt is pending, the fixed path invalidates that snapshot and re-encodes before retry. The
Current configuration reproduces stale-epoch behavior, while the Fixed configuration checks
100,001 simulated states.

`ParslSerializerHeaderConsistency` models the lower-level facade contract. `serialize()` emits
the serializer identifier, a newline delimiter, and the serializer body; the model keeps the
body's producing serializer separate from the header seen by `deserialize()`. The current branch
accepts a swapped callable/data header as a valid decoded object even though the envelope identity
is inconsistent, while the fixed branch rejects the mismatched envelope. TLC finds the current counterexample and checks
100,001 fixed states. The configuration uses a callable payload; replacing `OBJECT_KIND` with
`"data"` exercises the symmetric data serializer path.

The focused apply-message models keep the concrete three-buffer callable/args/kwargs contract
separate from the end-to-end route model. This avoids hiding a malformed frame-count or payload
length behind a generic "message delivered" state.

`ParslHtexRegistrationShape.tla` covers the registration-specific schema boundary. The outer
pickle/type guard can succeed while required fields such as `python_v` are absent; the current
branch then crashes while constructing the manager record. The fixed branch rejects the malformed
registration before it mutates `_ready_managers`. The runtime probe uses the real interchange
handler with a pickleable registration missing `python_v`.

`ParslHtexTaskIngressContinuation.tla` refines the malformed task-envelope boundary to a message
sequence. A malformed decoded task followed by a valid task leaves the current interchange loop
dead before the valid task can be queued; the fixed branch discards the first envelope and keeps
processing the channel. This is a temporal refinement of BUG-098 rather than a separate defect.

`ParslHtexSerializationFailure.tla` models the submit-side serialization error boundary. The
current `HighThroughputExecutor.submit` catches only `TypeError` from `pack_apply_message`; a
different serializer exception such as `ValueError` escapes as an implementation exception rather
than Parsl's `SerializationError`. The fixed branch normalizes every serialization failure before
it leaves submit. `tests/test_htex_serialization_failure_runtime.py` invokes the real executor
method with deterministic serializer failures. This finding is recorded as BUG-268.

`ParslHtexSerializationErrorName.tla` refines the same submit-side error path for callable
instances. When `pack_apply_message` raises `TypeError`, the current code uses `func.__name__`
while constructing `SerializationError`; a callable object with only `__call__` has no such
attribute, so an `AttributeError` masks the serialization failure. The fixed branch uses a safe
callable description. `tests/test_htex_serialization_error_name_runtime.py` probes both a named
function and a callable instance. This refinement is recorded as BUG-272.

`ParslHtexResultDecodeContinuation.tla` is a temporal refinement of BUG-020. It puts a corrupt
result frame before an independent valid frame in the same incoming batch. The current worker
exits on the first decode exception, leaving both the first Future orphaned and the later Future
pending; the fixed branch fails the first Future explicitly and continues to the valid frame.
`tests/test_htex_result_decode_continuation_runtime.py` reproduces the current batch behavior with
the real result-worker loop.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslHtexSerializationFailureCurrent.cfg models/serialization/ParslHtexSerializationFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslHtexSerializationFailureFixed.cfg models/serialization/ParslHtexSerializationFailure.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_serialization_failure_runtime.py -v
```

`ParslCommandSendFailure.tla` models a transport exception during `CommandClient.run`'s
`send_pyobj` call. The current branch leaves the REQ client marked healthy, while the fixed branch
poisons it before the next command can reuse the failed socket. The runtime probe uses the real
`CommandClient.run` implementation with a failing socket double.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCommandSendFailureCurrent.cfg models/serialization/ParslCommandSendFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCommandSendFailureFixed.cfg models/serialization/ParslCommandSendFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCommandSendFailureNormal.cfg models/serialization/ParslCommandSendFailure.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_command_send_failure_runtime.py -v
```

This transport-health boundary is recorded as BUG-214.

`ParslCommandReceiveFailure.tla` covers the complementary response path. The current
`CommandClient.run` lets a `recv_pyobj`/deserialization exception escape without changing
`ok`, leaving the REQ client apparently reusable even though its request/reply state is unknown.
The fixed branch poisons the client before propagating the error. The runtime probe uses the real
`CommandClient.run` implementation with a socket double whose `recv_pyobj` raises.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCommandReceiveFailureCurrent.cfg models/serialization/ParslCommandReceiveFailure.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCommandReceiveFailureFixed.cfg models/serialization/ParslCommandReceiveFailure.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_command_receive_failure_runtime.py -v
```

This receive-health boundary is recorded as BUG-238.

`ParslCommandClientConcurrentClose.tla` models the inter-thread close race. `run()` holds
`_lock` while polling and exchanging the command, but the current `close()` path closes the
socket without that lock. The current model therefore permits a raw socket error from an
in-flight command; the fixed branch serializes close with the operation boundary. The runtime
probe uses two threads and a deterministic socket double to close during `poll()`.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCommandClientConcurrentCloseCurrent.cfg models/serialization/ParslCommandClientConcurrentClose.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCommandClientConcurrentCloseFixed.cfg models/serialization/ParslCommandClientConcurrentClose.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_command_client_concurrent_close_runtime.py -v
```

This concurrent-close boundary is recorded as BUG-239.

`ParslHtexResultForwarding.tla` models manager-side task ownership while a serialized result is
forwarded over the outgoing ZMQ channel. The current implementation removes the task ID from
the manager record before `send_multipart`; a send exception therefore loses the manager's only
ownership record. The Fixed branch retains ownership until forwarding succeeds and allows a
bounded retry. The runtime probe uses a real `Interchange` method with a deterministic failing
outgoing socket and observes the current task-list loss. This boundary is recorded as BUG-225.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslHtexResultForwardingCurrent.cfg models/serialization/ParslHtexResultForwarding.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslHtexResultForwardingFixed.cfg models/serialization/ParslHtexResultForwarding.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_htex_result_forwarding_runtime.py -v
```

## Safety properties

- no dispatch occurs before receive and decode;
- serializer headers are present before decode;
- malformed, misrouted, duplicate, or dropped frames cannot resolve a Future;
- a result for an old attempt is stale and cannot overwrite a newer retry;
- a decode failure leaves the result worker available for later independent frames;
- callable and argument snapshots are isolated from post-submit source mutation.

The current/fixed configurations in the TLC sweep intentionally retain counterexamples for
stale-result acceptance, close/send races, malformed frames, and cache aliasing. Fixed variants
preserve the later valid message or classify the old frame without changing the logical Future.

The concrete header behavior is probed by
`tests/test_serializer_header_consistency_runtime.py`: the current built-in dill serializers
accept a data body after its header is changed from `02` to `C2`, which is why the model treats
the envelope identity as inconsistent even though the decoded Python value is unchanged.

The unified smoke runner now also checks callable serializer/deserializer caches, mutable-callable
aliasing, empty registries, malformed envelopes, dynamic plugin caching and plugin API errors,
task-transport close races, and ZMQ callable retry/object snapshots. These cases make serializer
cache state and wire-attempt identity explicit instead of treating serialization as a single opaque
success/failure bit.

Command-client coverage additionally checks concurrent close, pre-send timeout reuse, and lock
deadline behavior against the real control-channel helper. Historical timeout/reply configuration
files that reference missing invariants remain outside the runner until their defining module is
restored.
