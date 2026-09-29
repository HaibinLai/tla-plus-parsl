--------------------------- MODULE ParslHtexWorkerTaskBatchShape ---------------------------
EXTENDS Naturals, Sequences

(***************************************************************************
 * A valid outer pickle can still contain an invalid task-batch shape.  The
 * current worker assumes an iterable list of task dictionaries and lets a
 * shape/field error escape the communicator loop.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES state, remaining, accepted
vars == <<state, remaining, accepted>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "receiving"
    /\ remaining = <<"malformed-shape", "valid-list">>
    /\ accepted = 0

HandleHead ==
    /\ Len(remaining) > 0
    /\ IF Head(remaining) = "malformed-shape"
          THEN IF USE_FIXED
               THEN /\ state' = "receiving"
                    /\ remaining' = Tail(remaining)
                    /\ UNCHANGED accepted
               ELSE /\ state' = "failed"
                    /\ UNCHANGED <<remaining, accepted>>
          ELSE /\ Head(remaining) = "valid-list"
               /\ state' = "done"
               /\ remaining' = Tail(remaining)
               /\ accepted' = accepted + 1

Next ==
    \/ HandleHead
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"receiving", "failed", "done"}
    /\ remaining \in Seq({"malformed-shape", "valid-list"})
    /\ accepted \in 0..1

NoShapeAbort == state # "failed"
FixedAcceptsValidList == USE_FIXED => (state = "done" => accepted = 1)

=============================================================================
