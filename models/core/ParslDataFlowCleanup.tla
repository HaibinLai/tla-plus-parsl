--------------------------- MODULE ParslDataFlowCleanup ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * DataFlowKernel.cleanup component lifecycle from parsl/dataflow/dflow.py.
 *
 * Cleanup marks the DFK before closing dependencies, then shuts down the job
 * status poller and executors, and finally closes monitoring.  A second call
 * is rejected without repeating component shutdown.
 ***************************************************************************)

Components == {"memoizer", "usage", "poller", "executors", "monitoring", "task-launch-pool"}
Order == <<"memoizer", "usage", "poller", "executors", "monitoring", "task-launch-pool">>
States == {"open", "cleaning", "closed", "rejected"}

VARIABLES state, cleanupCalled, closed, events
vars == <<state, cleanupCalled, closed, events>>

Init ==
    /\ state = "open"
    /\ cleanupCalled = FALSE
    /\ closed = {}
    /\ events = <<>>

BeginCleanup ==
    /\ state = "open"
    /\ ~cleanupCalled
    /\ state' = "cleaning"
    /\ cleanupCalled' = TRUE
    /\ UNCHANGED <<closed, events>>

CloseNext ==
    /\ state = "cleaning"
    /\ Cardinality(closed) < Len(Order)
    /\ LET component == Order[Cardinality(closed) + 1] IN
        /\ closed' = closed \cup {component}
        /\ events' = Append(events, component)
    /\ UNCHANGED <<state, cleanupCalled>>

FinishCleanup ==
    /\ state = "cleaning"
    /\ closed = Components
    /\ state' = "closed"
    /\ UNCHANGED <<cleanupCalled, closed, events>>

RejectSecondCleanup ==
    /\ cleanupCalled
    /\ state \in {"cleaning", "closed"}
    /\ state' = "rejected"
    /\ UNCHANGED <<cleanupCalled, closed, events>>

Next ==
    \/ BeginCleanup
    \/ CloseNext
    \/ FinishCleanup
    \/ RejectSecondCleanup
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ cleanupCalled \in BOOLEAN
    /\ closed \subseteq Components
    /\ events \in Seq(Components)

CleanupOrderSafety ==
    state \in {"cleaning", "closed"} =>
        \A i, j \in 1..Len(events) : i < j =>
            \E x, y \in 1..Len(Order) : events[i] = Order[x] /\ events[j] = Order[y] /\ x < y

CleanupCompleteness == state = "closed" => closed = Components

RepeatCleanupSafety == state = "rejected" => cleanupCalled /\ closed \subseteq Components

=============================================================================
