--------------------------- MODULE ParslGridEngineStatus ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Grid Engine qstat status parsing.
 *
 * GridEngineProvider._status reads parts[4] for every non-header line.  A
 * truncated scheduler line can therefore raise before status bookkeeping;
 * the fixed configuration skips malformed lines and preserves the prior state.
 ***************************************************************************)

CONSTANTS MALFORMED_LINE, USE_FIXED

States == {"idle", "polling", "updated", "crashed"}

VARIABLES state, knownJobStatus, malformedIgnored
vars == <<state, knownJobStatus, malformedIgnored>>

Init ==
    /\ MALFORMED_LINE \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "idle"
    /\ knownJobStatus = "running"
    /\ malformedIgnored = FALSE

BeginPoll ==
    /\ state = "idle"
    /\ state' = "polling"
    /\ UNCHANGED <<knownJobStatus, malformedIgnored>>

MalformedLineCrashes ==
    /\ state = "polling"
    /\ MALFORMED_LINE
    /\ ~USE_FIXED
    /\ state' = "crashed"
    /\ UNCHANGED <<knownJobStatus, malformedIgnored>>

MalformedLineIgnored ==
    /\ state = "polling"
    /\ MALFORMED_LINE
    /\ USE_FIXED
    /\ state' = "updated"
    /\ malformedIgnored' = TRUE
    /\ UNCHANGED knownJobStatus

ValidLineUpdates ==
    /\ state = "polling"
    /\ ~MALFORMED_LINE
    /\ state' = "updated"
    /\ knownJobStatus' = "running"
    /\ UNCHANGED malformedIgnored

Next ==
    \/ BeginPoll
    \/ MalformedLineCrashes
    \/ MalformedLineIgnored
    \/ ValidLineUpdates
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ knownJobStatus = "running"
    /\ malformedIgnored \in BOOLEAN

PollingSafety == state # "crashed"

MalformedHandling ==
    MALFORMED_LINE => (state = "updated" => malformedIgnored)

=============================================================================
