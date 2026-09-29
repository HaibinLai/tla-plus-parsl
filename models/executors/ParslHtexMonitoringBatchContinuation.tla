--------------------------- MODULE ParslHtexMonitoringBatchContinuation ---------------------------
EXTENDS Naturals, Sequences

(***************************************************************************
 * A bounded HTEX result batch with an optional monitoring frame followed by
 * a valid task result.  When monitoring is disabled, the current source uses
 * an assertion instead of isolating the optional frame, aborting the batch.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES state, remaining, forwarded
vars == <<state, remaining, forwarded>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "processing"
    /\ remaining = <<"monitoring", "valid">>
    /\ forwarded = 0

HandleHead ==
    /\ Len(remaining) > 0
    /\ IF Head(remaining) = "monitoring"
          THEN IF USE_FIXED
               THEN /\ state' = "processing"
                    /\ remaining' = Tail(remaining)
                    /\ forwarded' = forwarded
               ELSE /\ state' = "failed"
                    /\ UNCHANGED <<remaining, forwarded>>
          ELSE /\ Head(remaining) = "valid"
               /\ state' = "done"
               /\ remaining' = Tail(remaining)
               /\ forwarded' = forwarded + 1

Next ==
    \/ HandleHead
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"processing", "failed", "done"}
    /\ remaining \in Seq({"monitoring", "valid"})
    /\ forwarded \in 0..1

NoBatchAbort == state # "failed"
FixedForwardsValidResult ==
    USE_FIXED => (state = "done" => forwarded = 1)

=============================================================================
