--------------------------- MODULE ParslProviderPolling ---------------------------
EXTENDS Naturals, Integers, FiniteSets

(***************************************************************************
 * ExecutionProvider API polling abstraction.
 *
 * Provider submit, status, and cancel calls are modeled separately from the
 * executor's desired block target.  Unknown status is treated as provider
 * failure, transient API errors do not fabricate an active block, and cancel
 * failure restores the pre-cancel state.
 ***************************************************************************)

CONSTANTS BLOCKS, MAX_BLOCKS, MAX_API_FAILURES, MAX_STATUS_POLLS

BlockStates == {"absent", "submitting", "pending", "running", "cancelling",
                "cancelled", "failed"}
CallKinds == {"none", "status", "cancel"}
CancelPreviousStates == {"none", "pending", "running"}

VARIABLES blockState, providerTarget, callKind, callBlock,
          cancelPrevious, apiFailures, statusPolls

vars == <<blockState, providerTarget, callKind, callBlock,
           cancelPrevious, apiFailures, statusPolls>>

Init ==
    /\ BLOCKS # {}
    /\ MAX_BLOCKS >= Cardinality(BLOCKS)
    /\ MAX_API_FAILURES >= 0
    /\ MAX_STATUS_POLLS > 0
    /\ blockState = [b \in BLOCKS |-> "absent"]
    /\ providerTarget = 0
    /\ callKind = "none"
    /\ callBlock = "none"
    /\ cancelPrevious = [b \in BLOCKS |-> "none"]
    /\ apiFailures = 0
    /\ statusPolls = [b \in BLOCKS |-> 0]

SubmitBlock(b) ==
    /\ blockState[b] = "absent"
    /\ providerTarget < MAX_BLOCKS
    /\ blockState' = [blockState EXCEPT ![b] = "submitting"]
    /\ providerTarget' = providerTarget + 1
    /\ UNCHANGED <<callKind, callBlock, cancelPrevious, apiFailures, statusPolls>>

SubmitAccepted(b) ==
    /\ blockState[b] = "submitting"
    /\ blockState' = [blockState EXCEPT ![b] = "pending"]
    /\ UNCHANGED <<providerTarget, callKind, callBlock,
                    cancelPrevious, apiFailures, statusPolls>>

SubmitRejected(b) ==
    /\ blockState[b] = "submitting"
    /\ providerTarget' = providerTarget - 1
    /\ blockState' = [blockState EXCEPT ![b] = "absent"]
    /\ UNCHANGED <<callKind, callBlock, cancelPrevious, apiFailures, statusPolls>>

BeginStatus(b) ==
    /\ callKind = "none"
    /\ blockState[b] \in {"pending", "running"}
    /\ callKind' = "status"
    /\ callBlock' = b
    /\ UNCHANGED <<blockState, providerTarget, cancelPrevious,
                    apiFailures, statusPolls>>

StatusPending ==
    /\ callKind = "status"
    /\ blockState[callBlock] \in {"pending", "running"}
    /\ statusPolls[callBlock] < MAX_STATUS_POLLS
    /\ blockState' = [blockState EXCEPT ![callBlock] = "pending"]
    /\ statusPolls' = [statusPolls EXCEPT ![callBlock] = @ + 1]
    /\ callKind' = "none"
    /\ callBlock' = "none"
    /\ UNCHANGED <<providerTarget, cancelPrevious, apiFailures>>

StatusRunning ==
    /\ callKind = "status"
    /\ blockState[callBlock] \in {"pending", "running"}
    /\ statusPolls[callBlock] < MAX_STATUS_POLLS
    /\ blockState' = [blockState EXCEPT ![callBlock] = "running"]
    /\ statusPolls' = [statusPolls EXCEPT ![callBlock] = @ + 1]
    /\ callKind' = "none"
    /\ callBlock' = "none"
    /\ UNCHANGED <<providerTarget, cancelPrevious, apiFailures>>

