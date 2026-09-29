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

`ParslSerializerRegistry.tla` models the concrete `facade.deserialize` registry order. With a
colliding identifier, the current configuration decodes a data payload through the code registry
and violates `DispatchSafety`; the fixed configuration rejects the ambiguous header, while the
normal `C2`/`02` configuration passes. `tests/test_serializer_registry_runtime.py` observes the
current code-first behavior directly.

`ParslZMQSerializationEndToEnd.tla` combines the default `C2`/`02` headers with multipart frame
progress, route checks, duplicate/drop handling, worker attempts, and result correlation. The
current configuration finds a `ResultCorrelationSafety` counterexample; the fixed configuration
classifies late or terminal results as stale and checks 562,641 states.

`ParslSerializationFallback.tla` models the facade's serializer iteration: a failed registered
serializer is suppressed while later serializers are tried, and the final serializer exception is
re-raised only when every method fails. The runtime probe replaces the data registry with small
real facade-compatible serializers and checks both fallback and all-failed paths.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationFallbackPrimary.cfg models/serialization/ParslSerializationFallback.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationFallbackSecondary.cfg models/serialization/ParslSerializationFallback.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslSerializationFallbackFailure.cfg models/serialization/ParslSerializationFallback.tla
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

`ParslPoolExecutorCallableCache.tla` models the callable cache in
`parsl.concurrent.ParslPoolExecutor.get_app`. The current dictionary lookup rejects an otherwise
valid callable object whose `__hash__` is `None`; the fixed branch uses an identity-compatible
cache path. The runtime probe invokes the real cache lookup with an unhashable callable object.

```bash
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslPoolExecutorCallableCacheCurrent.cfg models/serialization/ParslPoolExecutorCallableCache.tla
java -cp tla2tools.jar tlc2.TLC -config models/serialization/ParslPoolExecutorCallableCacheFixed.cfg models/serialization/ParslPoolExecutorCallableCache.tla
/tmp/parsl-venv/bin/python -m unittest tests/test_pool_executor_callable_cache_runtime.py -v
```
