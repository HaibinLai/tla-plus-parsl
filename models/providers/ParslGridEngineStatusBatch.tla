--------------------------- MODULE ParslGridEngineStatusBatch ---------------------------
EXTENDS Naturals, Sequences

(***************************************************************************
 * Grid Engine qstat status batch with a malformed record followed by a
 * valid record.  The current parser indexes parts[4] before checking the
 * record shape, aborting the entire polling pass.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES state, remaining, knownStatus
vars == <<state, remaining, knownStatus>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "polling"
    /\ remaining = <<"malformed", "valid">>
    /\ knownStatus = "pending"

ProcessHead ==
    /\ Len(remaining) > 0
    /\ IF Head(remaining) = "malformed"
          THEN IF USE_FIXED
               THEN /\ state' = "polling"
                    /\ remaining' = Tail(remaining)
                    /\ UNCHANGED knownStatus
               ELSE /\ state' = "failed"
                    /\ UNCHANGED <<remaining, knownStatus>>
          ELSE /\ Head(remaining) = "valid"
               /\ state' = "done"
               /\ remaining' = Tail(remaining)
               /\ knownStatus' = "running"

Next ==
    \/ ProcessHead
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"polling", "failed", "done"}
    /\ remaining \in Seq({"malformed", "valid"})
    /\ knownStatus \in {"pending", "running"}

NoPollAbort == state # "failed"
FixedUpdatesKnownJob == USE_FIXED => (state = "done" => knownStatus = "running")

=============================================================================
