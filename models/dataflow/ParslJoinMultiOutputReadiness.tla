------------------------- MODULE ParslJoinMultiOutputReadiness -------------------------
EXTENDS Naturals, Integers, FiniteSets, Sequences

(***************************************************************************
 * Multi-output stage-out joined with join_app callback aggregation.
 *
 * Each output has its own physical transfer and captured source version.
 * The Current branch publishes each output Future independently and allows
 * the join callback to finish after one output.  The Fixed branch publishes
 * the output set only when every transfer is complete, every captured version
 * is current, and every output callback has been observed.
 ***************************************************************************)

CONSTANT USE_FIXED
Outputs == {"o1", "o2"}
TransferStates == {"idle", "sending", "ready", "failed"}
OutputStates == {"unresolved", "ready", "failed"}

VARIABLES app, sourceVersion, transfer, captured, published, output,
          observed, join, result

vars == <<app, sourceVersion, transfer, captured, published, output,
           observed, join, result>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ app = "running"
    /\ sourceVersion = 0
    /\ transfer = [o \in Outputs |-> "idle"]
    /\ captured = [o \in Outputs |-> -1]
    /\ published = [o \in Outputs |-> -1]
    /\ output = [o \in Outputs |-> "unresolved"]
    /\ observed = [o \in Outputs |-> FALSE]
    /\ join = "waiting"
    /\ result = <<>>

CompleteApp ==
    /\ app = "running"
    /\ app' = "succeeded"
    /\ UNCHANGED <<sourceVersion, transfer, captured, published, output,
                    observed, join, result>>

Begin(o) ==
    /\ o \in Outputs
    /\ app = "succeeded"
    /\ transfer[o] = "idle"
    /\ transfer' = [transfer EXCEPT ![o] = "sending"]
    /\ captured' = [captured EXCEPT ![o] = sourceVersion]
    /\ UNCHANGED <<app, sourceVersion, published, output, observed, join,
                    result>>

ChangeSource ==
    /\ sourceVersion = 0
    /\ \E o \in Outputs : transfer[o] = "sending"
    /\ sourceVersion' = 1
    /\ UNCHANGED <<app, transfer, captured, published, output, observed,
                    join, result>>

CompleteTransfer(o) ==
    /\ o \in Outputs
    /\ transfer[o] = "sending"
    /\ transfer' = [transfer EXCEPT ![o] = "ready"]
    /\ UNCHANGED <<app, sourceVersion, captured, published, output, observed,
                    join, result>>

FailTransfer(o) ==
    /\ o \in Outputs
    /\ transfer[o] = "sending"
    /\ transfer' = [transfer EXCEPT ![o] = "failed"]
    /\ UNCHANGED <<app, sourceVersion, captured, published, output, observed,
                    join, result>>

RetryTransfer(o) ==
    /\ o \in Outputs
    /\ transfer[o] = "failed"
    /\ app = "succeeded"
    /\ transfer' = [transfer EXCEPT ![o] = "sending"]
    /\ captured' = [captured EXCEPT ![o] = sourceVersion]
    /\ UNCHANGED <<app, sourceVersion, published, output, observed, join,
                    result>>

Publish(o) ==
    /\ o \in Outputs
    /\ transfer[o] = "ready"
    /\ IF USE_FIXED
          THEN /\ (\A x \in Outputs : transfer[x] = "ready")
               /\ (\A x \in Outputs : captured[x] = sourceVersion)
               /\ output' = [x \in Outputs |-> "ready"]
               /\ published' = [x \in Outputs |-> sourceVersion]
          ELSE /\ output' = [output EXCEPT ![o] = "ready"]
               /\ published' = [published EXCEPT ![o] = captured[o]]
    /\ UNCHANGED <<app, sourceVersion, transfer, captured, observed, join,
                    result>>

PublishFailure(o) ==
    /\ o \in Outputs
    /\ transfer[o] = "failed"
    /\ output' = [output EXCEPT ![o] = "failed"]
    /\ UNCHANGED <<app, sourceVersion, transfer, captured, published,
                    observed, join, result>>

Observe(o) ==
    /\ o \in Outputs
    /\ output[o] = "ready"
    /\ observed' = [observed EXCEPT ![o] = TRUE]
    /\ UNCHANGED <<app, sourceVersion, transfer, captured, published, output,
                    join, result>>

FinalizeJoin ==
    /\ join = "waiting"
    /\ IF USE_FIXED
          THEN /\ (\A o \in Outputs : output[o] = "ready")
               /\ (\A o \in Outputs : observed[o])
          ELSE /\ \E o \in Outputs : output[o] = "ready"
    /\ join' = "succeeded"
    /\ result' = <<published["o1"], published["o2"]>>
    /\ UNCHANGED <<app, sourceVersion, transfer, captured, published,
                    output, observed>>

FinalizeFailure ==
    /\ join = "waiting"
    /\ \E o \in Outputs : output[o] = "failed"
    /\ join' = "failed"
    /\ UNCHANGED <<app, sourceVersion, transfer, captured, published, output,
                    observed, result>>

Next ==
    \/ CompleteApp
    \/ \E o \in Outputs : Begin(o)
    \/ ChangeSource
    \/ \E o \in Outputs : CompleteTransfer(o) \/ FailTransfer(o)
    \/ \E o \in Outputs : RetryTransfer(o)
    \/ \E o \in Outputs : Publish(o) \/ PublishFailure(o)
    \/ \E o \in Outputs : Observe(o)
    \/ FinalizeJoin
    \/ FinalizeFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ app \in {"running", "succeeded"}
    /\ sourceVersion \in 0..1
    /\ transfer \in [Outputs -> TransferStates]
    /\ captured \in [Outputs -> -1..1]
    /\ published \in [Outputs -> -1..1]
    /\ output \in [Outputs -> OutputStates]
    /\ observed \in [Outputs -> BOOLEAN]
    /\ join \in {"waiting", "succeeded", "failed"}
    /\ result \in Seq(-1..1)

PublicationSafety ==
    \A o \in Outputs : output[o] = "ready" =>
        /\ app = "succeeded"
        /\ transfer[o] = "ready"
        /\ published[o] = sourceVersion

JoinCompleteness ==
    join = "succeeded" =>
        /\ (\A o \in Outputs : output[o] = "ready")
        /\ (\A o \in Outputs : observed[o])
        /\ Len(result) = 2

ConsumerSafety ==
    join = "succeeded" => result = <<published["o1"], published["o2"]>>

=============================================================================
CONSTANT USE_FIXED = TRUE

SPECIFICATION Spec

INVARIANTS
    TypeOK
    PublicationSafety
    JoinCompleteness
    ConsumerSafety
