--------------------------- MODULE ParslMPILifecycle ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Compact composition model for MPIExecutor/MPITaskScheduler.
 *
 * Resource validation, node allocation, MPI launch, result decoding, and
 * shutdown are connected here.  `mapped` represents the optional task-to-node
 * bookkeeping entry, while `resourceValid` and `allocation` model the
 * scheduler's resource contract separately.
 ***************************************************************************)

CONSTANT USE_FIXED

Phases == {"new", "accepted", "rejected", "queued", "running", "completed",
          "failed", "cancelled", "assertion", "decode-error", "stopped"}

VARIABLES phase, resourceValid, mapped, allocation, executorState
vars == <<phase, resourceValid, mapped, allocation, executorState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "new"
    /\ resourceValid = TRUE
    /\ mapped = TRUE
    /\ allocation = FALSE
    /\ executorState = "running"

Configure(kind) ==
    /\ phase = "new"
    /\ kind \in {"mapped-valid", "unmapped-valid", "invalid"}
    /\ resourceValid' = (kind # "invalid")
    /\ mapped' = (kind = "mapped-valid")
    /\ UNCHANGED <<phase, allocation, executorState>>

Validate ==
    /\ phase = "new"
    /\ IF USE_FIXED /\ ~resourceValid THEN phase' = "rejected" ELSE phase' = "accepted"
    /\ UNCHANGED <<resourceValid, mapped, allocation, executorState>>

Submit ==
    /\ phase = "accepted"
    /\ phase' = "queued"
    /\ UNCHANGED <<resourceValid, mapped, allocation, executorState>>

Launch ==
    /\ phase = "queued"
    /\ phase' = "running"
    /\ allocation' = TRUE
    /\ UNCHANGED <<resourceValid, mapped, executorState>>

ReceiveResult(kind) ==
    /\ phase = "running"
    /\ kind \in {"valid", "corrupt"}
    /\ IF kind = "corrupt" THEN
           /\ IF USE_FIXED THEN
                  /\ phase' = "failed"
                  /\ allocation' = FALSE
              ELSE
                  /\ phase' = "decode-error"
                  /\ allocation' = TRUE
       ELSE IF mapped \/ USE_FIXED THEN
           /\ phase' = "completed"
           /\ allocation' = FALSE
       ELSE
           /\ phase' = "assertion"
           /\ allocation' = FALSE
    /\ UNCHANGED <<resourceValid, mapped, executorState>>

Cancel ==
    /\ phase = "running"
    /\ phase' = "cancelled"
    /\ allocation' = FALSE
    /\ UNCHANGED <<resourceValid, mapped, executorState>>

Shutdown ==
    /\ executorState = "running"
    /\ phase \in {"completed", "failed", "cancelled", "rejected"}
    /\ executorState' = "stopped"
    /\ phase' = "stopped"
    /\ UNCHANGED <<resourceValid, mapped, allocation>>

Next ==
    \/ \E kind \in {"mapped-valid", "unmapped-valid", "invalid"} : Configure(kind)
    \/ Validate
    \/ Submit
    \/ Launch
    \/ \E kind \in {"valid", "corrupt"} : ReceiveResult(kind)
    \/ Cancel
    \/ Shutdown
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ resourceValid \in BOOLEAN
    /\ mapped \in BOOLEAN
    /\ allocation \in BOOLEAN
    /\ executorState \in {"running", "stopped"}

ResourceLaunchSafety == phase = "running" => resourceValid
DecodeCleanup == phase = "decode-error" => ~allocation
NoRawAssertion == phase # "assertion"
TerminalAllocation == phase \in {"completed", "failed", "cancelled", "stopped"} => ~allocation
ShutdownTerminal == executorState = "stopped" => phase = "stopped"

=============================================================================
