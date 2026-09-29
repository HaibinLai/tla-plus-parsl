--------------------------- MODULE ParslMonitoringStatusHistory ---------------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * Append-only monitoring status history.
 *
 * Parsl stores each task status event as a row keyed by task/run/status/time;
 * it does not overwrite the previous status.  Delivery may be out of order,
 * so consumers must derive the current status from the greatest event version
 * rather than from insertion order.  Versions stand for event timestamps in
 * this bounded abstraction.
 ***************************************************************************)

CONSTANT MAX_VERSION
Statuses == {"running", "timed_out", "succeeded"}
Event == [version : 1..MAX_VERSION, status : Statuses]

StatusOf(v) ==
    IF v = 1 THEN "running"
    ELSE IF v = 2 THEN "timed_out" ELSE "succeeded"
EventOf(v) == [version |-> v, status |-> StatusOf(v)]
AllEvents == {EventOf(v) : v \in 1..MAX_VERSION}

VARIABLES emitted, queue, rows
vars == <<emitted, queue, rows>>

Init ==
    /\ MAX_VERSION = 3
    /\ emitted = {}
    /\ queue = <<>>
    /\ rows = {}

Emit(v) ==
    /\ v \in 1..MAX_VERSION
    /\ v \notin emitted
    /\ emitted' = emitted \cup {v}
    /\ queue' = Append(queue, EventOf(v))
    /\ UNCHANGED rows

Reorder ==
    /\ Len(queue) >= 2
    /\ queue' = <<queue[2], queue[1]>>
    /\ UNCHANGED <<emitted, rows>>

Deliver ==
    /\ Len(queue) > 0
    /\ rows' = rows \cup {Head(queue)}
    /\ queue' = Tail(queue)
    /\ UNCHANGED emitted

Next ==
    \/ \E v \in 1..MAX_VERSION : Emit(v)
    \/ Reorder
    \/ Deliver
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ emitted \subseteq 1..MAX_VERSION
    /\ queue \in Seq(Event)
    /\ rows \subseteq AllEvents

HistoryIntegrity ==
    \A e \in rows : e.status = StatusOf(e.version)

LatestVersionSafety ==
    rows # {} =>
        LET latest == CHOOSE v \in 1..MAX_VERSION :
                          EventOf(v) \in rows /\
                          \A w \in 1..MAX_VERSION :
                              EventOf(w) \in rows => w <= v
        IN EventOf(latest) \in rows

TerminalHistorySafety ==
    EventOf(MAX_VERSION) \in rows => StatusOf(MAX_VERSION) = "succeeded"

=============================================================================
