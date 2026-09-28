--------------------------- MODULE ParslApplyMessageArity ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Arity of facade.unpack_apply_message.
 *
 * An apply message consists of exactly callable, args, and kwargs buffers.
 * The current unpacker returns every framed buffer and leaves arity failure
 * to execute_task's tuple assignment.  USE_FIXED models rejecting a count
 * other than three at the unpack boundary.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES frameCount, state
vars == <<frameCount, state>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ frameCount = 4
    /\ state = "wire"

Unpack ==
    /\ state = "wire"
    /\ state' = IF USE_FIXED /\ frameCount # 3 THEN "rejected" ELSE "unpacked"
    /\ UNCHANGED frameCount

Next ==
    \/ Unpack
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ frameCount \in Nat
    /\ state \in {"wire", "unpacked", "rejected"}

AritySafety ==
    state = "unpacked" => frameCount = 3

=============================================================================
