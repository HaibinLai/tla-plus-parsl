--------------------------- MODULE ParslHtexWorkerTaskFrameContinuation ---------------------------
EXTENDS Naturals, Sequences

(***************************************************************************
 * Manager-side worker task receiver.  A task socket can deliver a corrupt
 * outer pickle frame before a valid task batch.  The current communicator
 * lets the decode exception escape and stops receiving tasks.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES state, remaining, accepted
vars == <<state, remaining, accepted>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "receiving"
    /\ remaining = <<"corrupt-pickle", "valid-task-batch">>
    /\ accepted = 0

ReceiveHead ==
    /\ Len(remaining) > 0
    /\ IF Head(remaining) = "corrupt-pickle"
          THEN IF USE_FIXED
               THEN /\ state' = "receiving"
                    /\ remaining' = Tail(remaining)
                    /\ UNCHANGED accepted
               ELSE /\ state' = "failed"
                    /\ UNCHANGED <<remaining, accepted>>
          ELSE /\ Head(remaining) = "valid-task-batch"
               /\ state' = "done"
               /\ remaining' = Tail(remaining)
               /\ accepted' = accepted + 1

Next ==
    \/ ReceiveHead
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"receiving", "failed", "done"}
    /\ remaining \in Seq({"corrupt-pickle", "valid-task-batch"})
    /\ accepted \in 0..1

NoCommunicatorAbort == state # "failed"
FixedAcceptsLaterBatch == USE_FIXED => (state = "done" => accepted = 1)

=============================================================================
