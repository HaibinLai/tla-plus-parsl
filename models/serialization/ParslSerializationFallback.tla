--------------------------- MODULE ParslSerializationFallback ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Serializer fallback order in parsl/serialize/facade.py.
 *
 * serialize() tries registered serializers in insertion order.  A failure from
 * one method is suppressed while the next method is attempted; only when all
 * methods fail is the last exception re-raised.
 ***************************************************************************)

CONSTANTS PRIMARY_OK, FALLBACK_OK
States == {"ready", "primary", "fallback", "serialized", "failed"}

VARIABLES state, attempts, result
vars == <<state, attempts, result>>

Init ==
    /\ PRIMARY_OK \in BOOLEAN
    /\ FALLBACK_OK \in BOOLEAN
    /\ state = "ready"
    /\ attempts = 0
    /\ result = "none"

TryPrimary ==
    /\ state = "ready"
    /\ state' = IF PRIMARY_OK THEN "serialized" ELSE "fallback"
    /\ attempts' = 1
    /\ result' = IF PRIMARY_OK THEN "primary" ELSE result

TryFallback ==
    /\ state = "fallback"
    /\ state' = IF FALLBACK_OK THEN "serialized" ELSE "failed"
    /\ attempts' = 2
    /\ result' = IF FALLBACK_OK THEN "fallback" ELSE "last-error"

Next ==
    \/ TryPrimary
    \/ TryFallback
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ PRIMARY_OK \in BOOLEAN
    /\ FALLBACK_OK \in BOOLEAN
    /\ state \in States
    /\ attempts \in 0..2
    /\ result \in {"none", "primary", "fallback", "last-error"}

FallbackSafety ==
    state = "serialized" => result \in {"primary", "fallback"}

FailureSafety ==
    state = "failed" => ~PRIMARY_OK /\ ~FALLBACK_OK /\ result = "last-error"

=============================================================================
