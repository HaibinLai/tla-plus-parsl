--------------------------- MODULE ParslGlobusTransferTimeout ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Globus.transfer_file active-transfer wait bound.
 *
 * The implementation passes timeout=60 to each task_wait call, but its
 * surrounding loop has no overall deadline.  A transfer that remains ACTIVE
 * can therefore keep the stage Future pending forever.  The fixed branch
 * turns the bounded poll budget into an explicit timeout outcome.
 *************************************************************************** *)

CONSTANTS MAX_POLLS, USE_FIXED
VARIABLES state, polls
vars == <<state, polls>>

Init ==
    /\ MAX_POLLS \in Nat
    /\ MAX_POLLS > 0
    /\ USE_FIXED \in BOOLEAN
    /\ state = "submitted"
    /\ polls = 0

Submit ==
    /\ state = "submitted"
    /\ state' = "polling"
    /\ UNCHANGED polls

ActivePoll ==
    /\ state = "polling"
    /\ polls < MAX_POLLS
    /\ polls' = polls + 1
    /\ state' = "polling"

PollBudgetExpires ==
    /\ state = "polling"
    /\ polls = MAX_POLLS
    /\ IF USE_FIXED
          THEN /\ state' = "timed-out"
               /\ UNCHANGED polls
               ELSE /\ state' = "polling"
               /\ UNCHANGED polls

Next == Submit \/ ActivePoll \/ PollBudgetExpires \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"submitted", "polling", "timed-out"}
    /\ polls \in Nat

TerminalOutcome == state = "timed-out"

BoundedWaitSafety == state = "polling" => (polls < MAX_POLLS \/ USE_FIXED)

=============================================================================
