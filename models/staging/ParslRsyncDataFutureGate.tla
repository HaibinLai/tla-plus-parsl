--------------------------- MODULE ParslRsyncDataFutureGate ---------------------------
EXTENDS Naturals

(***************************************************************************
 * RSync stage-out and DataFuture readiness.
 *
 * RSync's stage-out wrapper runs the application and then copies the output.
 * The provider returns None, so DataManager can make the output DataFuture
 * follow the application Future rather than the in-task rsync operation.  The
 * Current branch therefore exposes a ready DataFuture before bytes are
 * published (and can keep it ready after rsync failure).  The Fixed branch
 * gates readiness on successful rsync publication.
 ***************************************************************************)

CONSTANT USE_FIXED
AppStates == {"new", "running", "succeeded", "failed"}
RsyncStates == {"idle", "running", "succeeded", "failed"}
FutureStates == {"unresolved", "ready", "failed"}
ConsumerStates == {"blocked", "running", "done"}
ByteStates == {"none", "partial", "complete"}

VARIABLES app, rsync, dataFuture, consumer, bytes
vars == <<app, rsync, dataFuture, consumer, bytes>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ app = "new"
    /\ rsync = "idle"
    /\ dataFuture = "unresolved"
    /\ consumer = "blocked"
    /\ bytes = "none"

StartApp ==
    /\ app = "new"
    /\ app' = "running"
    /\ UNCHANGED <<rsync, dataFuture, consumer, bytes>>

CompleteApp ==
    /\ app = "running"
    /\ app' = "succeeded"
    /\ dataFuture' = IF USE_FIXED THEN dataFuture ELSE "ready"
    /\ UNCHANGED <<rsync, consumer, bytes>>

FailApp ==
    /\ app = "running"
    /\ app' = "failed"
    /\ dataFuture' = "failed"
    /\ UNCHANGED <<rsync, consumer, bytes>>

StartRsync ==
    /\ app = "succeeded"
    /\ rsync = "idle"
    /\ rsync' = "running"
    /\ UNCHANGED <<app, dataFuture, consumer, bytes>>

RsyncSuccess ==
    /\ rsync = "running"
    /\ rsync' = "succeeded"
    /\ dataFuture' = "ready"
    /\ bytes' = "complete"
    /\ UNCHANGED <<app, consumer>>

RsyncFailure ==
    /\ rsync = "running"
    /\ rsync' = "failed"
    /\ dataFuture' = IF USE_FIXED THEN "failed" ELSE dataFuture
    /\ bytes' = IF USE_FIXED THEN "none" ELSE "partial"
    /\ UNCHANGED <<app, consumer>>

StartConsumer ==
    /\ consumer = "blocked"
    /\ dataFuture = "ready"
    /\ consumer' = "running"
    /\ UNCHANGED <<app, rsync, dataFuture, bytes>>

FinishConsumer ==
    /\ consumer = "running"
    /\ consumer' = "done"
    /\ UNCHANGED <<app, rsync, dataFuture, bytes>>

Next ==
    \/ StartApp
    \/ CompleteApp
    \/ FailApp
    \/ StartRsync
    \/ RsyncSuccess
    \/ RsyncFailure
    \/ StartConsumer
    \/ FinishConsumer
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ app \in AppStates
    /\ rsync \in RsyncStates
    /\ dataFuture \in FutureStates
    /\ consumer \in ConsumerStates
    /\ bytes \in ByteStates

DataFutureGate ==
    dataFuture = "ready" => rsync = "succeeded" /\ bytes = "complete"

ConsumerGate ==
    consumer = "running" => rsync = "succeeded" /\ bytes = "complete"

FailureSafety ==
    rsync = "failed" =>
        /\ dataFuture # "ready"
        /\ consumer # "running"
        /\ bytes # "partial"

=============================================================================
CONSTANT USE_FIXED = TRUE

SPECIFICATION Spec

INVARIANTS
    TypeOK
    DataFutureGate
    ConsumerGate
    FailureSafety
