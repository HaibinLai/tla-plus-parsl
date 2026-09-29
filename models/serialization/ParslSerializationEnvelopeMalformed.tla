--------------------------- MODULE ParslSerializationEnvelopeMalformed ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Serializer envelope framing.
 *
 * deserialize expects a serializer header followed by a newline and body.
 * An empty or truncated payload currently raises a raw split/unpack error;
 * USE_FIXED models converting malformed framing into a uniform decode
 * failure without attempting plugin loading.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES payload, state
vars == <<payload, state>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ payload = "no-header"
    /\ state = "received"

Decode ==
    /\ state = "received"
    /\ state' = IF USE_FIXED THEN "rejected" ELSE "crashed"
    /\ UNCHANGED payload

Next == Decode \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ payload = "no-header"
    /\ state \in {"received", "rejected", "crashed"}

EnvelopeSafety == state # "crashed"
=============================================================================
