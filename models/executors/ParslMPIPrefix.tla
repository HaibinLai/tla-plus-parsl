--------------------------- MODULE ParslMPIPrefix ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Bounded model of MPI launch-prefix selection.
 *
 * The real mpi_prefix_composer builds all supported prefixes and then selects
 * PARSL_MPI_PREFIX from srun, aprun, or mpiexec.  An unsupported launcher is
 * rejected rather than silently selecting a different backend.
 ***************************************************************************)

CONSTANTS MPI_LAUNCHER, SPEC_VALID

Launchers == {"srun", "aprun", "mpiexec"}
States == {"new", "composed", "rejected"}

VARIABLES state, selectedPrefix
vars == <<state, selectedPrefix>>

Init ==
    /\ MPI_LAUNCHER \in STRING
    /\ SPEC_VALID \in BOOLEAN
    /\ state = "new"
    /\ selectedPrefix = "none"

Compose ==
    /\ state = "new"
    /\ IF MPI_LAUNCHER \in Launchers /\ SPEC_VALID THEN
           /\ state' = "composed"
           /\ selectedPrefix' = MPI_LAUNCHER
       ELSE
           /\ state' = "rejected"
           /\ selectedPrefix' = "none"

Next ==
    \/ Compose
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ selectedPrefix \in STRING

PrefixSafety ==
    /\ state = "composed" => selectedPrefix = MPI_LAUNCHER
    /\ state = "rejected" => selectedPrefix = "none"

=============================================================================
