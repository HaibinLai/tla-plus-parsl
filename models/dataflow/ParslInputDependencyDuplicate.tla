--------------------------- MODULE ParslInputDependencyDuplicate ---------------------------
EXTENDS Naturals

(***************************************************************************
 * DataFlowKernel._gather_all_deps walks every kwarg and then walks the
 * special inputs kwarg again.  A Future supplied through inputs is therefore
 * registered twice.  USE_FIXED excludes inputs from the generic kwarg pass.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLE dependencyCount

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ dependencyCount = 0

GatherGenericKwargs ==
    /\ dependencyCount' = IF USE_FIXED THEN 0 ELSE 1

GatherInputs ==
    /\ dependencyCount = IF USE_FIXED THEN 0 ELSE 1
    /\ dependencyCount' = dependencyCount + 1

Next == GatherGenericKwargs \/ GatherInputs \/ UNCHANGED dependencyCount
Spec == Init /\ [][Next]_dependencyCount

TypeOK == dependencyCount \in 0..2
NoDuplicateDependency == dependencyCount <= 1
=============================================================================
