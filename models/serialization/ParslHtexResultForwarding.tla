--------------------------- MODULE ParslHtexResultForwarding ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX manager result forwarding and task ownership.
 *
 * process_manager_socket_message removes a task ID from the manager record
 * before sending the serialized result to the executor.  A send failure must
 * not silently lose that ownership record: the task must remain recoverable
 * or the result must already be confirmed forwarded.
 ***************************************************************************)

CONSTANT USE_FIXED

SendStates == {"not_attempted", "failed", "succeeded"}

VARIABLES decoded, taskOwned, sendState, forwarded, managerAlive
vars == <<decoded, taskOwned, sendState, forwarded, managerAlive>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ decoded = FALSE
    /\ taskOwned = TRUE
    /\ sendState = "not_attempted"
    /\ forwarded = FALSE
    /\ managerAlive = TRUE

DecodeResult ==
    /\ managerAlive
    /\ ~decoded
    /\ decoded' = TRUE
    /\ UNCHANGED <<taskOwned, sendState, forwarded, managerAlive>>

ForwardSuccess ==
    /\ managerAlive
    /\ decoded
    /\ sendState = "not_attempted"
    /\ taskOwned' = FALSE
    /\ sendState' = "succeeded"
    /\ forwarded' = TRUE
    /\ UNCHANGED <<decoded, managerAlive>>

ForwardFailure ==
    /\ managerAlive
    /\ decoded
    /\ sendState = "not_attempted"
    /\ sendState' = "failed"
    /\ IF USE_FIXED
          THEN /\ taskOwned' = TRUE
               /\ managerAlive' = TRUE
          ELSE /\ taskOwned' = FALSE
               /\ managerAlive' = FALSE
    /\ UNCHANGED <<decoded, forwarded>>

RetryForward ==
    /\ USE_FIXED
    /\ decoded
    /\ taskOwned
    /\ sendState = "failed"
    /\ managerAlive
    /\ taskOwned' = FALSE
    /\ sendState' = "succeeded"
    /\ forwarded' = TRUE
    /\ UNCHANGED <<decoded, managerAlive>>

Next ==
    \/ DecodeResult
    \/ ForwardSuccess
    \/ ForwardFailure
    \/ RetryForward
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ decoded \in BOOLEAN
    /\ taskOwned \in BOOLEAN
    /\ sendState \in SendStates
    /\ forwarded \in BOOLEAN
    /\ managerAlive \in BOOLEAN

NoTaskLoss ==
    sendState = "failed" => taskOwned \/ forwarded

ForwardingConsistency ==
    forwarded => /\ sendState = "succeeded"
                 /\ ~taskOwned

RetryOwnership ==
    sendState = "failed" /\ USE_FIXED => taskOwned

=============================================================================
SPECIFICATION Spec

INVARIANTS
    TypeOK
    NoTaskLoss
    ForwardingConsistency
    RetryOwnership
