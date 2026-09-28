--------------------------- MODULE ParslCondorStatus ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTCondor status-output parsing.
 *
 * CondorProvider._status splits every output line and immediately reads
 * parts[0] and parts[1].  A malformed/truncated scheduler line therefore
 * raises before the provider can preserve the previous resource status.
 * The fixed configuration skips lines that do not contain two fields.
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
    /\ knownJobStatus' = "completed"
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
    /\ knownJobStatus \in {"running", "completed"}
    /\ malformedIgnored \in BOOLEAN

PollingSafety == state # "crashed"

MalformedHandling ==
    MALFORMED_LINE => (state = "updated" => malformedIgnored)

=============================================================================
