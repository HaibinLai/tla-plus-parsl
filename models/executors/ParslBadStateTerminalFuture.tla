--------------------------- MODULE ParslBadStateTerminalFuture ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Executor bad-state cleanup with a terminal Future in the task registry.
 *
 * set_bad_state_and_fail_all walks the registry and calls set_exception on
 * every Future.  The current branch raises when it reaches an already-done
 * Future and stops before failing the remaining pending work; the fixed branch
 * skips terminal entries and continues the drain.
 ***************************************************************************)

CONSTANT USE_FIXED
Tasks == {"T1", "T2"}
TaskStates == {"pending", "done", "failed"}

VARIABLES task, badState, cleanupError
vars == <<task, badState, cleanupError>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ task = [t \in Tasks |-> "pending"]
    /\ badState = FALSE
    /\ cleanupError = FALSE

CompleteFirst ==
    /\ task["T1"] = "pending"
    /\ task' = [task EXCEPT !["T1"] = "done"]
    /\ UNCHANGED <<badState, cleanupError>>

SetBadState ==
    /\ ~badState
    /\ badState' = TRUE
    /\ UNCHANGED <<task, cleanupError>>

FailPending(t) ==
    /\ badState
    /\ t \in Tasks
    /\ task[t] = "pending"
    /\ task' = [task EXCEPT ![t] = "failed"]
    /\ UNCHANGED <<badState, cleanupError>>

VisitTerminal(t) ==
    /\ badState
    /\ t \in Tasks
    /\ task[t] = "done"
    /\ IF USE_FIXED
          THEN cleanupError' = FALSE
          ELSE cleanupError' = TRUE
    /\ UNCHANGED <<task, badState>>

Next ==
    \/ CompleteFirst
    \/ SetBadState
    \/ \E t \in Tasks : FailPending(t) \/ VisitTerminal(t)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ task \in [Tasks -> TaskStates]
    /\ badState \in BOOLEAN
    /\ cleanupError \in BOOLEAN

NoCleanupError == ~cleanupError

BadStateDrainsPending ==
    cleanupError => task["T2"] = "pending"

TerminalTaskStable == task["T1"] = "done" => task["T1"] = "done"

=============================================================================
