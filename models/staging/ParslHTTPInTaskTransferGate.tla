--------------------------- MODULE ParslHTTPInTaskTransferGate ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * HTTP in-task staging: response validation, streamed bytes, publication,
 * and user-function admission are one protocol.  The current implementation
 * writes directly to the final path and invokes the wrapped function without
 * checking HTTP status.  The fixed branch stages into a temporary buffer,
 * validates the response, and publishes before admitting the task.
 ***************************************************************************)

CONSTANTS CHUNKS, STATUS_OK, STREAM_OK, USE_FIXED

TransferStates == {"idle", "receiving", "succeeded", "failed"}
PublicationStates == {"none", "temp", "final"}
TaskStates == {"waiting", "ran", "blocked"}

VARIABLES transfer, received, tempBytes, finalBytes, publication, task
vars == <<transfer, received, tempBytes, finalBytes, publication, task>>

Init ==
    /\ CHUNKS # {}
    /\ STATUS_OK \in BOOLEAN
    /\ STREAM_OK \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ transfer = "idle"
    /\ received = {}
    /\ tempBytes = 0
    /\ finalBytes = 0
    /\ publication = "none"
    /\ task = "waiting"

StartTransfer ==
    /\ transfer = "idle"
    /\ transfer' = "receiving"
    /\ UNCHANGED <<received, tempBytes, finalBytes, publication, task>>

ReceiveChunk(c) ==
    /\ transfer = "receiving"
    /\ c \in CHUNKS
    /\ c \notin received
    /\ received' = received \cup {c}
    /\ IF USE_FIXED
          THEN /\ tempBytes' = tempBytes + 1
               /\ UNCHANGED finalBytes
          ELSE /\ finalBytes' = finalBytes + 1
               /\ UNCHANGED tempBytes
    /\ UNCHANGED <<transfer, publication, task>>

FailTransfer ==
    /\ transfer = "receiving"
    /\ ~STREAM_OK
    /\ transfer' = "failed"
    /\ IF USE_FIXED
          THEN /\ tempBytes' = 0
               /\ UNCHANGED finalBytes
          ELSE UNCHANGED <<tempBytes, finalBytes>>
    /\ UNCHANGED <<received, publication, task>>

CompleteTransfer ==
    /\ transfer = "receiving"
    /\ STREAM_OK
    /\ received = CHUNKS
    /\ transfer' = "succeeded"
    /\ IF USE_FIXED
          THEN /\ publication' = IF STATUS_OK THEN "final" ELSE "none"
               /\ finalBytes' = IF STATUS_OK THEN tempBytes ELSE 0
          ELSE /\ publication' = "final"
               /\ finalBytes' = Cardinality(CHUNKS)
    /\ UNCHANGED <<received, tempBytes, task>>

AdmitTask ==
    /\ task = "waiting"
    /\ IF USE_FIXED
          THEN /\ transfer = "succeeded"
               /\ STATUS_OK
               /\ publication = "final"
          ELSE /\ transfer = "succeeded"
    /\ task' = "ran"
    /\ UNCHANGED <<transfer, received, tempBytes, finalBytes, publication>>

RejectTask ==
    /\ task = "waiting"
    /\ transfer = "failed" \/ (USE_FIXED /\ transfer = "succeeded" /\ ~STATUS_OK)
    /\ task' = "blocked"
    /\ UNCHANGED <<transfer, received, tempBytes, finalBytes, publication>>

Next ==
    \/ StartTransfer
    \/ \E c \in CHUNKS : ReceiveChunk(c)
    \/ FailTransfer
    \/ CompleteTransfer
    \/ AdmitTask
    \/ RejectTask
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ transfer \in TransferStates
    /\ received \subseteq CHUNKS
    /\ tempBytes \in Nat
    /\ finalBytes \in Nat
    /\ publication \in PublicationStates
    /\ task \in TaskStates

TaskRequiresValidHTTP ==
    task = "ran" => /\ transfer = "succeeded"
                         /\ STATUS_OK
                         /\ publication = "final"
                         /\ finalBytes = Cardinality(CHUNKS)

NoPartialFinalPublication ==
    USE_FIXED => (publication = "final" =>
        /\ transfer = "succeeded"
        /\ STATUS_OK
        /\ finalBytes = Cardinality(CHUNKS))

=============================================================================
SPECIFICATION Spec

INVARIANTS
    TypeOK
    TaskRequiresValidHTTP
    NoPartialFinalPublication
