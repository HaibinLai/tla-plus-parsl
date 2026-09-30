--------------------------- MODULE ParslFluxInflightSubmissionFailure ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Flux submission failure after dequeue.
 *
 * The submission thread removes a job from submission_queue before building
 * its Flux jobspec.  A preparation exception therefore occurs after dequeue;
 * the current wrapper drains only the remaining queue and can leave this
 * in-flight Future pending.  The fixed branch terminally fails the job before
 * stopping the submission thread.
 ***************************************************************************)

CONSTANT USE_FIXED

JobStates == {"queued", "inflight", "submitted", "failed"}
ThreadStates == {"running", "stopped"}
FutureStates == {"pending", "succeeded", "failed"}

VARIABLES job, thread, future
vars == <<job, thread, future>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ job = "queued"
    /\ thread = "running"
    /\ future = "pending"

Dequeue ==
    /\ job = "queued"
    /\ job' = "inflight"
    /\ UNCHANGED <<thread, future>>

BuildSuccess ==
    /\ job = "inflight"
    /\ job' = "submitted"
    /\ future' = "succeeded"
    /\ UNCHANGED thread

BuildFailure ==
    /\ job = "inflight"
    /\ job' = IF USE_FIXED THEN "failed" ELSE "inflight"
    /\ future' = IF USE_FIXED THEN "failed" ELSE "pending"
    /\ thread' = "stopped"

Next ==
    \/ Dequeue
    \/ BuildSuccess
    \/ BuildFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ job \in JobStates
    /\ thread \in ThreadStates
    /\ future \in FutureStates

SubmissionFailureTerminality ==
    thread = "stopped" => future # "pending"

NoInflightOrphan ==
    thread = "stopped" => job # "inflight"

=============================================================================
