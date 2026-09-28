--------------------------- MODULE ParslGlobusComputeSubmitRace ---------------------------
EXTENDS Naturals

(***************************************************************************
 * GlobusComputeExecutor.submit temporarily writes a task's resource
 * specification into one shared SDK Executor, calls SDK submit, and restores
 * the defaults in finally.  Two concurrent calls can therefore overwrite the
 * configuration observed by the first call.  USE_FIXED models serializing the
 * whole override/submit/restore sequence with a lock.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES phaseA, phaseB, sdkConfig, seenA, seenB, lock
vars == <<phaseA, phaseB, sdkConfig, seenA, seenB, lock>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phaseA = "idle"
    /\ phaseB = "idle"
    /\ sdkConfig = "default"
    /\ seenA = "none"
    /\ seenB = "none"
    /\ lock = "none"

BeginA ==
    /\ phaseA = "idle"
    /\ (USE_FIXED => lock = "none")
    /\ phaseA' = "active"
    /\ sdkConfig' = "A"
    /\ lock' = IF USE_FIXED THEN "A" ELSE lock
    /\ UNCHANGED <<phaseB, seenA, seenB>>

BeginB ==
    /\ phaseB = "idle"
    /\ (USE_FIXED => lock = "none")
    /\ phaseB' = "active"
    /\ sdkConfig' = "B"
    /\ lock' = IF USE_FIXED THEN "B" ELSE lock
    /\ UNCHANGED <<phaseA, seenA, seenB>>

SubmitA ==
    /\ phaseA = "active"
    /\ phaseA' = "done"
    /\ seenA' = sdkConfig
    /\ sdkConfig' = "default"
    /\ lock' = IF USE_FIXED THEN "none" ELSE lock
    /\ UNCHANGED <<phaseB, seenB>>

SubmitB ==
    /\ phaseB = "active"
    /\ phaseB' = "done"
    /\ seenB' = sdkConfig
    /\ sdkConfig' = "default"
    /\ lock' = IF USE_FIXED THEN "none" ELSE lock
    /\ UNCHANGED <<phaseA, seenA>>

Done ==
    /\ phaseA \in {"idle", "done"}
    /\ phaseB \in {"idle", "done"}
    /\ UNCHANGED vars

Next == BeginA \/ BeginB \/ SubmitA \/ SubmitB \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phaseA \in {"idle", "active", "done"}
    /\ phaseB \in {"idle", "active", "done"}
    /\ sdkConfig \in {"default", "A", "B"}
    /\ seenA \in {"none", "default", "A", "B"}
    /\ seenB \in {"none", "default", "A", "B"}
    /\ lock \in {"none", "A", "B"}

SubmitConfigSafety ==
    /\ phaseA = "done" => seenA = "A"
    /\ phaseB = "done" => seenB = "B"

=============================================================================
