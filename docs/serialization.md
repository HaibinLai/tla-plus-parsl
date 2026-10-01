# Serialization and transport models

`ParslCallableClosureMemo.tla` connects serialized callable contents to memoization. Two
closures with the same function name/module have distinct serialized payloads, but the current
name/module-only memo key collides and can return the first closure's result. The current
configuration violates `MemoResultSafety`; the fixed configuration includes closure identity.

These models cover Python callable/object serialization, framed buffers, serializer plugins,
ZMQ-style transport, task/result correlation, duplicate or stale messages, and apply-message
arity.

`ParslApplyDispatchBoundary.tla` connects the framing layer to worker invocation. The current
facade returns every length-prefixed buffer, while `execute_task` expects exactly function, args,
and kwargs; the fixed branch rejects malformed arity before worker dispatch. The runtime bridge
uses a real serialized callable plus an extra frame and observes the same boundary.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslApplyDispatchBoundaryCurrent.cfg models/serialization/ParslApplyDispatchBoundary.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslApplyDispatchBoundaryFixed.cfg models/serialization/ParslApplyDispatchBoundary.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_apply_dispatch_boundary_runtime.py -v
```

`ParslFunctionObjectTransport.tla` is the smallest executable snapshot model for a Python
callable and the object content it closes over.  Serialization captures a bounded source
version before the message is queued; source mutation is allowed while the frame is in flight,
but decode and execution must use the captured version.  This corresponds to
`pack_apply_message` producing immutable bytes before `TasksOutgoing`/ZMQ transport.  The
runtime probe uses a real closure, mutates its source dictionary after packing, and verifies that
the decoded callable still observes the packed value.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslFunctionObjectTransport.cfg models/serialization/ParslFunctionObjectTransport.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_function_object_transport_runtime.py -v
```

`ParslCallableRetryTransport.tla` composes that snapshot boundary with physical retry and
task/result correlation.  Attempt 0 and attempt 1 can capture different closure versions; a
late result from the failed attempt is classified as stale in the fixed configuration.  TLC
finds the current 42-state late-result counterexample and checks 190 generated/73 distinct fixed
states.  The runtime bridge packs two real callable payloads and verifies that they retain their
per-attempt closure contents.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCallableRetryTransportCurrent.cfg models/serialization/ParslCallableRetryTransport.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCallableRetryTransportFixed.cfg models/serialization/ParslCallableRetryTransport.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_callable_retry_transport_runtime.py -v
```

`ParslCallableArgumentAlias.tla` models identity shared by a closure and an argument.  The
current `pack_apply_message` path serializes those roots independently, so decoding produces
two equal but non-identical mutable objects; the fixed branch represents a bundled graph that
preserves the alias.  The runtime probe demonstrates the current behavior with a real closure.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCallableArgumentAliasCurrent.cfg models/serialization/ParslCallableArgumentAlias.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCallableArgumentAliasFixed.cfg models/serialization/ParslCallableArgumentAlias.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_callable_argument_alias_runtime.py -v
```

`ParslPythonNestedAlias.tla` extends the same identity boundary to a nested field: the callable,
direct argument, and nested reference all point to one source object. The current branch
reconstructs independent object IDs for the argument and nested field; the fixed branch preserves
one decoded graph identity. The runtime bridge in `tests/test_python_nested_alias_runtime.py`
confirms the current `pack_apply_message` behavior with a real closure and nested mutable dict.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslPythonNestedAliasCurrent.cfg models/serialization/ParslPythonNestedAlias.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslPythonNestedAliasFixed.cfg models/serialization/ParslPythonNestedAlias.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_python_nested_alias_runtime.py -v
```

`ParslCallableEqualCache.tla` models a related object-content boundary in
`DillCallableSerializer`: its `lru_cache` uses Python equality/hash semantics. Two distinct
callable instances that compare equal can therefore reuse the first serialized payload. The fixed
branch uses an identity/content-safe key. The runtime probe is
[`tests/test_callable_equal_cache_runtime.py`](../tests/test_callable_equal_cache_runtime.py).

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCallableEqualCacheCurrent.cfg models/serialization/ParslCallableEqualCache.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCallableEqualCacheFixed.cfg models/serialization/ParslCallableEqualCache.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_callable_equal_cache_runtime.py -v
```

