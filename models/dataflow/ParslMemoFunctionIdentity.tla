--------------------------- MODULE ParslMemoFunctionIdentity ---------------------------
EXTENDS Naturals

(***************************************************************************
 * BasicMemoizer.id_for_memo_function currently identifies a function by only
 * __name__ and __module__.  A changed function body can therefore reuse an
 * old checkpoint.  The FIXED branch includes a symbolic source/version id.
 *************************************************************************** *)

CONSTANTS CHANGE_SOURCE, USE_FIXED

VARIABLES state, sourceVersion, memoKey

Init ==
    /\ CHANGE_SOURCE \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "old"
    /\ sourceVersion = 0
    /\ memoKey = "old-key"

ChangeSource ==
    /\ state = "old"
    /\ state' = "new"
    /\ sourceVersion' = IF CHANGE_SOURCE THEN 1 ELSE 0
    /\ memoKey' = IF CHANGE_SOURCE /\ USE_FIXED THEN "new-key" ELSE "old-key"

Next ==
    \/ ChangeSource
    \/ UNCHANGED <<state, sourceVersion, memoKey>>

vars == <<state, sourceVersion, memoKey>>
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"old", "new"}
    /\ sourceVersion \in Nat
    /\ memoKey \in {"old-key", "new-key"}

MemoKeySafety ==
    CHANGE_SOURCE /\ sourceVersion = 1 => memoKey = "new-key"

=============================================================================
