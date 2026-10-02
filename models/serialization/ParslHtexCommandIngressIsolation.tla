--------------------------- MODULE ParslHtexCommandIngressIsolation ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX interchange command-channel isolation.
 *
 * process_command calls command_channel.recv_pyobj directly.  The Current
 * branch lets a malformed command frame escape the interchange loop.  The
 * Fixed branch discards the malformed command and keeps the loop available
 * for later task/result processing.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES interchangeState, commandState, laterWorkState
vars == <<interchangeState, commandState, laterWorkState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ interchangeState = "alive"
    /\ commandState = "pending"
    /\ laterWorkState = "pending"

ReceiveMalformedCommand ==
    /\ interchangeState = "alive"
    /\ commandState = "pending"
    /\ IF USE_FIXED
          THEN /\ commandState' = "discarded"
               /\ UNCHANGED <<interchangeState, laterWorkState>>
          ELSE /\ interchangeState' = "crashed"
               /\ UNCHANGED <<commandState, laterWorkState>>

ProcessLaterWork ==
    /\ interchangeState = "alive"
    /\ commandState = "discarded"
    /\ laterWorkState' = "processed"
    /\ UNCHANGED <<interchangeState, commandState>>

Next ==
    \/ ReceiveMalformedCommand
    \/ ProcessLaterWork
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ interchangeState \in {"alive", "crashed"}
    /\ commandState \in {"pending", "discarded"}
    /\ laterWorkState \in {"pending", "processed"}

InterchangeSurvives == interchangeState = "alive"

LaterWorkAvailable ==
    laterWorkState = "processed" => interchangeState = "alive"

=============================================================================
