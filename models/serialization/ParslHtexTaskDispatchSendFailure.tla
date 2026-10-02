--------------------------- MODULE ParslHtexTaskDispatchSendFailure ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX task-dispatch ownership across a ZMQ send failure.
 *
 * Interchange.process_tasks_to_send removes a task from the pending queue
 * before manager_sock.send_multipart.  The Current branch loses ownership if
 * that send raises.  The Fixed branch retains/requeues the task so it can be
 * retried or explicitly terminalized.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES taskState, sendState, owner
vars == <<taskState, sendState, owner>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ taskState = "queued"
    /\ sendState = "ready"
    /\ owner = "queue"

TakeTask ==
    /\ taskState = "queued"
    /\ owner = "queue"
    /\ taskState' = "inflight"
    /\ owner' = "sender"
    /\ UNCHANGED sendState

SendSuccess ==
    /\ taskState = "inflight"
    /\ owner = "sender"
    /\ taskState' = "delivered"
    /\ sendState' = "sent"
    /\ owner' = "none"

SendFailure ==
    /\ taskState = "inflight"
    /\ owner = "sender"
    /\ IF USE_FIXED
          THEN /\ taskState' = "queued"
               /\ sendState' = "ready"
               /\ owner' = "queue"
          ELSE /\ taskState' = "lost"
               /\ sendState' = "failed"
               /\ owner' = "none"

Next ==
    \/ TakeTask
    \/ SendSuccess
    \/ SendFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ taskState \in {"queued", "inflight", "delivered", "lost"}
    /\ sendState \in {"ready", "sent", "failed"}
    /\ owner \in {"queue", "sender", "none"}

NoTaskLoss == taskState # "lost"

OwnershipConsistency ==
    /\ taskState = "queued" => owner = "queue"
    /\ taskState = "inflight" => owner = "sender"
    /\ taskState \in {"delivered", "lost"} => owner = "none"

=============================================================================
