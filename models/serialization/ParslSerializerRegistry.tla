--------------------------- MODULE ParslSerializerRegistry ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Serializer registry dispatch.
 *
 * Parsl's facade checks methods_for_code before methods_for_data.  The normal
 * identifiers (C2 and 02) are disjoint, but a plugin or registration mistake
 * can collide.  The current branch decodes an ambiguous data payload as a
 * callable; the fixed branch rejects the ambiguous header.
 ***************************************************************************)

CONSTANTS CODE_ID, DATA_ID, WIRE_KIND, USE_FIXED

PayloadKinds == {"callable", "data"}
DispatchStates == {"none", "framed", "decoded", "rejected"}
DecodedKinds == {"none", "callable", "data"}

VARIABLES header, dispatchState, decodedKind
vars == <<header, dispatchState, decodedKind>>

Init ==
    /\ CODE_ID # ""
    /\ DATA_ID # ""
    /\ WIRE_KIND \in PayloadKinds
    /\ dispatchState = "none"
    /\ header = ""
    /\ decodedKind = "none"

Encode ==
    /\ dispatchState = "none"
    /\ header' = IF WIRE_KIND = "callable" THEN CODE_ID ELSE DATA_ID
    /\ dispatchState' = "framed"
    /\ UNCHANGED decodedKind

Deserialize ==
    /\ dispatchState = "framed"
    /\ IF USE_FIXED /\ CODE_ID = DATA_ID
       THEN /\ dispatchState' = "rejected"
            /\ decodedKind' = "none"
       ELSE IF header = CODE_ID
            THEN /\ dispatchState' = "decoded"
                 /\ decodedKind' = "callable"
            ELSE IF header = DATA_ID
                 THEN /\ dispatchState' = "decoded"
                      /\ decodedKind' = "data"
                 ELSE /\ dispatchState' = "rejected"
                      /\ decodedKind' = "none"
    /\ UNCHANGED header

Next ==
    \/ Encode
    \/ Deserialize
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ header \in {"", CODE_ID, DATA_ID}
    /\ dispatchState \in DispatchStates
    /\ decodedKind \in DecodedKinds

DispatchSafety ==
    dispatchState = "decoded" => decodedKind = WIRE_KIND

AmbiguitySafety ==
    CODE_ID = DATA_ID =>
        IF USE_FIXED THEN dispatchState # "decoded" ELSE TRUE

RejectionSafety ==
    dispatchState = "rejected" => decodedKind = "none"

=============================================================================
