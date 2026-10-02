--------------------------- MODULE ParslFunctionEnvironmentCacheIdentity ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Function environment-package cache identity.
 *
 * Work Queue and TaskVine cache _prepare_package results in a map keyed by
 * id(fn).  A recycled Python object id can therefore return an environment
 * package produced for different callable contents.  The fixed branch uses
 * a content/snapshot key instead of a recycled object identity.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES phase, firstContent, secondContent, cacheKey, returnedPackage
vars == <<phase, firstContent, secondContent, cacheKey, returnedPackage>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "empty"
    /\ firstContent = "old-imports"
    /\ secondContent = "new-imports"
    /\ cacheKey = "unset"
    /\ returnedPackage = "unset"

CacheFirst ==
    /\ phase = "empty"
    /\ cacheKey' = IF USE_FIXED THEN firstContent ELSE "object-42"
    /\ returnedPackage' = "package-old"
    /\ phase' = "cached"
    /\ UNCHANGED <<firstContent, secondContent>>

LookupSecond ==
    /\ phase = "cached"
    /\ cacheKey' = IF USE_FIXED THEN secondContent ELSE "object-42"
    /\ returnedPackage' = IF USE_FIXED THEN "package-new" ELSE returnedPackage
    /\ phase' = "looked_up"
    /\ UNCHANGED <<firstContent, secondContent>>

Next ==
    \/ CacheFirst
    \/ LookupSecond
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase \in {"empty", "cached", "looked_up"}
    /\ firstContent = "old-imports"
    /\ secondContent = "new-imports"
    /\ cacheKey \in {"unset", "object-42", "old-imports", "new-imports"}
    /\ returnedPackage \in {"unset", "package-old", "package-new"}

FreshEnvironmentSafety ==
    phase = "looked_up" => returnedPackage = "package-new"

=============================================================================
