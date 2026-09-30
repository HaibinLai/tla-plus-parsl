---------------------- MODULE ParslCallableAliasRetry ----------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * Callable/argument aliasing across a physical retry.
 *
 * One mutable object is captured by a callable and also passed as an
 * argument.  The object can mutate between attempts.  The fixed transport
 * preserves the shared identity and captures the current source epoch for a
 * retry; the current transport decodes independent callable/argument roots.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES phase, attempt, sourceEpoch, capturedEpoch, decodedAlias, resultEpoch
vars == <<phase, attempt, sourceEpoch, capturedEpoch, decodedAlias, resultEpoch>>

Init ==
    /\ phase = "new"
    /\ attempt = 0
    /\ sourceEpoch = 0
    /\ capturedEpoch = -1
    /\ decodedAlias = FALSE
    /\ resultEpoch = -1

Encode ==
    /\ phase \in {"new", "retry"}
    /\ capturedEpoch' = sourceEpoch
    /\ decodedAlias' = FALSE
    /\ phase' = "encoded"
    /\ UNCHANGED <<attempt, sourceEpoch, resultEpoch>>

Mutate ==
    /\ phase = "encoded"
    /\ sourceEpoch = 0
    /\ sourceEpoch' = 1
    /\ IF USE_FIXED
          THEN /\ phase' = "retry"
               /\ capturedEpoch' = -1
          ELSE /\ phase' = phase
               /\ capturedEpoch' = capturedEpoch
    /\ UNCHANGED <<attempt, decodedAlias, resultEpoch>>

Decode ==
    /\ phase = "encoded"
    /\ phase' = "running"
    /\ decodedAlias' = USE_FIXED
    /\ UNCHANGED <<attempt, sourceEpoch, capturedEpoch, resultEpoch>>

Fail ==
    /\ phase = "running"
    /\ attempt = 0
    /\ phase' = "retry"
    /\ attempt' = 1
    /\ UNCHANGED <<sourceEpoch, capturedEpoch, decodedAlias, resultEpoch>>

Complete ==
    /\ phase = "running"
    /\ phase' = "done"
    /\ resultEpoch' = capturedEpoch
    /\ UNCHANGED <<attempt, sourceEpoch, capturedEpoch, decodedAlias>>

Next ==
    \/ Encode
    \/ Mutate
    \/ Decode
    \/ Fail
    \/ Complete
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"new", "encoded", "running", "retry", "done"}
    /\ attempt \in 0..1
    /\ sourceEpoch \in 0..1
    /\ capturedEpoch \in -1..1
    /\ decodedAlias \in BOOLEAN
    /\ resultEpoch \in -1..1

AliasSafety ==
    phase = "done" => decodedAlias

RetrySnapshotSafety ==
    phase = "done" /\ attempt = 1 => resultEpoch = sourceEpoch

AttemptBoundSafety ==
    attempt <= 1

=============================================================================
CONSTANT USE_FIXED = TRUE

SPECIFICATION Spec

INVARIANTS
    TypeOK
    AliasSafety
    RetrySnapshotSafety
    AttemptBoundSafety
