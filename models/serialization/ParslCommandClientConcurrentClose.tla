--------------------------- MODULE ParslCommandClientConcurrentClose ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Concurrent CommandClient.close while run() owns the command operation.
 *
 * run() serializes poll/send/receive under _lock, but close() currently does
 * not acquire that lock.  The current branch can close the socket during an
 * in-flight command, producing a raw socket error while leaving the client
 * apparently healthy.  The fixed branch lets the in-flight command finish
 * before close acquires the operation boundary.
 ***************************************************************************)

CONSTANT USE_FIXED

States == {"open", "running", "running_closed", "completed", "closed", "raw_error"}
VARIABLES state, socketClosed, ok
vars == <<state, socketClosed, ok>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "open"
    /\ socketClosed = FALSE
    /\ ok = TRUE

StartRun ==
    /\ state = "open"
    /\ state' = "running"
    /\ UNCHANGED <<socketClosed, ok>>

Close ==
    /\ state \in IF USE_FIXED THEN {"open", "completed"}
                              ELSE {"open", "running", "completed"}
    /\ state' = IF state = "running" THEN "running_closed" ELSE "closed"
    /\ socketClosed' = TRUE
    /\ ok' = IF USE_FIXED THEN FALSE ELSE TRUE

RunCompletes ==
    /\ state = "running"
    /\ ~socketClosed
    /\ state' = "completed"
    /\ UNCHANGED <<socketClosed, ok>>

RunHitsClosedSocket ==
    /\ state = "running_closed"
    /\ socketClosed
    /\ state' = "raw_error"
    /\ UNCHANGED <<socketClosed, ok>>

Next ==
    \/ StartRun
    \/ Close
    \/ RunCompletes
    \/ RunHitsClosedSocket
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ state \in States
    /\ socketClosed \in BOOLEAN
    /\ ok \in BOOLEAN

ConcurrentCloseSafety ==
    state = "raw_error" => USE_FIXED

ClosedClientHealth ==
    state = "closed" => ~ok

=============================================================================
