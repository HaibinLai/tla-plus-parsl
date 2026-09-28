--------------------------- MODULE ParslStrategy ---------------------------
EXTENDS Naturals, Integers

CONSTANTS MAX_TASKS, MAX_BLOCKS, MIN_BLOCKS, SLOTS_PER_BLOCK,
          MAX_IDLE_TIME, MAX_TIME

VARIABLES activeTasks, blocks, idleSince, clock
vars == <<activeTasks, blocks, idleSince, clock>>

Init ==
    /\ MAX_TASKS > 0
    /\ MAX_BLOCKS >= MIN_BLOCKS
    /\ MIN_BLOCKS >= 0
    /\ SLOTS_PER_BLOCK > 0
    /\ MAX_IDLE_TIME >= 0
    /\ MAX_TIME >= MAX_IDLE_TIME
    /\ activeTasks = 0
    /\ blocks = MIN_BLOCKS
    /\ idleSince = -1
    /\ clock = 0

AddTask ==
    /\ activeTasks < MAX_TASKS
    /\ activeTasks' = activeTasks + 1
    /\ idleSince' = -1
    /\ UNCHANGED <<blocks, clock>>

CompleteTask ==
    /\ activeTasks > 0
    /\ activeTasks' = activeTasks - 1
    /\ UNCHANGED <<blocks, idleSince, clock>>

ScaleOut ==
    /\ activeTasks > blocks * SLOTS_PER_BLOCK
    /\ blocks < MAX_BLOCKS
    /\ blocks' = blocks + 1
    /\ idleSince' = -1
    /\ UNCHANGED <<activeTasks, clock>>

StartIdleTimer ==
    /\ activeTasks = 0
    /\ blocks > MIN_BLOCKS
    /\ idleSince = -1
    /\ idleSince' = clock
    /\ UNCHANGED <<activeTasks, blocks, clock>>

ScaleIn ==
    /\ activeTasks = 0
    /\ blocks > MIN_BLOCKS
    /\ idleSince # -1
    /\ clock - idleSince >= MAX_IDLE_TIME
    /\ blocks' = blocks - 1
    /\ idleSince' = -1
    /\ UNCHANGED <<activeTasks, clock>>

ResetIdleTimer ==
    /\ activeTasks > 0
    /\ idleSince # -1
    /\ idleSince' = -1
    /\ UNCHANGED <<activeTasks, blocks, clock>>

PollNoChange ==
    /\ ((activeTasks = 0 /\ blocks = MIN_BLOCKS)
        \/ (activeTasks > 0 /\ blocks = MAX_BLOCKS))
    /\ UNCHANGED vars

Tick ==
    /\ clock < MAX_TIME
    /\ clock' = clock + 1
    /\ UNCHANGED <<activeTasks, blocks, idleSince>>

Next == AddTask \/ CompleteTask \/ ScaleOut \/ StartIdleTimer
         \/ ScaleIn \/ ResetIdleTimer \/ PollNoChange \/ Tick

Spec == Init /\ [][Next]_vars /\ WF_vars(ScaleIn) /\ WF_vars(Tick)

TypeOK ==
    /\ activeTasks \in 0..MAX_TASKS
    /\ blocks \in MIN_BLOCKS..MAX_BLOCKS
    /\ idleSince \in -1..MAX_TIME
    /\ clock \in 0..MAX_TIME

CapacitySafety ==
    /\ blocks >= MIN_BLOCKS /\ blocks <= MAX_BLOCKS
    /\ activeTasks = 0 \/ activeTasks <= MAX_TASKS

IdleTimerSafety ==
    /\ idleSince = -1 \/ (idleSince <= clock /\ activeTasks = 0)

EventuallyIdleScaleIn ==
    []((activeTasks = 0 /\ blocks > MIN_BLOCKS /\ clock + MAX_IDLE_TIME <= MAX_TIME)
       ~> (blocks = MIN_BLOCKS))

=============================================================================
