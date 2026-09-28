--------------------------- MODULE ParslPython ---------------------------
EXTENDS Naturals, FiniteSets, Sequences

(***************************************************************************
 * A small model of the Python object graph carried by a Parsl task.
 *
 * A callable is not modeled as an opaque boolean.  Its roots include a
 * function object and argument objects; edges represent globals, defaults,
 * closure cells, and nested references.  The encoder walks the graph before
 * producing a symbolic pickle token, and the decoder walks it again before
 * exposing a reconstructed callable/payload.
 ***************************************************************************)

CONSTANTS TASKS, OBJECTS, FUNCTION_OBJECTS, GLOBAL_OBJECTS,
          DEFAULT_OBJECTS, CLOSURE_OBJECTS, ARGUMENT_OBJECTS,
          TASK_ROOTS, OBJECT_EDGES, SERIALIZABLE_OBJECTS

PHASES == {"none", "encoding", "encoded", "decoding", "decoded", "failed"}
Kinds == FUNCTION_OBJECTS \cup GLOBAL_OBJECTS \cup DEFAULT_OBJECTS
         \cup CLOSURE_OBJECTS \cup ARGUMENT_OBJECTS

Roots(t) == {o \in OBJECTS : (t \o "::" \o o) \in TASK_ROOTS}
Children(o) == {c \in OBJECTS : (o \o "->" \o c) \in OBJECT_EDGES}
PickleToken(t) == t \o ":pickle-payload"

VARIABLES phase, encPending, encVisited, decPending, decVisited,
          payloadToken, wireValid, objectOK

vars == <<phase, encPending, encVisited, decPending, decVisited,
           payloadToken, wireValid, objectOK>>

Init ==
    /\ TASKS # {}
    /\ OBJECTS # {}
    /\ FUNCTION_OBJECTS \subseteq OBJECTS
    /\ GLOBAL_OBJECTS \subseteq OBJECTS
    /\ DEFAULT_OBJECTS \subseteq OBJECTS
    /\ CLOSURE_OBJECTS \subseteq OBJECTS
    /\ ARGUMENT_OBJECTS \subseteq OBJECTS
    /\ Kinds \subseteq OBJECTS
    /\ TASK_ROOTS \subseteq {(t \o "::" \o o) : t \in TASKS, o \in OBJECTS}
    /\ OBJECT_EDGES \subseteq {(o \o "->" \o c) : o \in OBJECTS, c \in OBJECTS}
    /\ SERIALIZABLE_OBJECTS \subseteq OBJECTS
    /\ \A t \in TASKS : Roots(t) \cap FUNCTION_OBJECTS # {}
    /\ \A t \in TASKS : Roots(t) \cap ARGUMENT_OBJECTS # {}
    /\ phase = [t \in TASKS |-> "none"]
    /\ encPending = [t \in TASKS |-> {}]
    /\ encVisited = [t \in TASKS |-> {}]
    /\ decPending = [t \in TASKS |-> {}]
    /\ decVisited = [t \in TASKS |-> {}]
    /\ payloadToken = [t \in TASKS |-> "none"]
    /\ wireValid = [t \in TASKS |-> TRUE]
    /\ objectOK = [o \in OBJECTS |-> o \in SERIALIZABLE_OBJECTS]

StartEncode(t) ==
    /\ phase[t] = "none"
    /\ phase' = [phase EXCEPT ![t] = "encoding"]
    /\ encPending' = [encPending EXCEPT ![t] = Roots(t)]
    /\ encVisited' = [encVisited EXCEPT ![t] = {}]
    /\ UNCHANGED <<decPending, decVisited, payloadToken, wireValid, objectOK>>

EncodeObject(t, o) ==
    /\ phase[t] = "encoding"
    /\ o \in encPending[t]
    /\ LET newPending == (encPending[t] \ {o})
                         \cup (Children(o) \ (encVisited[t] \cup {o}))
           newVisited == encVisited[t] \cup {o}
       IN
           /\ IF objectOK[o]
                 THEN phase' = phase
                 ELSE phase' = [phase EXCEPT ![t] = "failed"]
           /\ encPending' = [encPending EXCEPT ![t] =
                                  IF objectOK[o] THEN newPending ELSE {}]
           /\ encVisited' = [encVisited EXCEPT ![t] = newVisited]
    /\ UNCHANGED <<decPending, decVisited, payloadToken, wireValid, objectOK>>

FinishEncode(t) ==
    /\ phase[t] = "encoding"
    /\ encPending[t] = {}
    /\ phase' = [phase EXCEPT ![t] = "encoded"]
    /\ payloadToken' = [payloadToken EXCEPT ![t] = PickleToken(t)]
    /\ UNCHANGED <<encPending, encVisited, decPending, decVisited,
                    wireValid, objectOK>>

CorruptPayload(t) ==
    /\ phase[t] = "encoded"
    /\ wireValid[t]
    /\ wireValid' = [wireValid EXCEPT ![t] = FALSE]
    /\ UNCHANGED <<phase, encPending, encVisited, decPending, decVisited,
                    payloadToken, objectOK>>

