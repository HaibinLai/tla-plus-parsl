--------------------------- MODULE ParslPoolExecutorCallableCache ---------------------------
EXTENDS Naturals

(***************************************************************************
 * ParslPoolExecutor.get_app callable cache lookup.
 *
 * get_app uses the callable object directly as a dictionary key.  A callable
 * object may be perfectly executable while deliberately being unhashable
 * (__hash__ = None).  USE_FIXED models an identity-based cache path for that
 * case instead of failing before submission.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES callableHashable, state, cacheEntries
vars == <<callableHashable, state, cacheEntries>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ callableHashable = FALSE
    /\ state = "new"
    /\ cacheEntries = 0

LookupCallable ==
    /\ state = "new"
    /\ state' = IF callableHashable \/ USE_FIXED THEN "ready" ELSE "error"
    /\ cacheEntries' = IF callableHashable \/ USE_FIXED THEN 1 ELSE 0
    /\ UNCHANGED callableHashable

Next ==
    \/ LookupCallable
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ callableHashable \in BOOLEAN
    /\ state \in {"new", "ready", "error"}
    /\ cacheEntries \in 0..1

UnhashableCallableSafety ==
    ~callableHashable => state # "error"

=============================================================================