`ParslPythonCyclic.cfg` extends the object-graph model with a self-referential argument object.
The visited-set walk terminates on the cycle while preserving the internal alias after decoding.
The runtime probe `tests/test_python_cyclic_object_runtime.py` checks this property through the
real Parsl serializer and `dill`.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslPythonCyclic.cfg models/serialization/ParslPython.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_python_cyclic_object_runtime.py -v
```

`ParslSerializationBinaryPayload.tla` checks that length-prefixed framing preserves raw payload
bytes even when they contain newline, NUL, and non-ASCII values. The runtime probe exercises the
real `pack_buffers` and `unpack_buffers` helpers with the same binary content.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationBinaryPayload.cfg models/serialization/ParslSerializationBinaryPayload.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_serialization_binary_payload_runtime.py -v
```

`ParslSerializationWire.tla` refines that framing for the actual `pack_apply_message` shape:
buffer 0 is the callable (`C2`), buffers 1 and 2 are positional arguments and keyword arguments
(`02`), and all three must be length-prefixed, unpacked, and decoded in order before dispatch.
The normal wire configuration is part of the foundational smoke gate; the companion failure
configuration exercises rejection when one of the three buffers cannot be serialized.
The runtime probe `test_apply_message_has_three_length_prefixed_serializer_buffers` inspects the
real packed bytes and then executes the decoded callable. This is the concrete bridge between the
symbolic frame indices in the model and Parsl's serializer facade.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationWire.cfg models/serialization/ParslSerializationWire.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_zmq_serialization_runtime.py -v
```

Files live in [`models/serialization/`](../models/serialization/). Runtime probes are in
`tests/test_*serialization*runtime.py` and `tests/test_zmq_serialization_runtime.py`.

`ParslCurveZMQCertificateMode.tla` models the certificate-loading guard in `parsl.curvezmq`.
Only a private (0700) certificate directory with a secret key may load a CurveZMQ key. The
runtime probe creates real pyzmq certificates, loads a valid key, and confirms that changing the
directory to 0755 is rejected.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCurveZMQCertificateModeValid.cfg models/serialization/ParslCurveZMQCertificateMode.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCurveZMQCertificateModeInvalid.cfg models/serialization/ParslCurveZMQCertificateMode.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_curvezmq_certificate_runtime.py -v
```

`ParslSerializationEnvelopeMalformed.tla` models the outer serializer envelope. The current
`deserialize` path assumes a header/body newline and lets a missing separator raise a raw
`ValueError`; the fixed branch rejects malformed framing as a decode failure before plugin lookup.
The runtime probe calls the real facade with a truncated payload.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationEnvelopeMalformedCurrent.cfg models/serialization/ParslSerializationEnvelopeMalformed.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationEnvelopeMalformedFixed.cfg models/serialization/ParslSerializationEnvelopeMalformed.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_serialization_envelope_malformed_runtime.py -v
```

`ParslSerializationNegativeLength.tla` covers a malformed decimal length header. A negative
length currently performs a Python negative slice and then crashes while parsing the leftover
byte; the fixed branch rejects the header before slicing. The runtime probe uses the real
`unpack_buffers` helper and records the current `ValueError` boundary.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationNegativeLengthCurrent.cfg models/serialization/ParslSerializationNegativeLength.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationNegativeLengthFixed.cfg models/serialization/ParslSerializationNegativeLength.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationNegativeLengthValid.cfg models/serialization/ParslSerializationNegativeLength.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_serialization_negative_length_runtime.py -v
```

