--------------------------- MODULE ParslGlobusComputeConfig ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * A focused GlobusComputeExecutor configuration-isolation model.
 *
 * submit() temporarily writes a task-specific resource specification into the
 * shared Globus Compute Executor, calls the underlying submit, and restores
 * the configured defaults in a finally block.  The wrapper itself has no
 * lock.  SERIALIZED models the required caller-side submitter lock; FALSE
 * probes interleaved calls to expose cross-task resource-specification use.
 ***************************************************************************)

CONSTANT SERIALIZED

Tasks == {"A", "B"}
Specs == {"default", "specA", "specB"}
Phases == {"idle", "submitting", "submitted"}

VARIABLES phase, desiredSpec, activeSpec, observedSpec
vars == <<phase, desiredSpec, activeSpec, observedSpec>>

Init ==
    /\ SERIALIZED \in BOOLEAN
    /\ phase = [t \in Tasks |-> "idle"]
    /\ desiredSpec = [t \in Tasks |-> IF t = "A" THEN "specA" ELSE "specB"]
    /\ activeSpec = "default"
    /\ observedSpec = [t \in Tasks |-> "none"]

BeginSubmit(t) ==
    /\ t \in Tasks
    /\ phase[t] = "idle"
    /\ ~SERIALIZED \/ \A u \in Tasks : phase[u] = "idle"
    /\ phase' = [phase EXCEPT ![t] = "submitting"]
    /\ activeSpec' = desiredSpec[t]
    /\ UNCHANGED <<desiredSpec, observedSpec>>

UnderlyingSubmit(t) ==
    /\ t \in Tasks
    /\ phase[t] = "submitting"
    /\ phase' = [phase EXCEPT ![t] = "submitted"]
    /\ observedSpec' = [observedSpec EXCEPT ![t] = activeSpec]
    /\ UNCHANGED <<desiredSpec, activeSpec>>

FinishSubmit(t) ==
    /\ t \in Tasks
    /\ phase[t] = "submitted"
    /\ phase' = [phase EXCEPT ![t] = "idle"]
    /\ activeSpec' = "default"
    /\ UNCHANGED <<desiredSpec, observedSpec>>

Next ==
    \/ \E t \in Tasks : BeginSubmit(t)
    \/ \E t \in Tasks : UnderlyingSubmit(t)
    \/ \E t \in Tasks : FinishSubmit(t)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ SERIALIZED \in BOOLEAN
    /\ phase \in [Tasks -> Phases]
    /\ desiredSpec \in [Tasks -> (Specs \ {"default"})]
    /\ activeSpec \in Specs
    /\ observedSpec \in [Tasks -> (Specs \cup {"none"})]

ConfigurationSafety ==
    \A t \in Tasks :
        observedSpec[t] \in {"none", desiredSpec[t]}

DefaultRestorationSafety ==
    (\A t \in Tasks : phase[t] = "idle") => activeSpec = "default"

=============================================================================
