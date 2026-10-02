--------------------------- MODULE ParslDataReadyStageOutFailure ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Cross-layer stage-out/data-readiness boundary.
 *
 * A consumer may run only after the logical application succeeded, the
 * physical transfer published every bounded chunk, and the DataFuture became
 * ready.  The Current branch permits an independent transfer to publish
 * after application failure; the Fixed branch keeps the failure terminal.
 ***************************************************************************)

CONSTANT USE_FIXED, CHUNKS

AppStates == {"pending", "succeeded", "failed"}
TransferStates == {"idle", "running", "succeeded", "failed"}
OutputStates == {"blocked", "ready", "failed"}
ConsumerStates == {"blocked", "running"}

VARIABLES app, received, transfer, output, consumer
vars == <<app, received, transfer, output, consumer>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ CHUNKS = 2
    /\ app = "pending"
    /\ received = 0
    /\ transfer = "idle"
    /\ output = "blocked"
    /\ consumer = "blocked"

AppSuccess ==
    /\ app = "pending"
    /\ app' = "succeeded"
    /\ UNCHANGED <<received, transfer, output, consumer>>

AppFailure ==
    /\ app = "pending"
    /\ app' = "failed"
    /\ UNCHANGED <<received, transfer, output, consumer>>

StartTransfer ==
    /\ transfer = "idle"
    /\ IF USE_FIXED
          THEN app = "succeeded"
          ELSE app \in {"succeeded", "failed"}
    /\ transfer' = "running"
    /\ UNCHANGED <<app, received, output, consumer>>

ReceiveChunk ==
    /\ transfer = "running"
    /\ received < CHUNKS
    /\ received' = received + 1
    /\ UNCHANGED <<app, transfer, output, consumer>>

FinishTransfer ==
    /\ transfer = "running"
    /\ received = CHUNKS
    /\ IF USE_FIXED
          THEN transfer' = "succeeded"
          ELSE transfer' = "succeeded"
    /\ UNCHANGED <<app, received, output, consumer>>

Publish ==
    /\ transfer = "succeeded"
    /\ output = "blocked"
    /\ output' = "ready"
    /\ UNCHANGED <<app, received, transfer, consumer>>

RunConsumer ==
    /\ output = "ready"
    /\ consumer = "blocked"
    /\ consumer' = "running"
    /\ UNCHANGED <<app, received, transfer, output>>

Next == AppSuccess \/ AppFailure \/ StartTransfer \/ ReceiveChunk \/ FinishTransfer \/ Publish \/ RunConsumer \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ CHUNKS = 2
    /\ app \in AppStates
    /\ received \in 0..CHUNKS
    /\ transfer \in TransferStates
    /\ output \in OutputStates
    /\ consumer \in ConsumerStates

ConsumerSafety == consumer = "running" =>
    /\ app = "succeeded"
    /\ received = CHUNKS
    /\ output = "ready"

=============================================================================