`ParslSerializationShortFrameCount.tla` covers a truncated apply message with only two framed
buffers. The current `unpack_and_deserialize` path deserializes both buffers before its final
three-frame assertion; the fixed branch validates the count before decoding. The runtime probe
records the two current deserializer calls.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationShortFrameCountCurrent.cfg models/serialization/ParslSerializationShortFrameCount.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationShortFrameCountFixed.cfg models/serialization/ParslSerializationShortFrameCount.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_serialization_short_frame_count_runtime.py -v
```

`ParslApplyMessageArity.tla` models the complementary extra-frame case. The public
`unpack_apply_message` currently returns all decoded frames, although the worker contract is
exactly `(func, args, kwargs)`. The current four-frame configuration violates `AritySafety`; the
candidate fixed configuration rejects the message at the boundary. The runtime probe uses the
real framing and facade helpers.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslApplyMessageArity.cfg models/serialization/ParslApplyMessageArity.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslApplyMessageArityFixed.cfg models/serialization/ParslApplyMessageArity.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_apply_message_arity_runtime.py -v
```

`ParslSerializationTruncatedLength.tla` covers a different truncation: a frame declares five
bytes but only three remain. The current slicer passes the short `b"abc"` payload to
`deserialize` before the later apply-message count assertion; the fixed branch rejects the
length mismatch before invoking a deserializer. TLC finds the current `TruncatedDecodeSafety`
counterexample (4 states generated) and checks the fixed branch (4 states generated). The runtime
probe patches the real facade deserializer and records the truncated payload.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationTruncatedLengthCurrent.cfg models/serialization/ParslSerializationTruncatedLength.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationTruncatedLengthFixed.cfg models/serialization/ParslSerializationTruncatedLength.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_serialization_truncated_length_runtime.py -v
```

`ParslSerializerRegistry.tla` models the concrete `facade.deserialize` registry order. With a
colliding identifier, the current configuration decodes a data payload through the code registry
and violates `DispatchSafety`; the fixed configuration rejects the ambiguous header, while the
normal `C2`/`02` configuration passes. `tests/test_serializer_registry_runtime.py` observes the
current code-first behavior directly.

`ParslZMQSerializationEndToEnd.tla` combines the default `C2`/`02` headers with multipart frame
progress, route checks, duplicate/drop handling, worker attempts, and result correlation. The
current configuration finds a `ResultCorrelationSafety` counterexample; the fixed configuration
classifies late or terminal results as stale and checks 562,641 generated states (118,496 distinct
states). `TerminalResultSafety` makes the terminal-Future boundary explicit: a result frame must
not resolve a Future that is already rejected. The concrete HTEX result-worker probe in
`tests/test_htex_result_queue_runtime.py` shows the current `Future.set_result` failure for a
cancelled Future after the task bookkeeping entry has already been removed.
`ParslZMQSerializationEndToEndSmoke.cfg` fixes `MAX_RETRIES = 0` and the corrected route/result
invariants complete in 2,589 generated and 760 distinct states, providing a fast regression run.
The full `ParslZMQSerializationEndToEndFixed.cfg` configuration is also in the foundational smoke
gate, retaining one retry so late result correlation, duplicate frames, route recovery, and
payload rejection are checked together.

`ParslTaskTransport.tla` is the smaller cross-layer companion: a bounded callable/argument object
graph must finish serialization before task transport, decoding must precede worker dispatch, and
results are correlated with the current physical attempt. Result acceptance additionally requires
an explicit valid result envelope and payload-validity bit, so an unverified frame cannot resolve
the logical Future. TLC checks 859 generated/288 distinct states for the default one-retry
configuration. `tests/test_task_transport_runtime.py` sends a
real `pack_apply_message` payload through an in-process ZMQ pair, decodes it with the real facade,
and invokes the reconstructed closure.

`ParslTaskTransportSmoke.cfg` keeps the full bounded callable/argument/closure graph but sets
`MAX_RETRIES = 0`. It provides a fast terminal-path regression for the serialization gate,
task/result wire ordering, and Future-resolution invariants; TLC checks 69 generated / 29 distinct
states at depth 14.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslTaskTransport.cfg models/serialization/ParslTaskTransport.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_task_transport_runtime.py -v
```

