--------------------------- MODULE ParslMonitoringHubStartFailureCleanup ---------------------------
EXTENDS Naturals

(***************************************************************************
 * MonitoringHub startup failure cleanup.
 *
 * `start` allocates the queue/process and marks the hub active before the
 * child process is started. If process startup raises, the current path
 * leaves the hub active with allocated resources. The fixed path rolls back
 * startup state before propagating the failure.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES state, active, queueAllocated, processStarted, cleanupCount, outcome
vars == <<state, active, queueAllocated, processStarted, cleanupCount, outcome>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "new"
    /\ active = FALSE
    /\ queueAllocated = FALSE
    /\ processStarted = FALSE
    /\ cleanupCount = 0
    /\ outcome = "none"

BeginStart ==
    /\ state = "new"
    /\ state' = "starting"
    /\ active' = TRUE
    /\ queueAllocated' = TRUE
    /\ UNCHANGED <<processStarted, cleanupCount, outcome>>

StartFails ==
    /\ state = "starting"
    /\ state' = "failed"
    /\ outcome' = "propagated"
    /\ IF USE_FIXED
       THEN /\ active' = FALSE
            /\ queueAllocated' = FALSE
            /\ cleanupCount' = 1
       ELSE /\ active' = active
            /\ queueAllocated' = queueAllocated
            /\ cleanupCount' = cleanupCount
    /\ UNCHANGED processStarted

StartSucceeds ==
    /\ state = "starting"
    /\ state' = "active"
    /\ processStarted' = TRUE
    /\ outcome' = "none"
    /\ UNCHANGED <<active, queueAllocated, cleanupCount>>

CloseAfterFailure ==
    /\ state = "failed"
    /\ state' = "closed"
    /\ active' = FALSE
    /\ queueAllocated' = FALSE
    /\ UNCHANGED <<processStarted, cleanupCount, outcome>>

Next ==
    \/ BeginStart
    \/ StartFails
    \/ StartSucceeds
    \/ CloseAfterFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"new", "starting", "active", "failed", "closed"}
    /\ active \in BOOLEAN
    /\ queueAllocated \in BOOLEAN
    /\ processStarted \in BOOLEAN
    /\ cleanupCount \in 0..1
    /\ outcome \in {"none", "propagated"}

StartupFailureCleanup ==
    state = "failed" =>
        /\ ~active
        /\ ~queueAllocated
        /\ cleanupCount = 1
        /\ ~processStarted

=============================================================================
