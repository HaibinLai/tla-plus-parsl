--------------------------- MODULE ParslNegativeScaleIn ---------------------------
EXTENDS Naturals

(***************************************************************************
 * BlockProviderExecutor.scale_in argument validation.
 *
 * The current implementation selects active_blocks[:blocks].  Python's
 * negative slice semantics turn blocks=-1 into every active block except the
 * last one, so an invalid request can cancel multiple blocks.  The fixed
 * branch rejects negative counts before selecting jobs.
 *************************************************************************** *)

CONSTANTS NEGATIVE_REQUEST, USE_FIXED
VARIABLES state, activeBlocks, cancelledBlocks
vars == <<state, activeBlocks, cancelledBlocks>>

Init ==
    /\ NEGATIVE_REQUEST \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "ready"
    /\ activeBlocks = 3
    /\ cancelledBlocks = 0

ScaleIn ==
    /\ state = "ready"
    /\ IF NEGATIVE_REQUEST /\ USE_FIXED
          THEN /\ state' = "rejected"
               /\ UNCHANGED <<activeBlocks, cancelledBlocks>>
          ELSE /\ state' = "scaled"
               /\ cancelledBlocks' = IF NEGATIVE_REQUEST
                                      THEN activeBlocks - 1
                                      ELSE 1
               /\ activeBlocks' = activeBlocks - cancelledBlocks'

Next == ScaleIn \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"ready", "rejected", "scaled"}
    /\ activeBlocks \in Nat
    /\ cancelledBlocks \in Nat

NoNegativeScaleInEffect == NEGATIVE_REQUEST => (cancelledBlocks = 0 \/ USE_FIXED)

=============================================================================