`ParslTaskTransportCloseRace.tla` adds the sender lifecycle to that boundary. The current branch
allows a ready serialized task to reach `TasksOutgoing.put()` after close, while the fixed branch
rejects it before touching the terminated socket. The runtime bridge uses a real
`pack_apply_message` payload and a closed-socket double.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslTaskTransportCloseRaceCurrent.cfg models/serialization/ParslTaskTransportCloseRace.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslTaskTransportCloseRaceFixed.cfg models/serialization/ParslTaskTransportCloseRace.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_task_transport_close_runtime.py -v
```

`ParslFunctionObjectContents.tla` is the smallest callable-content model. It snapshots a
closure's captured value and the argument value at their two serialization boundaries, permits
the submitter to mutate its source object afterward, then decodes and runs the captured content.
The `MutationIsolation` invariant checks that post-serialization mutation cannot alter the
worker's result. The runtime probe performs the same check with the real `dill`-backed facade.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslFunctionObjectContents.cfg models/serialization/ParslFunctionObjectContents.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_function_object_contents_runtime.py -v
```

`ParslPythonSmoke.cfg` provides the smallest complete object-graph check for `ParslPython.tla`:
one function root and one argument root with no nested edges. It generates 92 states (31 distinct)
and is useful for fast regression checks before exploring the larger cyclic graph.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslPythonSmoke.cfg models/serialization/ParslPython.tla
```

`ParslSerializationFallback.tla` models the facade's serializer iteration: a failed registered
serializer is suppressed while later serializers are tried, and the final serializer exception is
re-raised only when every method fails. The runtime probe replaces the data registry with small
real facade-compatible serializers and checks both fallback and all-failed paths.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationFallbackPrimary.cfg models/serialization/ParslSerializationFallback.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationFallbackSecondary.cfg models/serialization/ParslSerializationFallback.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationFallbackFailure.cfg models/serialization/ParslSerializationFallback.tla
```

`ParslSerializationEmptyRegistry.tla` covers the no-method boundary. With an empty selected
registry, the current `facade.serialize` loop reaches its final result check without assigning
`result`, leaking `UnboundLocalError`. The fixed branch rejects the request explicitly. The
runtime probe clears the real data registry and restores it in a `finally` block.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationEmptyRegistryCurrent.cfg models/serialization/ParslSerializationEmptyRegistry.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationEmptyRegistryFixed.cfg models/serialization/ParslSerializationEmptyRegistry.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_serialization_empty_registry_runtime.py -v
```

`ParslSerializationPluginCache.tla` models successful dynamic deserializer loading. The first
unknown header imports and instantiates the plugin; subsequent payloads reuse the entry in
`additional_methods_for_deserialization` without another import. The runtime probe uses a fake
module and counts imports and plugin instances.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationPluginCache.cfg models/serialization/ParslSerializationPluginCache.tla
```

`ParslCallableMutationCache.tla` makes the immutability assumption behind
`DillCallableSerializer` explicit. A mutable, hashable callable is serialized once, mutated, and
serialized again; the current `lru_cache` path returns the old payload, while the fixed branch
invalidates/recomputes it. `tests/test_callable_mutation_cache_runtime.py` reproduces the stale
callable state with the real dill serializer.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCallableMutationCacheCurrent.cfg models/serialization/ParslCallableMutationCache.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCallableMutationCacheFixed.cfg models/serialization/ParslCallableMutationCache.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_callable_mutation_cache_runtime.py -v
```

`ParslObjectSnapshotRetry.tla` connects mutable Python object contents to physical retries. The
current cache reuses the first serialized object version for a retry after mutation; TLC finds
`SnapshotSafety` at depth 7 (26 states generated). The fixed branch captures the object graph at
each retry boundary and checks 18 distinct states. This refines the concrete mutable-callable
probe above toward task-attempt semantics.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslObjectSnapshotRetryCurrent.cfg models/serialization/ParslObjectSnapshotRetry.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslObjectSnapshotRetryFixed.cfg models/serialization/ParslObjectSnapshotRetry.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_callable_mutation_cache_runtime.py tests/test_serialization_runtime.py -v
```

