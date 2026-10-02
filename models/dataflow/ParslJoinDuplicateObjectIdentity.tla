--------------------------- MODULE ParslJoinDuplicateObjectIdentity ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Duplicate join positions and Python object identity.
 *
 * handle_join_update iterates the concrete Future list and appends each
 * future.result() to the output list.  If one Future appears twice, both
 * positions therefore refer to the same returned Python object.  This is
 * distinct from merely preserving equal serialized values.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES innerDone, outerDone, resultAlias
vars == <<innerDone, outerDone, resultAlias>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ innerDone = FALSE
    /\ outerDone = FALSE
    /\ resultAlias = FALSE

CompleteInner ==
    /\ ~innerDone
    /\ innerDone' = TRUE
    /\ UNCHANGED <<outerDone, resultAlias>>

FinalizeDuplicateJoin ==
    /\ innerDone
    /\ ~outerDone
    /\ outerDone' = TRUE
    /\ resultAlias' = USE_FIXED
    /\ UNCHANGED innerDone

Next ==
    \/ CompleteInner
    \/ FinalizeDuplicateJoin
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ innerDone \in BOOLEAN
    /\ outerDone \in BOOLEAN
    /\ resultAlias \in BOOLEAN

AliasPreservation ==
    outerDone => resultAlias

=============================================================================
