---------------- MODULE ParslThreeOutputVersionedStageOut ----------------
EXTENDS Naturals, Integers, FiniteSets

(***************************************************************************
 * Three-output versioned stage-out.
 *
 * Independent output transfers share one application Future.  A source change
 * during transfer and a failure of any one output must not expose a partial or
 * obsolete output set to consumers.
 ***************************************************************************)

CONSTANT USE_FIXED
Outputs == {"O1", "O2", "O3"}

VARIABLES app, sourceVersion, transfer, captured, published, outputFuture,
          consumer
vars == <<app, sourceVersion, transfer, captured, published, outputFuture,
           consumer>>

Init ==
    /\ app = "running"
    /\ sourceVersion = 0
    /\ transfer = [o \in Outputs |-> "idle"]
    /\ captured = [o \in Outputs |-> -1]
    /\ published = [o \in Outputs |-> -1]
    /\ outputFuture = [o \in Outputs |-> "unresolved"]
    /\ consumer = [o \in Outputs |-> "waiting"]

Begin ==
    /\ app = "running"
    /\ \A o \in Outputs : transfer[o] = "idle"
    /\ transfer' = [o \in Outputs |-> "sending"]
    /\ captured' = [o \in Outputs |-> sourceVersion]
    /\ UNCHANGED <<app, sourceVersion, published, outputFuture, consumer>>

ModifySource ==
    /\ sourceVersion = 0
    /\ \E o \in Outputs : transfer[o] = "sending"
    /\ sourceVersion' = 1
    /\ UNCHANGED <<app, transfer, captured, published, outputFuture, consumer>>

CompleteTransfer(o) ==
    /\ o \in Outputs
    /\ transfer[o] = "sending"
    /\ transfer' = [transfer EXCEPT ![o] = "ready"]
    /\ UNCHANGED <<app, sourceVersion, captured, published, outputFuture, consumer>>

FailTransfer(o) ==
    /\ o \in Outputs
    /\ transfer[o] = "sending"
    /\ transfer' = [transfer EXCEPT ![o] = "failed"]
    /\ UNCHANGED <<app, sourceVersion, captured, published, outputFuture, consumer>>

RetryTransfer(o) ==
    /\ o \in Outputs
    /\ transfer[o] = "failed"
    /\ transfer' = [transfer EXCEPT ![o] = "sending"]
    /\ captured' = [captured EXCEPT ![o] = sourceVersion]
    /\ UNCHANGED <<app, sourceVersion, published, outputFuture, consumer>>

CompleteApp ==
    /\ app = "running"
    /\ app' = "succeeded"
    /\ UNCHANGED <<sourceVersion, transfer, captured, published, outputFuture, consumer>>

AllReady == \A o \in Outputs : transfer[o] = "ready"
AllCurrent == \A o \in Outputs : captured[o] = sourceVersion

Publish(o) ==
    /\ o \in Outputs
    /\ transfer[o] = "ready"
    /\ IF USE_FIXED
          THEN /\ app = "succeeded" /\ AllReady /\ AllCurrent
               /\ published' = [x \in Outputs |-> sourceVersion]
               /\ outputFuture' = [x \in Outputs |-> "ready"]
          ELSE /\ published' = [published EXCEPT ![o] = sourceVersion]
               /\ outputFuture' = [outputFuture EXCEPT ![o] = "ready"]
    /\ UNCHANGED <<app, sourceVersion, transfer, captured, consumer>>

RunConsumer(o) ==
    /\ o \in Outputs
    /\ outputFuture[o] = "ready"
    /\ consumer' = [consumer EXCEPT ![o] = "running"]
    /\ UNCHANGED <<app, sourceVersion, transfer, captured, published, outputFuture>>

Next ==
    \/ Begin
    \/ ModifySource
    \/ \E o \in Outputs : CompleteTransfer(o) \/ FailTransfer(o) \/ RetryTransfer(o)
    \/ CompleteApp
    \/ \E o \in Outputs : Publish(o) \/ RunConsumer(o)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ app \in {"running", "succeeded"}
    /\ sourceVersion \in 0..1
    /\ transfer \in [Outputs -> {"idle", "sending", "ready", "failed"}]
    /\ captured \in [Outputs -> (-1)..1]
    /\ published \in [Outputs -> (-1)..1]
    /\ outputFuture \in [Outputs -> {"unresolved", "ready"}]
    /\ consumer \in [Outputs -> {"waiting", "running"}]

PublicationSafety ==
    \A o \in Outputs : outputFuture[o] = "ready" =>
        /\ app = "succeeded"
        /\ published[o] = sourceVersion
        /\ transfer[o] = "ready"

AtomicOutputSafety ==
    (\E o \in Outputs : outputFuture[o] = "ready")
        => \A o \in Outputs : outputFuture[o] = "ready"

ConsumerSafety ==
    \A o \in Outputs : consumer[o] = "running" => outputFuture[o] = "ready"

=============================================================================
