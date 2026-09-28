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
