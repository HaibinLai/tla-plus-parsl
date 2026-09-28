--------------------------- MODULE ParslTorqueStatus ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Torque qstat status parsing.
 *
 * TorqueProvider._status parses each non-header line and immediately indexes
 * self.resources[job_id].  Unlike LSFProvider, it does not first test whether
 * the id belongs to the requested resource set.  A foreign scheduler line is
 * therefore modeled as a polling crash; the fixed configuration ignores it.
 ***************************************************************************)

CONSTANTS FOREIGN_LINE, USE_FIXED

States == {"idle", "polling", "updated", "crashed"}

VARIABLES state, knownJobStatus, foreignIgnored
vars == <<state, knownJobStatus, foreignIgnored>>

Init ==
    /\ FOREIGN_LINE \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "idle"
    /\ knownJobStatus = "running"
    /\ foreignIgnored = FALSE

BeginPoll ==
    /\ state = "idle"
    /\ state' = "polling"
    /\ UNCHANGED <<knownJobStatus, foreignIgnored>>

ForeignLineCrashes ==
    /\ state = "polling"
    /\ FOREIGN_LINE
    /\ ~USE_FIXED
    /\ state' = "crashed"
    /\ UNCHANGED <<knownJobStatus, foreignIgnored>>

ForeignLineIgnored ==
    /\ state = "polling"
    /\ FOREIGN_LINE
    /\ USE_FIXED
    /\ state' = "updated"
    /\ foreignIgnored' = TRUE
    /\ UNCHANGED knownJobStatus

KnownLineUpdates ==
    /\ state = "polling"
    /\ ~FOREIGN_LINE
    /\ state' = "updated"
    /\ knownJobStatus' = "completed"
    /\ UNCHANGED foreignIgnored

Next ==
    \/ BeginPoll
    \/ ForeignLineCrashes
    \/ ForeignLineIgnored
    \/ KnownLineUpdates
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ knownJobStatus \in {"running", "completed"}
    /\ foreignIgnored \in BOOLEAN

PollingSafety == state # "crashed"

ForeignHandling ==
    FOREIGN_LINE => (state = "updated" => foreignIgnored)

=============================================================================
