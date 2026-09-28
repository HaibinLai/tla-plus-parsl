--------------------------- MODULE ParslSerializationPluginError ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Dynamic serializer plugin validation.
 *
 * An unknown serializer header is dynamically imported.  The current
 * facade validates import/class construction but calls ``deserialize``
 * outside that error boundary, so a class without that method leaks a raw
 * AttributeError.  USE_FIXED models wrapping plugin-interface failures in
 * DeserializerPluginError.
 ***************************************************************************)

CONSTANT USE_FIXED
States == {"wire", "loaded", "decoded", "plugin_error", "wrapped_error"}

VARIABLES state, pluginHasDeserialize
vars == <<state, pluginHasDeserialize>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "wire"
    /\ pluginHasDeserialize = FALSE

LoadPlugin ==
    /\ state = "wire"
    /\ state' = "loaded"
    /\ UNCHANGED pluginHasDeserialize

InvokePlugin ==
    /\ state = "loaded"
    /\ IF pluginHasDeserialize
          THEN state' = "decoded"
          ELSE state' = IF USE_FIXED THEN "wrapped_error" ELSE "plugin_error"
    /\ UNCHANGED pluginHasDeserialize

Next ==
    \/ LoadPlugin
    \/ InvokePlugin
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ pluginHasDeserialize \in BOOLEAN

PluginErrorSafety ==
    state = "plugin_error" => USE_FIXED

=============================================================================
