--------------------------- MODULE ParslCallableClosureMemo ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Callable closure contents versus memoization identity.
 *
 * Two nested Python functions can share a name/module while capturing
 * different closure values. Serialization preserves those values, but the
 * current BasicMemoizer function identity uses only name/module. The fixed
 * branch includes a symbolic closure identity in the memo key.
 **************************************************************************)

CONSTANT USE_FIXED

VARIABLES keyA, keyB, payloadA, payloadB, cacheKey, cacheResult,
          cacheReady, invoked, cacheHit, observedResult

vars == <<keyA, keyB, payloadA, payloadB, cacheKey, cacheResult,
           cacheReady, invoked, cacheHit, observedResult>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ keyA = "none"
    /\ keyB = "none"
    /\ payloadA = "none"
    /\ payloadB = "none"
    /\ cacheKey = "none"
    /\ cacheResult = "none"
    /\ cacheReady = FALSE
    /\ invoked = FALSE
    /\ cacheHit = FALSE
    /\ observedResult = "none"

ComputeIdentities ==
    /\ keyA = "none"
    /\ keyA' = IF USE_FIXED THEN "add:module:closure:1"
                         ELSE "add:module"
    /\ keyB' = IF USE_FIXED THEN "add:module:closure:2"
                         ELSE "add:module"
    /\ payloadA' = "callable:closure:1"
    /\ payloadB' = "callable:closure:2"
    /\ UNCHANGED <<cacheKey, cacheResult, cacheReady, invoked,
                    cacheHit, observedResult>>

MemoizeA ==
    /\ keyA # "none"
    /\ ~cacheReady
    /\ cacheKey' = keyA
    /\ cacheResult' = "result:closure:1"
    /\ cacheReady' = TRUE
    /\ UNCHANGED <<keyA, keyB, payloadA, payloadB, invoked,
                    cacheHit, observedResult>>

InvokeBHit ==
    /\ cacheReady
    /\ keyB = cacheKey
    /\ ~invoked
    /\ invoked' = TRUE
    /\ cacheHit' = TRUE
    /\ observedResult' = cacheResult
    /\ UNCHANGED <<keyA, keyB, payloadA, payloadB, cacheKey,
                    cacheResult, cacheReady>>

InvokeBMiss ==
    /\ cacheReady
    /\ keyB # cacheKey
    /\ ~invoked
    /\ invoked' = TRUE
    /\ cacheHit' = FALSE
    /\ observedResult' = "result:closure:2"
    /\ UNCHANGED <<keyA, keyB, payloadA, payloadB, cacheKey,
                    cacheResult, cacheReady>>

Next ==
    \/ ComputeIdentities
    \/ MemoizeA
    \/ InvokeBHit
    \/ InvokeBMiss
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ keyA \in {"none", "add:module", "add:module:closure:1"}
    /\ keyB \in {"none", "add:module", "add:module:closure:2"}
    /\ payloadA \in {"none", "callable:closure:1"}
    /\ payloadB \in {"none", "callable:closure:2"}
    /\ cacheKey \in {"none", "add:module", "add:module:closure:1"}
    /\ cacheResult \in {"none", "result:closure:1"}
    /\ cacheReady \in BOOLEAN
    /\ invoked \in BOOLEAN
    /\ cacheHit \in BOOLEAN
    /\ observedResult \in {"none", "result:closure:1", "result:closure:2"}

PayloadDistinguishes ==
    payloadA # "none" /\ payloadB # "none" => payloadA # payloadB

MemoResultSafety ==
    invoked => observedResult = "result:closure:2"

FixedIdentitySafety ==
    USE_FIXED /\ keyA # "none" => keyA # keyB

=============================================================================
