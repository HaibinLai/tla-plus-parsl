--------------------------- MODULE ParslHtexCommandReplySendFailure ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX interchange command-reply send failure.
 *
 * The Current branch lets an exception from command_channel.send_pyobj escape
 * the interchange loop after a valid command has been handled.  The Fixed
 * branch isolates the disconnected client and keeps the loop alive for later
 * task/result processing.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES interchangeState, commandState, laterWorkState
vars == <<interchangeState, commandState, laterWorkState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ interchangeState = "alive"
    /\ commandState = "reply_pending"
    /\ laterWorkState = "pending"

ReplySendFailure ==
    /\ interchangeState = "alive"
    /\ commandState = "reply_pending"
    /\ IF USE_FIXED
          THEN /\ interchangeState' = "alive"
               /\ commandState' = "reply_dropped"
               /\ UNCHANGED laterWorkState
          ELSE /\ interchangeState' = "crashed"
               /\ UNCHANGED <<commandState, laterWorkState>>

ProcessLaterWork ==
    /\ interchangeState = "alive"
    /\ commandState = "reply_dropped"
    /\ laterWorkState' = "processed"
    /\ UNCHANGED <<interchangeState, commandState>>

Next ==
    \/ ReplySendFailure
    \/ ProcessLaterWork
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ interchangeState \in {"alive", "crashed"}
    /\ commandState \in {"reply_pending", "reply_dropped"}
    /\ laterWorkState \in {"pending", "processed"}

InterchangeSurvives == interchangeState = "alive"

LaterWorkAvailable ==
    laterWorkState = "processed" => interchangeState = "alive"

=============================================================================
