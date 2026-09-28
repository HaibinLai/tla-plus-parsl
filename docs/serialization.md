# Serialization and transport models

`ParslCallableClosureMemo.tla` connects serialized callable contents to memoization. Two
closures with the same function name/module have distinct serialized payloads, but the current
name/module-only memo key collides and can return the first closure's result. The current
configuration violates `MemoResultSafety`; the fixed configuration includes closure identity.

These models cover Python callable/object serialization, framed buffers, serializer plugins,
ZMQ-style transport, task/result correlation, duplicate or stale messages, and apply-message
arity.

Files live in [`models/serialization/`](../models/serialization/). Runtime probes are in
`tests/test_*serialization*runtime.py` and `tests/test_zmq_serialization_runtime.py`.

`ParslSerializerRegistry.tla` models the concrete `facade.deserialize` registry order. With a
colliding identifier, the current configuration decodes a data payload through the code registry
and violates `DispatchSafety`; the fixed configuration rejects the ambiguous header, while the
normal `C2`/`02` configuration passes. `tests/test_serializer_registry_runtime.py` observes the
current code-first behavior directly.

`ParslZMQSerializationEndToEnd.tla` combines the default `C2`/`02` headers with multipart frame
progress, route checks, duplicate/drop handling, worker attempts, and result correlation. The
current configuration finds a `ResultCorrelationSafety` counterexample; the fixed configuration
classifies late or terminal results as stale and checks 562,641 states.
