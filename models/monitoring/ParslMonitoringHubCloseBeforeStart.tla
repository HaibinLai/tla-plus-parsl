--------------------------- MODULE ParslMonitoringHubCloseBeforeStart ---------------------------
EXTENDS Naturals

(***************************************************************************
 * MonitoringHub cleanup before startup.
 *
 * MonitoringHub.start creates the active-state attribute, but the
 * constructor does not initialize it. A cleanup path that calls close before
 * start therefore reads missing state in the current implementation. The
 * fixed path treats an unstarted hub as an already-closed no-op.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES started, active, closed, outcome, cleanupCount
vars == <<started, active, closed, outcome, cleanupCount>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ started = FALSE
    /\ active = FALSE
    /\ closed = FALSE
    /\ outcome = "ok"
    /\ cleanupCount = 0

Start ==
    /\ ~started
    /\ started' = TRUE
    /\ active' = TRUE
    /\ UNCHANGED <<closed, outcome, cleanupCount>>

Close ==
    /\ IF ~started
          THEN IF USE_FIXED
               THEN /\ started' = started
                    /\ active' = active
                    /\ closed' = TRUE
                    /\ outcome' = "ok"
                    /\ cleanupCount' = cleanupCount
               ELSE /\ started' = started
                    /\ active' = active
                    /\ closed' = closed
                    /\ outcome' = "crashed"
                    /\ cleanupCount' = cleanupCount
          ELSE IF active
               THEN /\ started' = started
                    /\ active' = FALSE
                    /\ closed' = TRUE
                    /\ outcome' = "ok"
                    /\ cleanupCount' = cleanupCount + 1
               ELSE /\ UNCHANGED vars

Next == Start \/ Close \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ started \in BOOLEAN
    /\ active \in BOOLEAN
    /\ closed \in BOOLEAN
    /\ outcome \in {"ok", "crashed"}
    /\ cleanupCount \in 0..1

NoCloseCrash == outcome = "ok"

CloseIdempotence == cleanupCount <= 1

=============================================================================
