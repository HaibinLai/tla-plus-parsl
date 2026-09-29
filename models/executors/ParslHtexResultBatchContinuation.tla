--------------------------- MODULE ParslHtexResultBatchContinuation ---------------------------
EXTENDS Naturals, Sequences

(***************************************************************************
 * A bounded refinement of the HTEX manager result batch.
 *
 * The batch deliberately contains one malformed pickle followed by one valid
 * result.  The current implementation lets the malformed decode escape the
 * loop.  The candidate fixed path discards that frame and continues to the
 * valid result, preserving batch progress for unrelated tasks.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES state, remaining, forwarded
vars == <<state, remaining, forwarded>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "processing"
    /\ remaining = <<"malformed", "valid">>
    /\ forwarded = 0

DecodeHead ==
    /\ Len(remaining) > 0
    /\ Head(remaining) = "malformed"
    /\ IF USE_FIXED
          THEN /\ state' = "processing"
               /\ remaining' = Tail(remaining)
               /\ forwarded' = forwarded
          ELSE /\ state' = "failed"
               /\ UNCHANGED <<remaining, forwarded>>

ForwardValid ==
    /\ state = "processing"
    /\ Len(remaining) > 0
    /\ Head(remaining) = "valid"
    /\ state' = "done"
    /\ remaining' = Tail(remaining)
    /\ forwarded' = forwarded + 1

Next ==
    \/ DecodeHead
    \/ ForwardValid
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"processing", "failed", "done"}
    /\ remaining \in Seq({"malformed", "valid"})
    /\ forwarded \in 0..1

NoBatchAbort ==
    state # "failed"

FixedForwardsValidResult ==
    USE_FIXED => (state = "done" => forwarded = 1)

=============================================================================
