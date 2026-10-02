----------------------- MODULE ParslHtexFerryResultSendFailure -----------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX Manager.ferry_result result ownership across a ZMQ send failure.
 * get_result removes a result from the scheduler; the Current exception
 * handler logs the send failure but does not requeue or terminalize it.
 ***************************************************************************
 *)

CONSTANT USE_FIXED
ResultStates == {"queued", "consumed", "forwarded", "lost"}
SendStates == {"not_sent", "failed", "sent"}

VARIABLES result, send, retry
vars == <<result, send, retry>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ result = "queued"
    /\ send = "not_sent"
    /\ retry = 0

GetResult ==
    /\ result = "queued"
    /\ result' = "consumed"
    /\ UNCHANGED <<send, retry>>

SendFails ==
    /\ result = "consumed"
    /\ send = "not_sent"
    /\ send' = "failed"
    /\ result' = IF USE_FIXED THEN "queued" ELSE "lost"
    /\ retry' = IF USE_FIXED THEN retry + 1 ELSE retry

RetrySend ==
    /\ USE_FIXED
    /\ result = "queued"
    /\ send = "failed"
    /\ result' = "forwarded"
    /\ send' = "sent"
    /\ UNCHANGED retry

SendSucceeds ==
    /\ result = "consumed"
    /\ send = "not_sent"
    /\ result' = "forwarded"
    /\ send' = "sent"
    /\ UNCHANGED retry

Next == GetResult \/ SendFails \/ RetrySend \/ SendSucceeds \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ result \in ResultStates
    /\ send \in SendStates
    /\ retry \in Nat

NoLostResult == result # "lost"
ForwardingTerminal == result = "forwarded" => send = "sent"

========================================================================================
