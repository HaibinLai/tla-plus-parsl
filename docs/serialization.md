# Serialization and transport models

These models cover Python callable/object serialization, framed buffers, serializer plugins,
ZMQ-style transport, task/result correlation, duplicate or stale messages, and apply-message
arity.

Files live in [`models/serialization/`](../models/serialization/). Runtime probes are in
`tests/test_*serialization*runtime.py` and `tests/test_zmq_serialization_runtime.py`.
