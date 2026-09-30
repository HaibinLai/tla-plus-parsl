--------------------------- MODULE ParslAppFutureOutputStreams ---------------------------
EXTENDS Naturals

(***************************************************************************
 * AppFuture stdout/stderr property semantics.
 *
 * AppFuture returns an explicitly installed DataFuture when separate stage-out
 * created one; otherwise it exposes the original value from task_record.kwargs.
 * The original value may be None, a string, or an opaque tuple.  This model
 * records the current contract without assuming tuple stage-out semantics.
 ***************************************************************************)

CONSTANT STREAM_KIND, HAS_STAGED_FUTURE

Kinds == {"none", "string", "tuple"}
States == {"created", "observed"}

VARIABLES state, propertyValue, exposedValue
vars == <<state, propertyValue, exposedValue>>

Init ==
    /\ STREAM_KIND \in Kinds
    /\ HAS_STAGED_FUTURE \in BOOLEAN
    /\ state = "created"
    /\ propertyValue = IF HAS_STAGED_FUTURE THEN "datafuture" ELSE STREAM_KIND
    /\ exposedValue = "unobserved"

Observe ==
    /\ state = "created"
    /\ state' = "observed"
    /\ exposedValue' = propertyValue
    /\ UNCHANGED <<propertyValue>>

Next ==
    \/ Observe
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ STREAM_KIND \in Kinds
    /\ HAS_STAGED_FUTURE \in BOOLEAN
    /\ state \in States
    /\ propertyValue \in Kinds \cup {"datafuture"}
    /\ exposedValue \in Kinds \cup {"datafuture", "unobserved"}

ObservationSafety ==
    state = "observed" => exposedValue = propertyValue

StageOutOverrideSafety ==
    HAS_STAGED_FUTURE => propertyValue = "datafuture"

=============================================================================
