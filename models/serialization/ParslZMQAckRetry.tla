--------------------------- MODULE ParslZMQAckRetry ---------------------------
EXTENDS Naturals

(***************************************************************************
 * A compact multipart-message ACK/retry model.
 *
 * One logical task is encoded and sent over a bounded ZMQ-like path.  If the
 * acknowledgement is delayed, the sender may retransmit the same envelope.
 * The current branch dispatches the duplicate twice; the fixed branch keeps
 * the envelope identity in a receive-side seen set and dispatches once.
 ***************************************************************************)

CONSTANT USE_FIXED

WireStates == {"none", "encoded"}
TaskStates == {"pending", "running", "succeeded"}

VARIABLES wire, sendCount, outstanding, delivered, consumed, dispatchCount,
          acknowledged, task, future

vars == <<wire, sendCount, outstanding, delivered, consumed, dispatchCount,
           acknowledged, task, future>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ wire = "none"
    /\ sendCount = 0
    /\ outstanding = 0
    /\ delivered = 0
    /\ consumed = 0
    /\ dispatchCount = 0
    /\ acknowledged = FALSE
    /\ task = "pending"
    /\ future = "unresolved"

Encode ==
    /\ wire = "none"
    /\ task \in {"pending", "running"}
    /\ wire' = "encoded"
    /\ UNCHANGED <<sendCount, outstanding, delivered, consumed,
                    dispatchCount, acknowledged, task, future>>

Send ==
    /\ wire = "encoded"
    /\ sendCount < 2
    /\ wire' = "none"
    /\ sendCount' = sendCount + 1
    /\ outstanding' = outstanding + 1
    /\ UNCHANGED <<delivered, consumed, dispatchCount, acknowledged,
                    task, future>>

Receive ==
    /\ outstanding > 0
    /\ delivered < 2
    /\ outstanding' = outstanding - 1
    /\ delivered' = delivered + 1
    /\ UNCHANGED <<wire, sendCount, consumed, dispatchCount,
                    acknowledged, task, future>>

DispatchFirst ==
    /\ delivered > consumed
    /\ consumed = 0
    /\ consumed' = 1
    /\ dispatchCount' = 1
    /\ task' = "running"
    /\ UNCHANGED <<wire, sendCount, outstanding, delivered,
                    acknowledged, future>>

ReencodeAfterMissingAck ==
    /\ task = "running"
    /\ ~acknowledged
    /\ sendCount = 1
    /\ wire = "none"
    /\ wire' = "encoded"
    /\ UNCHANGED <<sendCount, outstanding, delivered, consumed,
                    dispatchCount, acknowledged, task, future>>

DispatchDuplicate ==
    /\ delivered > consumed
    /\ consumed = 1
    /\ consumed' = 2
    /\ dispatchCount' = IF USE_FIXED THEN dispatchCount ELSE dispatchCount + 1
    /\ UNCHANGED <<wire, sendCount, outstanding, delivered,
                    acknowledged, task, future>>

Complete ==
    /\ task = "running"
    /\ consumed >= 1
    /\ task' = "succeeded"
    /\ future' = "resolved"
    /\ acknowledged' = TRUE
    /\ UNCHANGED <<wire, sendCount, outstanding, delivered, consumed,
                    dispatchCount>>

Next ==
    \/ Encode
    \/ Send
    \/ Receive
    \/ DispatchFirst
    \/ ReencodeAfterMissingAck
    \/ DispatchDuplicate
    \/ Complete
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ wire \in WireStates
    /\ sendCount \in 0..2
    /\ outstanding \in 0..2
    /\ delivered \in 0..2
    /\ consumed \in 0..2
    /\ dispatchCount \in 0..2
    /\ acknowledged \in BOOLEAN
    /\ task \in TaskStates
    /\ future \in {"unresolved", "resolved"}

SingleDispatch == dispatchCount <= 1

AckOnlyAfterCompletion == acknowledged => task = "succeeded"

FutureConsistency == future = "resolved" => task = "succeeded"

=============================================================================
