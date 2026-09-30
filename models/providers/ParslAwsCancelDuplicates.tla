--------------------------- MODULE ParslAwsCancelDuplicates ---------------------------
EXTENDS Naturals

(***************************************************************************
 * AWSProvider.cancel receives a batch of instance IDs.  The remote API can
 * accept a repeated ID, but the current local cleanup loop removes each ID
 * from ``instances`` unconditionally.  A repeated ID therefore raises after
 * the remote termination already succeeded.  USE_FIXED models idempotent
 * local cleanup (or request de-duplication).
 ***************************************************************************)

CONSTANTS DUPLICATE_REQUEST, REMOTE_SUCCEEDS, USE_FIXED

VARIABLES state, localPresent, remoteTerminated
vars == <<state, localPresent, remoteTerminated>>

Init ==
    /\ DUPLICATE_REQUEST \in BOOLEAN
    /\ REMOTE_SUCCEEDS \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "ready"
    /\ localPresent = TRUE
    /\ remoteTerminated = FALSE

RemoteFailure ==
    /\ state = "ready"
    /\ ~REMOTE_SUCCEEDS
    /\ state' = "failed"
    /\ UNCHANGED <<localPresent, remoteTerminated>>

RemoteSuccess ==
    /\ state = "ready"
    /\ REMOTE_SUCCEEDS
    /\ remoteTerminated' = TRUE
    /\ localPresent' = FALSE
    /\ state' =
        IF DUPLICATE_REQUEST /\ ~USE_FIXED THEN "failed" ELSE "completed"

Next == RemoteFailure \/ RemoteSuccess \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"ready", "failed", "completed"}
    /\ localPresent \in BOOLEAN
    /\ remoteTerminated \in BOOLEAN

RemoteSuccessSafety ==
    REMOTE_SUCCEEDS => state # "failed"

TerminalCleanup ==
    state = "completed" => /\ remoteTerminated
                         /\ ~localPresent

=============================================================================
