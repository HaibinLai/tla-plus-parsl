----------------------- MODULE ParslMonitoringResourceHistory -----------------------
EXTENDS Naturals, Sequences, FiniteSets

(***************************************************************************
 * Append-only resource samples in the monitoring RESOURCE table.
 *
 * Resource messages can arrive out of order because they travel through the
 * external resource queue.  The table key includes timestamp, so each sample
 * remains a distinct row and a duplicate sample is idempotent.  Consumers can
 * select the greatest timestamp without allowing an older sample to overwrite
 * the latest observation.
 ***************************************************************************)

CONSTANT MAX_SAMPLES
Samples == { [timestamp |-> t, value |-> v] :
             t \in 1..MAX_SAMPLES, v \in 0..2 }

VARIABLES nextTimestamp, queue, rows, latest
vars == <<nextTimestamp, queue, rows, latest>>

Init ==
    /\ MAX_SAMPLES > 0
    /\ nextTimestamp = 1
    /\ queue = <<>>
    /\ rows = {}
    /\ latest = 0

Produce(v) ==
    /\ nextTimestamp \in 1..MAX_SAMPLES
    /\ v \in 0..2
    /\ Len(queue) < MAX_SAMPLES
    /\ queue' = Append(queue, [timestamp |-> nextTimestamp, value |-> v])
    /\ nextTimestamp' = nextTimestamp + 1
    /\ UNCHANGED <<rows, latest>>

Deliver(i) ==
    /\ i \in 1..Len(queue)
    /\ LET sample == queue[i] IN
        /\ rows' = rows \cup {sample}
        /\ latest' = IF sample.timestamp > latest THEN sample.timestamp ELSE latest
    /\ queue' = SubSeq(queue, 1, i - 1) \o SubSeq(queue, i + 1, Len(queue))
    /\ UNCHANGED nextTimestamp

Duplicate(sample) ==
    /\ sample \in rows
    /\ Len(queue) < MAX_SAMPLES
    /\ queue' = Append(queue, sample)
    /\ UNCHANGED <<nextTimestamp, rows, latest>>

Next ==
    \/ \E v \in 0..2 : Produce(v)
    \/ \E i \in 1..Len(queue) : Deliver(i)
    \/ \E sample \in rows : Duplicate(sample)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ nextTimestamp \in 1..(MAX_SAMPLES + 1)
    /\ queue \in Seq(Samples)
    /\ rows \subseteq Samples
    /\ latest \in 0..MAX_SAMPLES

AppendOnly ==
    \A sample \in rows : sample.timestamp < nextTimestamp

LatestSafety ==
    /\ latest = 0 <=> rows = {}
    /\ latest # 0 =>
        /\ \E sample \in rows : sample.timestamp = latest
        /\ \A sample \in rows : sample.timestamp <= latest

DuplicateSafety ==
    Cardinality({sample.timestamp : sample \in rows}) = Cardinality(rows)

=============================================================================
