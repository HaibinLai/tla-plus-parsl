# Serialization and transport models

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
