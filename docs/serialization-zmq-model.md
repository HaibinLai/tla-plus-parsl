# Serialization and ZMQ model map

The serialization abstraction is layered rather than treating a task as one opaque message.
The models distinguish serializer bytes, multipart framing, ZMQ queueing, route validation,
worker decode/dispatch, and result correlation.

## Source-to-model mapping

| Parsl source | Model |
| --- | --- |
| parsl/serialize/facade.py::pack_apply_message | ParslApplyMessageArity and ParslFunctionObjectContents |
| parsl/serialize/facade.py::serialize | ParslSerializationWire, serializer registry/cache, fallback, and plugin models |
| parsl/serialize/facade.py::unpack_and_deserialize | frame-count, declared-length, malformed-envelope, and truncated-payload models |
| parsl/executors/high_throughput/executor.py::submit_payload | ParslTaskTransport and ParslZMQSerializationEndToEnd task path |
| parsl/executors/high_throughput/executor.py result worker | result decode/retry, duplicate/unknown result, and stale-correlation models |
| parsl/executors/high_throughput/process_worker_pool.py | callable/object snapshot, worker result serialization, and failure payload models |

In ParslZMQSerializationEndToEnd, a task or result message has a serializer identifier,
sender/receiver route, multipart frame state, and attempt number. The abstract transitions are:

1. serialize the payload;
2. construct the multipart frame;
3. enqueue and deliver through a bounded ZMQ-like queue;
4. receive and validate the route;
5. decode and dispatch;
6. resolve only the current physical attempt, or classify the frame as stale.

`ParslMessageCorrelation` makes the correlation key explicit. Each result carries an
`origin` logical-task ID and a physical `attempt` number, while the abstract transport also
tracks the Future selected by its route. The model permits bounded queue reordering, a late
result from an earlier attempt, duplicate delivery, and a misrouted frame. The current
configuration demonstrates that checking only the attempt number can resolve a result into the
wrong task Future; the fixed configuration requires both `origin = target` and the current
attempt before resolution.

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