RepairPayload(t) ==
    /\ phase[t] = "encoded"
    /\ ~wireValid[t]
    /\ wireValid' = [wireValid EXCEPT ![t] = TRUE]
    /\ UNCHANGED <<phase, encPending, encVisited, decPending, decVisited,
                    payloadToken, objectOK>>

StartDecode(t) ==
    /\ phase[t] = "encoded"
    /\ wireValid[t]
    /\ phase' = [phase EXCEPT ![t] = "decoding"]
    /\ decPending' = [decPending EXCEPT ![t] = Roots(t)]
    /\ decVisited' = [decVisited EXCEPT ![t] = {}]
    /\ UNCHANGED <<encPending, encVisited, payloadToken, wireValid, objectOK>>

DecodeObject(t, o) ==
    /\ phase[t] = "decoding"
    /\ o \in decPending[t]
    /\ objectOK[o]
    /\ LET newPending == (decPending[t] \ {o})
                         \cup (Children(o) \ (decVisited[t] \cup {o}))
           newVisited == decVisited[t] \cup {o}
       IN
           /\ decPending' = [decPending EXCEPT ![t] = newPending]
           /\ decVisited' = [decVisited EXCEPT ![t] = newVisited]
    /\ UNCHANGED <<phase, encPending, encVisited, payloadToken, wireValid,
                    objectOK>>

DecodeFailure(t, o) ==
    /\ phase[t] = "decoding"
    /\ o \in decPending[t]
    /\ ~objectOK[o]
    /\ phase' = [phase EXCEPT ![t] = "failed"]
    /\ decPending' = [decPending EXCEPT ![t] = {}]
    /\ UNCHANGED <<encPending, encVisited, decVisited, payloadToken,
                    wireValid, objectOK>>

FinishDecode(t) ==
    /\ phase[t] = "decoding"
    /\ decPending[t] = {}
    /\ phase' = [phase EXCEPT ![t] = "decoded"]
    /\ UNCHANGED <<encPending, encVisited, decPending, decVisited,
                    payloadToken, wireValid, objectOK>>

MutateObject(o) ==
    /\ objectOK[o]
    /\ \A t \in TASKS : phase[t] = "none"
    /\ objectOK' = [objectOK EXCEPT ![o] = FALSE]
    /\ UNCHANGED <<phase, encPending, encVisited, decPending, decVisited,
                    payloadToken, wireValid>>

RepairObject(o) ==
    /\ ~objectOK[o]
    /\ objectOK' = [objectOK EXCEPT ![o] = TRUE]
    /\ UNCHANGED <<phase, encPending, encVisited, decPending, decVisited,
                    payloadToken, wireValid>>

Next ==
    \/ \E t \in TASKS : StartEncode(t)
    \/ \E t \in TASKS, o \in OBJECTS : EncodeObject(t, o)
    \/ \E t \in TASKS : FinishEncode(t)
    \/ \E t \in TASKS : CorruptPayload(t)
    \/ \E t \in TASKS : RepairPayload(t)
    \/ \E t \in TASKS : StartDecode(t)
    \/ \E t \in TASKS, o \in OBJECTS : DecodeObject(t, o)
    \/ \E t \in TASKS, o \in OBJECTS : DecodeFailure(t, o)
    \/ \E t \in TASKS : FinishDecode(t)
    \/ \E o \in OBJECTS : MutateObject(o)
    \/ \E o \in OBJECTS : RepairObject(o)
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in [TASKS -> PHASES]
    /\ encPending \in [TASKS -> SUBSET OBJECTS]
    /\ encVisited \in [TASKS -> SUBSET OBJECTS]
    /\ decPending \in [TASKS -> SUBSET OBJECTS]
    /\ decVisited \in [TASKS -> SUBSET OBJECTS]
    /\ payloadToken \in [TASKS -> ( {"none"} \cup {PickleToken(t) : t \in TASKS} )]
    /\ wireValid \in [TASKS -> BOOLEAN]
    /\ objectOK \in [OBJECTS -> BOOLEAN]

FunctionContentSafety ==
    \A t \in TASKS :
        phase[t] \in {"encoded", "decoding", "decoded"}
        => Roots(t) \subseteq encVisited[t]

SerializationSafety ==
    \A t \in TASKS :
        phase[t] \in {"encoded", "decoding", "decoded"}
        => encVisited[t] \subseteq {o \in OBJECTS : objectOK[o]}

FailureSafety ==
    \A t \in TASKS :
        phase[t] = "failed" => payloadToken[t] = "none"

RoundTripSafety ==
    \A t \in TASKS :
        phase[t] = "decoded"
        => /\ payloadToken[t] = PickleToken(t)
           /\ wireValid[t]
           /\ decVisited[t] = encVisited[t]

ObjectKindSafety ==
    \A t \in TASKS :
        /\ Roots(t) \cap FUNCTION_OBJECTS # {}
        /\ Roots(t) \cap ARGUMENT_OBJECTS # {}
        /\ (phase[t] = "decoded" =>
              encVisited[t] \cap (GLOBAL_OBJECTS \cup DEFAULT_OBJECTS
                                  \cup CLOSURE_OBJECTS)
              = decVisited[t] \cap (GLOBAL_OBJECTS \cup DEFAULT_OBJECTS
                                    \cup CLOSURE_OBJECTS))

=============================================================================
