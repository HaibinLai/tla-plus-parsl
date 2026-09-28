--------------------------- MODULE ParslDataFutureCopy ---------------------------
EXTENDS Naturals

(***************************************************************************
 * File/DataFuture staging-copy abstraction.
 *
 * Parsl keeps the global File URL separate from site-local path annotations.
 * DataManager.optionally_stage_in makes a clean copy before a staging provider
 * can attach a local path.  A DataFuture may become usable only after its
 * parent Future has completed successfully.
 ***************************************************************************)

PHASES == {"original", "copying", "staged", "failed"}
PARENT == {"pending", "ready", "failed"}

VARIABLES phase, originalLocal, capturedOriginalLocal, copyLocal,
          parentState, dependentState
vars == <<phase, originalLocal, capturedOriginalLocal, copyLocal,
          parentState, dependentState>>

Init ==
    /\ phase = "original"
    /\ originalLocal = "caller-path"
    /\ capturedOriginalLocal = "none"
    /\ copyLocal = "none"
    /\ parentState = "pending"
    /\ dependentState = "waiting"

AnnotateOriginal ==
    /\ phase = "original"
    /\ originalLocal = "caller-path"
    /\ originalLocal' = "updated-caller-path"
    /\ UNCHANGED <<phase, capturedOriginalLocal, copyLocal,
                    parentState, dependentState>>

MakeCleanCopy ==
    /\ phase = "original"
    /\ capturedOriginalLocal' = originalLocal
    /\ copyLocal' = "none"
    /\ phase' = "copying"
    /\ UNCHANGED <<originalLocal, parentState, dependentState>>

ParentReady ==
    /\ parentState = "pending"
    /\ parentState' = "ready"
    /\ UNCHANGED <<phase, originalLocal, capturedOriginalLocal,
                    copyLocal, dependentState>>

ParentFailed ==
    /\ parentState = "pending"
    /\ parentState' = "failed"
    /\ phase' = "failed"
    /\ dependentState' = "failed"
    /\ UNCHANGED <<originalLocal, capturedOriginalLocal, copyLocal>>

ProviderWritesCopy ==
    /\ phase = "copying"
    /\ copyLocal = "none"
    /\ copyLocal' = "staging-path"
    /\ phase' = "staged"
    /\ UNCHANGED <<originalLocal, capturedOriginalLocal,
                    parentState, dependentState>>

ProviderFails ==
    /\ phase = "copying"
    /\ phase' = "failed"
    /\ dependentState' = "failed"
    /\ UNCHANGED <<originalLocal, capturedOriginalLocal, copyLocal,
                    parentState>>

RunDependent ==
    /\ phase = "staged"
    /\ parentState = "ready"
    /\ dependentState = "waiting"
    /\ dependentState' = "running"
    /\ UNCHANGED <<phase, originalLocal, capturedOriginalLocal,
                    copyLocal, parentState>>

CompleteDependent ==
    /\ dependentState = "running"
    /\ dependentState' = "succeeded"
    /\ UNCHANGED <<phase, originalLocal, capturedOriginalLocal,
                    copyLocal, parentState>>

Next ==
    \/ AnnotateOriginal
    \/ MakeCleanCopy
    \/ ParentReady
    \/ ParentFailed
    \/ ProviderWritesCopy
    \/ ProviderFails
    \/ RunDependent
    \/ CompleteDependent
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in PHASES
    /\ originalLocal \in {"caller-path", "updated-caller-path"}
    /\ capturedOriginalLocal \in {"none", "caller-path", "updated-caller-path"}
    /\ copyLocal \in {"none", "staging-path"}
    /\ parentState \in PARENT
    /\ dependentState \in {"waiting", "running", "succeeded", "failed"}

CopyIsolation ==
    phase \in {"copying", "staged"}
        => /\ capturedOriginalLocal = originalLocal
           /\ copyLocal # "caller-path"

CleanCopySafety ==
    phase = "copying" => copyLocal = "none"

DependencySafety ==
    dependentState = "running" =>
        /\ phase = "staged"
        /\ parentState = "ready"

FailureSafety ==
    dependentState = "failed" => phase = "failed"

=============================================================================
