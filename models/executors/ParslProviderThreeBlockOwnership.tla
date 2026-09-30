--------------------- MODULE ParslProviderThreeBlockOwnership ---------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * Three-block provider ownership.
 *
 * The model keeps block generations, task ownership, one-task-per-block
 * capacity, failure/retry, stale polls, and idle-only scale-in separate.  The
 * current branch revives a failed block when an old poll arrives; the fixed
 * branch ignores that poll.
 ***************************************************************************)

CONSTANT USE_FIXED

Blocks == {"B1", "B2", "B3"}
Tasks == {"T1", "T2", "T3"}

VARIABLES block, generation, polledGeneration, task, taskBlock, stalePoll

vars == <<block, generation, polledGeneration, task, taskBlock, stalePoll>>

Init ==
    /\ block = [b \in Blocks |-> "none"]
    /\ generation = [b \in Blocks |-> 0]
    /\ polledGeneration = [b \in Blocks |-> 0]
    /\ task = [t \in Tasks |-> "pending"]
    /\ taskBlock = [t \in Tasks |-> "none"]
    /\ stalePoll = [b \in Blocks |-> FALSE]

Request(b) ==
    /\ b \in Blocks
    /\ block[b] = "none"
    /\ block' = [block EXCEPT ![b] = "pending"]
    /\ UNCHANGED <<generation, polledGeneration, task, taskBlock, stalePoll>>

Provision(b) ==
    /\ b \in Blocks
    /\ block[b] = "pending"
    /\ generation[b] < 2
    /\ block' = [block EXCEPT ![b] = "active"]
    /\ generation' = [generation EXCEPT ![b] = @ + 1]
    /\ stalePoll' = [stalePoll EXCEPT ![b] = FALSE]
    /\ UNCHANGED <<polledGeneration, task, taskBlock>>

Assign(t, b) ==
    /\ t \in Tasks
    /\ b \in Blocks
    /\ task[t] = "pending"
    /\ block[b] = "active"
    /\ \A other \in Tasks : task[other] = "running" => taskBlock[other] # b
    /\ task' = [task EXCEPT ![t] = "running"]
    /\ taskBlock' = [taskBlock EXCEPT ![t] = b]
    /\ UNCHANGED <<block, generation, polledGeneration, stalePoll>>

Complete(t) ==
    /\ t \in Tasks
    /\ task[t] = "running"
    /\ task' = [task EXCEPT ![t] = "done"]
    /\ UNCHANGED <<block, generation, polledGeneration, taskBlock, stalePoll>>

FailBlock(b) ==
    /\ b \in Blocks
    /\ block[b] = "active"
    /\ block' = [block EXCEPT ![b] = "failed"]
    /\ task' = [t \in Tasks |->
        IF taskBlock[t] = b /\ task[t] = "running" THEN "pending" ELSE task[t]]
    /\ UNCHANGED <<generation, polledGeneration, taskBlock, stalePoll>>

LatePoll(b) ==
    /\ b \in Blocks
    /\ block[b] = "failed"
    /\ polledGeneration[b] < generation[b]
    /\ stalePoll' = [stalePoll EXCEPT ![b] = TRUE]
    /\ IF USE_FIXED
          THEN block' = block
          ELSE block' = [block EXCEPT ![b] = "active"]
    /\ UNCHANGED <<generation, polledGeneration, task, taskBlock>>

RetryBlock(b) ==
    /\ b \in Blocks
    /\ block[b] = "failed"
    /\ block' = [block EXCEPT ![b] = "pending"]
    /\ UNCHANGED <<generation, polledGeneration, task, taskBlock, stalePoll>>

ScaleIn(b) ==
    /\ b \in Blocks
    /\ block[b] = "active"
    /\ \A t \in Tasks : taskBlock[t] = b => task[t] # "running"
    /\ block' = [block EXCEPT ![b] = "removed"]
    /\ UNCHANGED <<generation, polledGeneration, task, taskBlock, stalePoll>>

Next ==
    \/ \E b \in Blocks : Request(b) \/ Provision(b) \/ FailBlock(b)
                                \/ LatePoll(b) \/ RetryBlock(b) \/ ScaleIn(b)
    \/ \E t \in Tasks, b \in Blocks : Assign(t, b)
    \/ \E t \in Tasks : Complete(t)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ block \in [Blocks -> {"none", "pending", "active", "failed", "removed"}]
    /\ generation \in [Blocks -> 0..2]
    /\ polledGeneration \in [Blocks -> 0..2]
    /\ task \in [Tasks -> {"pending", "running", "done"}]
    /\ taskBlock \in [Tasks -> (Blocks \cup {"none"})]
    /\ stalePoll \in [Blocks -> BOOLEAN]

OwnershipSafety ==
    \A t \in Tasks : task[t] = "running" =>
        taskBlock[t] \in Blocks /\ block[taskBlock[t]] = "active"

BlockCapacitySafety ==
    \A b \in Blocks : Cardinality({t \in Tasks : task[t] = "running" /\ taskBlock[t] = b}) <= 1

ScaleInSafety ==
    \A b \in Blocks : block[b] = "removed" =>
        \A t \in Tasks : taskBlock[t] # b \/ task[t] # "running"

StalePollSafety ==
    \A b \in Blocks : stalePoll[b] => block[b] # "active"

=============================================================================
