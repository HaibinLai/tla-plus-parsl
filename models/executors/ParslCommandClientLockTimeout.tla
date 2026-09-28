--------------------------- MODULE ParslCommandClientLockTimeout ---------------------------
EXTENDS Naturals

(***************************************************************************
 * CommandClient.run starts its timeout clock before entering `with _lock`,
 * but Python Lock acquisition has no deadline.  A waiting caller can acquire
 * the lock after its command deadline and still send the REQ message.
 * USE_FIXED represents deadline-aware lock acquisition.
 *************************************************************************** *)

CONSTANT USE_FIXED
DEADLINE == 1

VARIABLES phase, lockHeld, elapsed
vars == <<phase, lockHeld, elapsed>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "waiting-lock"
    /\ lockHeld = TRUE
    /\ elapsed = 0

AdvanceTime ==
    /\ phase = "waiting-lock"
    /\ elapsed < DEADLINE
    /\ elapsed' = elapsed + 1
    /\ UNCHANGED <<phase, lockHeld>>

ReleaseOtherCommand ==
    /\ lockHeld
    /\ lockHeld' = FALSE
    /\ UNCHANGED <<phase, elapsed>>

AcquireAndSend ==
    /\ phase = "waiting-lock"
    /\ ~lockHeld
    /\ IF USE_FIXED /\ elapsed >= DEADLINE
          THEN /\ phase' = "timed-out"
               /\ lockHeld' = FALSE
          ELSE /\ phase' = "sent"
               /\ lockHeld' = TRUE
    /\ UNCHANGED elapsed

ReceiveReply ==
    /\ phase = "sent"
    /\ phase' = "returned"
    /\ lockHeld' = FALSE
    /\ UNCHANGED elapsed

Done ==
    /\ phase \in {"timed-out", "returned"}
    /\ UNCHANGED vars

Next == AdvanceTime \/ ReleaseOtherCommand \/ AcquireAndSend \/ ReceiveReply \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"waiting-lock", "sent", "returned", "timed-out"}
    /\ lockHeld \in BOOLEAN
    /\ elapsed \in 0..DEADLINE

DeadlineBeforeSend ==
    phase = "sent" => elapsed < DEADLINE

TimeoutTerminal ==
    phase = "timed-out" => ~lockHeld

=============================================================================