The serialization runtime probe also checks the corresponding data-root boundary: a mutable
argument graph is captured by `pack_apply_message`, so mutating the caller's dictionary after
packing does not change the queued payload. This is the concrete argument-side evidence for the
object snapshot abstraction (alongside the closure snapshot test).

`ParslZMQObjectSnapshot.tla` connects that object snapshot boundary to a queued multipart frame.
The current branch lets mutation after serialization change the in-flight payload; TLC finds
`PayloadImmutability` after 5 states. The fixed branch keeps the captured bytes immutable through
receive/decode and checks 9 distinct states. The concrete round-trip evidence is in
`tests/test_zmq_serialization_runtime.py` and `tests/test_serialization_runtime.py`.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslZMQObjectSnapshotCurrent.cfg models/serialization/ParslZMQObjectSnapshot.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslZMQObjectSnapshotFixed.cfg models/serialization/ParslZMQObjectSnapshot.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_zmq_serialization_runtime.py tests/test_serialization_runtime.py tests/test_serialization_binary_payload_runtime.py -v
```

`ParslCallableDeserializeCache.tla` checks the other side of the same cache. The current
`DillCallableSerializer.deserialize` cache can return the same mutable callable instance for
repeated identical payloads; a mutation made by one task is then visible to the next task. The
current configuration violates `FreshSecondDecode`, while the fixed configuration creates a fresh
object and checks 8 generated/4 distinct states. The runtime probe demonstrates the alias with a
real dill payload.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCallableDeserializeCacheCurrent.cfg models/serialization/ParslCallableDeserializeCache.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCallableDeserializeCacheFixed.cfg models/serialization/ParslCallableDeserializeCache.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_callable_deserialize_cache_runtime.py -v
```

This mutable-instance alias is recorded as BUG-103: repeated task decodes can observe a prior
task's callable mutation when the deserializer cache returns the same object.

`ParslCallableSerializerCache.tla` models the cache-key boundary for callable serialization.
`DillCallableSerializer.serialize` uses an `lru_cache`, so an otherwise serializable callable
with `__hash__ = None` fails before dill is reached. The candidate fixed branch bypasses the
hash-based cache for that object. `tests/test_callable_serializer_cache_runtime.py` compares the
real callable serializer with uncached `DillSerializer` behavior.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCallableSerializerCache.cfg models/serialization/ParslCallableSerializerCache.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslCallableSerializerCacheFixed.cfg models/serialization/ParslCallableSerializerCache.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_callable_serializer_cache_runtime.py -v
```

`ParslSerializationPluginFailureCache.tla` models a failed dynamically loaded deserializer. The
current `facade.deserialize` inserts the plugin into `additional_methods_for_deserialization`
before invoking its `deserialize` method, so a decode exception leaves the failing instance
cached. The fixed branch evicts it, allowing a later request to reload a healthy plugin. The
runtime probe injects a fake plugin and observes the current cache entry.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationPluginFailureCacheCurrent.cfg models/serialization/ParslSerializationPluginFailureCache.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationPluginFailureCacheFixed.cfg models/serialization/ParslSerializationPluginFailureCache.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_serialization_plugin_failure_cache_runtime.py -v
```

This failure-cache boundary is recorded as BUG-104: a plugin that raises during decoding remains
in the deserializer cache and can poison subsequent requests.

`ParslPoolExecutorCallableCache.tla` models the callable cache in
`parsl.concurrent.ParslPoolExecutor.get_app`. The current dictionary lookup rejects an otherwise
valid callable object whose `__hash__` is `None`; the fixed branch uses an identity-compatible
cache path. The runtime probe invokes the real cache lookup with an unhashable callable object.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslPoolExecutorCallableCacheCurrent.cfg models/serialization/ParslPoolExecutorCallableCache.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslPoolExecutorCallableCacheFixed.cfg models/serialization/ParslPoolExecutorCallableCache.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_pool_executor_callable_cache_runtime.py -v
```

This callable-cache boundary is recorded as BUG-102: an otherwise serializable callable with
`__hash__ = None` is rejected by the current hash-keyed cache before dill is attempted.
