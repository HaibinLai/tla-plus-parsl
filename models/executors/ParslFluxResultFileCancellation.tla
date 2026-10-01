--------------------------- MODULE ParslFluxResultFileCancellation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Flux physical future, result-file publication, wrapper cancellation, and
 * late callback delivery in one bounded protocol.  The Current branch lets a
 * callback write to a cancelled wrapper; the Fixed branch discards that stale
 * callback while preserving result-file validation for live wrappers.
 ***************************************************************************)

CONSTANT USE_FIXED

FluxStates == {"absent", "running", "succeeded", "failed", "cancelled"}
WrapperStates == {"pending", "cancelled", "succeeded", "failed"}
FileStates == {"absent", "valid", "malformed", "exception"}

VARIABLES flux, wrapper, file, callback, callbackRaised
vars == <<flux, wrapper, file, callback, callbackRaised>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ flux = "absent"
    /\ wrapper = "pending"
    /\ file = "absent"
    /\ callback = FALSE
    /\ callbackRaised = FALSE

Submit ==
    /\ flux = "absent"
    /\ flux' = "running"
    /\ UNCHANGED <<wrapper, file, callback, callbackRaised>>

FluxSucceeds ==
    /\ flux = "running"
    /\ flux' = "succeeded"
    /\ callback' = TRUE
    /\ UNCHANGED <<wrapper, file, callbackRaised>>

FluxCancels ==
    /\ flux = "running"
    /\ flux' = "cancelled"
    /\ wrapper' = IF USE_FIXED THEN "cancelled" ELSE wrapper
    /\ UNCHANGED <<file, callback, callbackRaised>>

WrapperCancels ==
    /\ flux = "running"
    /\ wrapper = "pending"
    /\ wrapper' = "cancelled"
    /\ UNCHANGED <<flux, file, callback, callbackRaised>>

PublishFile(kind) ==
    /\ flux = "succeeded"
    /\ callback
    /\ file = "absent"
    /\ kind \in {"valid", "malformed", "exception"}
    /\ file' = kind
    /\ UNCHANGED <<flux, wrapper, callback, callbackRaised>>

CompleteCallback ==
    /\ flux = "succeeded"
    /\ callback
    /\ file \in {"valid", "malformed", "exception"}
    /\ IF wrapper = "cancelled"
          THEN IF USE_FIXED
               THEN /\ UNCHANGED wrapper
                    /\ UNCHANGED callbackRaised
               ELSE /\ callbackRaised' = TRUE
                    /\ UNCHANGED wrapper
          ELSE /\ wrapper' = IF file = "valid" THEN "succeeded" ELSE "failed"
               /\ UNCHANGED callbackRaised
    /\ callback' = FALSE
    /\ UNCHANGED <<flux, file>>

Next ==
    \/ Submit
    \/ FluxSucceeds
    \/ FluxCancels
    \/ WrapperCancels
    \/ \E kind \in {"valid", "malformed", "exception"} : PublishFile(kind)
    \/ CompleteCallback
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ flux \in FluxStates
    /\ wrapper \in WrapperStates
    /\ file \in FileStates
    /\ callback \in BOOLEAN
    /\ callbackRaised \in BOOLEAN

NoLateCallbackWrite == ~callbackRaised
FileResultSafety == wrapper = "succeeded" => file = "valid"
TerminalWrapperStable == wrapper = "cancelled" => wrapper = "cancelled"

=============================================================================
SPECIFICATION Spec

INVARIANTS
    TypeOK
    NoLateCallbackWrite
    FileResultSafety
    TerminalWrapperStable
