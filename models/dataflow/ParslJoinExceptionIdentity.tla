--------------------------- MODULE ParslJoinExceptionIdentity ---------------------------
EXTENDS Naturals

(***************************************************************************
 * JoinError exception identity.
 *
 * DataFlowKernel.handle_join_update collects the actual exception objects
 * from completed inner Futures.  JoinError then preserves the first leaf
 * exception as __cause__, while annotating additional sibling failures in
 * the rendered path.  The model distinguishes object identity from merely
 * equal exception text.
 ***************************************************************************)

CONSTANT USE_FIXED, MAX_SIBLINGS

States == {"pending", "inner_built", "outer_built"}

VARIABLES state, leafId, innerCauseId, outerCauseId, siblingCount
vars == <<state, leafId, innerCauseId, outerCauseId, siblingCount>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ MAX_SIBLINGS > 0
    /\ state = "pending"
    /\ leafId = "leaf-7"
    /\ innerCauseId = "unset"
    /\ outerCauseId = "unset"
    /\ siblingCount = 0

BuildInner ==
    /\ state = "pending"
    /\ innerCauseId' = leafId
    /\ state' = "inner_built"
    /\ UNCHANGED <<leafId, outerCauseId, siblingCount>>

BuildOuter ==
    /\ state = "inner_built"
    /\ outerCauseId' = IF USE_FIXED THEN innerCauseId ELSE "copied-leaf"
    /\ siblingCount' = 1
    /\ state' = "outer_built"
    /\ UNCHANGED <<leafId, innerCauseId>>

DuplicateCallback ==
    /\ state = "outer_built"
    /\ siblingCount < MAX_SIBLINGS
    /\ siblingCount' = siblingCount + 1
    /\ UNCHANGED <<state, leafId, innerCauseId, outerCauseId>>

Next ==
    \/ BuildInner
    \/ BuildOuter
    \/ DuplicateCallback
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ MAX_SIBLINGS > 0
    /\ state \in States
    /\ leafId = "leaf-7"
    /\ innerCauseId \in {"unset", "leaf-7"}
    /\ outerCauseId \in {"unset", "leaf-7", "copied-leaf"}
    /\ siblingCount \in 0..MAX_SIBLINGS

ExceptionIdentitySafety ==
    state = "outer_built" =>
        /\ innerCauseId = leafId
        /\ (USE_FIXED => outerCauseId = innerCauseId)

SiblingAnnotationSafety ==
    state = "outer_built" => siblingCount >= 1

=============================================================================
