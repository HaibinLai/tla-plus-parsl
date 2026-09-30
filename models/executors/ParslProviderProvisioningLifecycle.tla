------------------- MODULE ParslProviderProvisioningLifecycle -------------------
EXTENDS Naturals

(***************************************************************************
 * Provider provisioning and stale polling.
 *
 * A single logical block is requested, provisioned, failed, retried, and
 * eventually used by one task.  A status poll from the failed generation can
 * arrive late.  The fixed provider ignores that stale observation instead of
 * reviving a block that no longer owns capacity.
 ***************************************************************************)

CONSTANT USE_FIXED
MAX_RETRIES == 1

VARIABLES provider, block, task, attempts, generation, polledGeneration,
          stalePoll, scaleInRequested
vars == <<provider, block, task, attempts, generation, polledGeneration,
          stalePoll, scaleInRequested>>

Init ==
    /\ provider = "up"
    /\ block = "none"
    /\ task = "pending"
    /\ attempts = 0
    /\ generation = 0
    /\ polledGeneration = 0
    /\ stalePoll = FALSE
    /\ scaleInRequested = FALSE

RequestBlock ==
    /\ block = "none"
    /\ block' = "pending"
    /\ UNCHANGED <<provider, task, attempts, generation, polledGeneration,
                    stalePoll, scaleInRequested>>

Provision ==
    /\ provider = "up"
    /\ block = "pending"
    /\ block' = "active"
    /\ generation' = generation + 1
    /\ stalePoll' = FALSE
    /\ UNCHANGED <<provider, task, attempts, polledGeneration,
                    scaleInRequested>>

ProviderFails ==
    /\ block = "active"
    /\ provider' = "down"
    /\ block' = "failed"
    /\ task' = IF task = "running" THEN "pending" ELSE task
    /\ UNCHANGED <<attempts, generation, polledGeneration, stalePoll,
                    scaleInRequested>>

RetryProvision ==
    /\ provider = "down"
    /\ block = "failed"
    /\ attempts < MAX_RETRIES
    /\ provider' = "up"
    /\ block' = "pending"
    /\ attempts' = attempts + 1
    /\ UNCHANGED <<task, generation, polledGeneration, stalePoll,
                    scaleInRequested>>

LatePoll ==
    /\ block = "failed"
    /\ polledGeneration < generation
    /\ stalePoll' = TRUE
    /\ IF USE_FIXED
          THEN block' = block
          ELSE block' = "active"
    /\ UNCHANGED <<provider, task, attempts, generation, polledGeneration,
                    scaleInRequested>>

Dispatch ==
    /\ block = "active"
    /\ task = "pending"
    /\ task' = "running"
    /\ UNCHANGED <<provider, block, attempts, generation, polledGeneration,
                    stalePoll, scaleInRequested>>

Complete ==
    /\ task = "running"
    /\ task' = "done"
    /\ UNCHANGED <<provider, block, attempts, generation, polledGeneration,
                    stalePoll, scaleInRequested>>

ScaleIn ==
    /\ block = "active"
    /\ task \in {"pending", "done"}
    /\ scaleInRequested' = TRUE
    /\ block' = "removed"
    /\ UNCHANGED <<provider, task, attempts, generation, polledGeneration,
                    stalePoll>>

Next ==
    \/ RequestBlock
    \/ Provision
    \/ ProviderFails
    \/ RetryProvision
    \/ LatePoll
    \/ Dispatch
    \/ Complete
    \/ ScaleIn
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ provider \in {"up", "down"}
    /\ block \in {"none", "pending", "active", "failed", "removed"}
    /\ task \in {"pending", "running", "done"}
    /\ attempts \in 0..MAX_RETRIES
    /\ generation \in 0..2
    /\ polledGeneration \in 0..2
    /\ stalePoll \in BOOLEAN
    /\ scaleInRequested \in BOOLEAN

RetryBoundSafety == attempts <= MAX_RETRIES

AdmissionSafety == task = "running" => block = "active" /\ provider = "up"

StalePollSafety == stalePoll => block # "active"

ScaleInSafety == scaleInRequested => block = "removed"

=============================================================================
CONSTANT USE_FIXED = TRUE

SPECIFICATION Spec

INVARIANTS
    TypeOK
    RetryBoundSafety
    AdmissionSafety
    StalePollSafety
    ScaleInSafety
