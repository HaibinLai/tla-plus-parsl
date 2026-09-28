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
Endpoints == {"default", "endpointA", "endpointB"}
Phases == {"idle", "submitting", "submitted"}

VARIABLES phase, desiredSpec, desiredEndpoint, activeSpec, activeEndpoint,
          observedSpec, observedEndpoint
vars == <<phase, desiredSpec, desiredEndpoint, activeSpec, activeEndpoint,
          observedSpec, observedEndpoint>>

Init ==
    /\ SERIALIZED \in BOOLEAN
    /\ phase = [t \in Tasks |-> "idle"]
    /\ desiredSpec = [t \in Tasks |-> IF t = "A" THEN "specA" ELSE "specB"]
    /\ desiredEndpoint = [t \in Tasks |-> IF t = "A" THEN "endpointA" ELSE "endpointB"]
    /\ activeSpec = "default"
    /\ activeEndpoint = "default"
    /\ observedSpec = [t \in Tasks |-> "none"]
    /\ observedEndpoint = [t \in Tasks |-> "none"]

BeginSubmit(t) ==
    /\ t \in Tasks
    /\ phase[t] = "idle"
    /\ ~SERIALIZED \/ \A u \in Tasks : phase[u] = "idle"
    /\ phase' = [phase EXCEPT ![t] = "submitting"]
    /\ activeSpec' = desiredSpec[t]
    /\ activeEndpoint' = desiredEndpoint[t]
    /\ UNCHANGED <<desiredSpec, desiredEndpoint, observedSpec, observedEndpoint>>

UnderlyingSubmit(t) ==
    /\ t \in Tasks
    /\ phase[t] = "submitting"
    /\ phase' = [phase EXCEPT ![t] = "submitted"]
    /\ observedSpec' = [observedSpec EXCEPT ![t] = activeSpec]
    /\ observedEndpoint' = [observedEndpoint EXCEPT ![t] = activeEndpoint]
    /\ UNCHANGED <<desiredSpec, desiredEndpoint, activeSpec, activeEndpoint>>

FinishSubmit(t) ==
    /\ t \in Tasks
    /\ phase[t] = "submitted"
    /\ phase' = [phase EXCEPT ![t] = "idle"]
    /\ activeSpec' = "default"
    /\ activeEndpoint' = "default"
    /\ UNCHANGED <<desiredSpec, desiredEndpoint, observedSpec, observedEndpoint>>

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
    /\ desiredEndpoint \in [Tasks -> (Endpoints \ {"default"})]
    /\ activeSpec \in Specs
    /\ activeEndpoint \in Endpoints
    /\ observedSpec \in [Tasks -> (Specs \cup {"none"})]
    /\ observedEndpoint \in [Tasks -> (Endpoints \cup {"none"})]

ConfigurationSafety ==
    \A t \in Tasks :
        /\ observedSpec[t] \in {"none", desiredSpec[t]}
        /\ observedEndpoint[t] \in {"none", desiredEndpoint[t]}

DefaultRestorationSafety ==
    (\A t \in Tasks : phase[t] = "idle")
        => /\ activeSpec = "default"
           /\ activeEndpoint = "default"

=============================================================================
