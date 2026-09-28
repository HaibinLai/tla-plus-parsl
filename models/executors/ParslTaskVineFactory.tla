--------------------------- MODULE ParslTaskVineFactory ---------------------------
EXTENDS Naturals

(***************************************************************************
 * TaskVine's optional factory process.  Parsl constructs a TaskVine Factory,
 * applies factory/worker timeout and capacity settings, enters its context,
 * and leaves only after the executor stop signal is set.  Construction errors
 * are translated into TaskVineFactoryFailure.
 *************************************************************************** *)

VARIABLES factoryState, configState, stopSignal, errorState
vars == <<factoryState, configState, stopSignal, errorState>>

Init ==
    /\ factoryState = "absent"
    /\ configState = "unset"
    /\ stopSignal = FALSE
    /\ errorState = "none"

CreateFactory ==
    /\ factoryState = "absent"
    /\ factoryState' = "created"
    /\ configState' = "unset"
    /\ UNCHANGED <<stopSignal, errorState>>

ConfigureFactory ==
    /\ factoryState = "created"
    /\ configState = "unset"
    /\ factoryState' = "created"
    /\ configState' = "configured"
    /\ UNCHANGED <<stopSignal, errorState>>

EnterContext ==
    /\ factoryState = "created"
    /\ configState = "configured"
    /\ factoryState' = "running"
    /\ UNCHANGED <<configState, stopSignal, errorState>>

RequestStop ==
    /\ factoryState = "running"
    /\ stopSignal' = TRUE
    /\ UNCHANGED <<factoryState, configState, errorState>>

ExitContext ==
    /\ factoryState = "running"
    /\ stopSignal
    /\ factoryState' = "stopped"
    /\ UNCHANGED <<configState, stopSignal, errorState>>

CreateFailure ==
    /\ factoryState = "absent"
    /\ factoryState' = "stopped"
    /\ errorState' = "TaskVineFactoryFailure"
    /\ UNCHANGED <<configState, stopSignal>>

Done ==
    /\ factoryState = "stopped"
    /\ UNCHANGED vars

Next == CreateFactory \/ ConfigureFactory \/ EnterContext \/ RequestStop
       \/ ExitContext \/ CreateFailure \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ factoryState \in {"absent", "created", "running", "stopped"}
    /\ configState \in {"unset", "configured"}
    /\ stopSignal \in BOOLEAN
    /\ errorState \in {"none", "TaskVineFactoryFailure"}

ConfigurationBeforeRun ==
    factoryState = "running" => configState = "configured"

StopBeforeExit ==
    factoryState = "stopped" /\ errorState = "none" => stopSignal

=============================================================================
