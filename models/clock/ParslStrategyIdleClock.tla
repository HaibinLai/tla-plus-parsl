--------------------------- MODULE ParslStrategyIdleClock ---------------------------
EXTENDS Naturals, Integers

(***************************************************************************
 * Idle scale-in deadline model for jobs.strategy.Strategy.
 *
 * The source currently stores an idle baseline and evaluates the deadline
 * with time.time().  A wall-clock rollback can therefore suppress scale-in
 * even though monotonic elapsed time has crossed the configured horizon.
 * The Fixed branch evaluates the same policy with monotonic elapsed time.
 ***************************************************************************)

CONSTANT USE_FIXED

MAX_IDLE == 5

VARIABLES wall, mono, idleWall, idleMono, scaledIn, observedDue
vars == <<wall, mono, idleWall, idleMono, scaledIn, observedDue>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ wall = 100
    /\ mono = 100
    /\ idleWall = 100
    /\ idleMono = 100
    /\ scaledIn = FALSE
    /\ observedDue = FALSE

Advance(wallDelta, monoDelta) ==
    /\ wallDelta \in -3..3
    /\ monoDelta \in 0..3
    /\ wall' = wall + wallDelta
    /\ mono' = mono + monoDelta
    /\ UNCHANGED <<idleWall, idleMono, scaledIn, observedDue>>

Evaluate ==
    /\ scaledIn = FALSE
    /\ observedDue' = IF mono - idleMono > MAX_IDLE THEN TRUE ELSE FALSE
    /\ scaledIn' = IF IF USE_FIXED
                            THEN mono - idleMono > MAX_IDLE
                            ELSE wall - idleWall > MAX_IDLE
                        THEN TRUE ELSE FALSE
    /\ UNCHANGED <<wall, mono, idleWall, idleMono>>

Next ==
    \/ \E wd \in -3..3, md \in 0..3 : Advance(wd, md)
    \/ Evaluate
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ wall \in Int
    /\ mono \in Nat
    /\ idleWall \in Int
    /\ idleMono \in Nat
    /\ scaledIn \in BOOLEAN
    /\ observedDue \in BOOLEAN

ObservedDeadlineSafety ==
    observedDue => scaledIn

NoPrematureScaleIn ==
    scaledIn => mono - idleMono > MAX_IDLE

=============================================================================
