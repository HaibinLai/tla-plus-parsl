--------------------------- MODULE ParslPythonNestedAlias ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Nested Python object alias identity.
 *
 * The callable, a direct argument, and a nested field all reference one
 * source object.  The unsafe branch reconstructs separate objects for the
 * latter two roots; the fixed branch preserves the shared graph identity.
 ***************************************************************************)

CONSTANT USE_FIXED

Roots == {"callable", "argument", "nested"}
ObjectIds == {"O", "O1", "O2"}

VARIABLES phase, sourceRef, decodedRef

vars == <<phase, sourceRef, decodedRef>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "new"
    /\ sourceRef = [r \in Roots |-> "O"]
    /\ decodedRef = [r \in Roots |-> "O"]

Serialize ==
    /\ phase = "new"
    /\ phase' = "serialized"
    /\ UNCHANGED <<sourceRef, decodedRef>>

Decode ==
    /\ phase = "serialized"
    /\ phase' = "decoded"
    /\ decodedRef' =
        IF USE_FIXED
        THEN [r \in Roots |-> "O"]
        ELSE [r \in Roots |->
              IF r = "callable" THEN "O"
              ELSE IF r = "argument" THEN "O1" ELSE "O2"]
    /\ UNCHANGED sourceRef

Next ==
    \/ Serialize
    \/ Decode
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"new", "serialized", "decoded"}
    /\ sourceRef \in [Roots -> ObjectIds]
    /\ decodedRef \in [Roots -> ObjectIds]

NestedAliasSafety ==
    phase = "decoded" =>
        decodedRef["callable"] = decodedRef["argument"]
        /\ decodedRef["argument"] = decodedRef["nested"]

SourceGraphSafety ==
    \A r \in Roots : sourceRef[r] = "O"

=============================================================================
