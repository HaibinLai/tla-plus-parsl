--------------------------- MODULE ParslHtexExecutorResultFrameContinuation ---------------------------
EXTENDS Naturals, Sequences

(***************************************************************************
 * Executor-side result queue handling.  A corrupt outer pickle frame is
 * followed by a valid result for another task.  The current worker lets the
 * pickle exception escape the loop; the candidate fixed path discards the
 * bad frame and continues.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES state, remaining, resolved
vars == <<state, remaining, resolved>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "processing"
    /\ remaining = <<"corrupt-pickle", "valid-result">>
    /\ resolved = 0

DecodeHead ==
    /\ Len(remaining) > 0
    /\ IF Head(remaining) = "corrupt-pickle"
          THEN IF USE_FIXED
               THEN /\ state' = "processing"
                    /\ remaining' = Tail(remaining)
                    /\ UNCHANGED resolved
               ELSE /\ state' = "failed"
                    /\ UNCHANGED <<remaining, resolved>>
          ELSE /\ Head(remaining) = "valid-result"
               /\ state' = "done"
               /\ remaining' = Tail(remaining)
               /\ resolved' = resolved + 1

Next ==
    \/ DecodeHead
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"processing", "failed", "done"}
    /\ remaining \in Seq({"corrupt-pickle", "valid-result"})
    /\ resolved \in 0..1

NoWorkerAbort == state # "failed"
FixedResolvesLaterResult == USE_FIXED => (state = "done" => resolved = 1)

=============================================================================
