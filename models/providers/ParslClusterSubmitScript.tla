--------------------------- MODULE ParslClusterSubmitScript ---------------------------
EXTENDS Naturals

(***************************************************************************
 * ClusterProvider._write_submit_script from parsl/providers/cluster_provider.py.
 *
 * Template substitution and file publication have distinct failure classes:
 * a missing template key becomes SchedulerMissingArgs, while an I/O failure
 * becomes ScriptPathError.  A valid template reaches the written state.
 ***************************************************************************)

CONSTANTS TEMPLATE_VALID, PATH_WRITABLE

States == {"ready", "written", "scheduler_error", "path_error"}
VARIABLES state, fileVisible
vars == <<state, fileVisible>>

Init ==
    /\ TEMPLATE_VALID \in BOOLEAN
    /\ PATH_WRITABLE \in BOOLEAN
    /\ state = "ready"
    /\ fileVisible = FALSE

WriteScript ==
    /\ state = "ready"
    /\ IF ~TEMPLATE_VALID
          THEN /\ state' = "scheduler_error"
               /\ UNCHANGED fileVisible
          ELSE IF ~PATH_WRITABLE
               THEN /\ state' = "path_error"
                    /\ UNCHANGED fileVisible
               ELSE /\ state' = "written"
                    /\ fileVisible' = TRUE

Next ==
    \/ WriteScript
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ TEMPLATE_VALID \in BOOLEAN
    /\ PATH_WRITABLE \in BOOLEAN
    /\ state \in States
    /\ fileVisible \in BOOLEAN

ErrorMappingSafety ==
    /\ state = "scheduler_error" => ~TEMPLATE_VALID /\ ~fileVisible
    /\ state = "path_error" => TEMPLATE_VALID /\ ~PATH_WRITABLE /\ ~fileVisible

PublicationSafety == state = "written" => TEMPLATE_VALID /\ PATH_WRITABLE /\ fileVisible

=============================================================================