StatusUnknown ==
    /\ callKind = "status"
    /\ blockState[callBlock] \in {"pending", "running"}
    /\ blockState' = [blockState EXCEPT ![callBlock] = "failed"]
    /\ providerTarget' = providerTarget - 1
    /\ callKind' = "none"
    /\ callBlock' = "none"
    /\ UNCHANGED <<cancelPrevious, apiFailures, statusPolls>>

StatusError ==
    /\ callKind = "status"
    /\ callBlock \in BLOCKS
    /\ apiFailures < MAX_API_FAILURES
    /\ apiFailures' = apiFailures + 1
    /\ callKind' = "none"
    /\ callBlock' = "none"
    /\ UNCHANGED <<blockState, providerTarget, cancelPrevious, statusPolls>>

BeginCancel(b) ==
    /\ callKind = "none"
    /\ blockState[b] \in {"pending", "running"}
    /\ blockState' = [blockState EXCEPT ![b] = "cancelling"]
    /\ cancelPrevious' = [cancelPrevious EXCEPT ![b] = blockState[b]]
    /\ callKind' = "cancel"
    /\ callBlock' = b
    /\ UNCHANGED <<providerTarget, apiFailures, statusPolls>>

CancelAccepted ==
    /\ callKind = "cancel"
    /\ blockState[callBlock] = "cancelling"
    /\ blockState' = [blockState EXCEPT ![callBlock] = "cancelled"]
    /\ providerTarget' = providerTarget - 1
    /\ cancelPrevious' = [cancelPrevious EXCEPT ![callBlock] = "none"]
    /\ callKind' = "none"
    /\ callBlock' = "none"
    /\ UNCHANGED <<apiFailures, statusPolls>>

CancelFailed ==
    /\ callKind = "cancel"
    /\ blockState[callBlock] = "cancelling"
    /\ blockState' = [blockState EXCEPT ![callBlock] = cancelPrevious[callBlock]]
    /\ cancelPrevious' = [cancelPrevious EXCEPT ![callBlock] = "none"]
    /\ callKind' = "none"
    /\ callBlock' = "none"
    /\ UNCHANGED <<providerTarget, apiFailures, statusPolls>>

Next ==
    \/ \E b \in BLOCKS : SubmitBlock(b)
    \/ \E b \in BLOCKS : SubmitAccepted(b) \/ SubmitRejected(b)
    \/ \E b \in BLOCKS : BeginStatus(b)
    \/ StatusPending
    \/ StatusRunning
    \/ StatusUnknown
    \/ StatusError
    \/ \E b \in BLOCKS : BeginCancel(b)
    \/ CancelAccepted
    \/ CancelFailed
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ blockState \in [BLOCKS -> BlockStates]
    /\ providerTarget \in 0..MAX_BLOCKS
    /\ callKind \in CallKinds
    /\ callBlock \in BLOCKS \cup {"none"}
    /\ cancelPrevious \in [BLOCKS -> CancelPreviousStates]
    /\ apiFailures \in 0..MAX_API_FAILURES
    /\ statusPolls \in [BLOCKS -> 0..MAX_STATUS_POLLS]

TargetSafety ==
    /\ providerTarget <= MAX_BLOCKS
    /\ providerTarget >= 0
    /\ Cardinality({b \in BLOCKS :
          blockState[b] \in {"submitting", "pending", "running", "cancelling"}})
       <= providerTarget

CallSafety ==
    /\ callKind = "none" => callBlock = "none"
    /\ callKind # "none" => callBlock \in BLOCKS
    /\ callKind = "status" => blockState[callBlock] \in {"pending", "running"}
    /\ callKind = "cancel" => blockState[callBlock] = "cancelling"

ActiveBlockSafety ==
    \A b \in BLOCKS : blockState[b] = "running" => providerTarget > 0

UnknownStatusSafety ==
    \A b \in BLOCKS : blockState[b] = "failed" =>
        b # callBlock \/ callKind # "status"

CancelSafety ==
    \A b \in BLOCKS :
        blockState[b] = "cancelled" => cancelPrevious[b] = "none"

=============================================================================
