--------------------------- MODULE ParslHtexTaskResourceSpecType ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX task-message object typing.
 *
 * The task path accepts a decoded Python object and calls .get on
 * context.resource_spec.  A serialized task with a non-mapping resource_spec
 * therefore escapes the interchange loop.  USE_FIXED models rejecting the
 * object before queue insertion.
 ***************************************************************************)

CONSTANT USE_FIXED
VARIABLES resourceSpec, state, queued
vars == <<resourceSpec, state, queued>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ resourceSpec = "list"
    /\ state = "ready"
    /\ queued = 0

Receive ==
    /\ state = "ready"
    /\ state' = IF USE_FIXED THEN "ignored" ELSE "crashed"
    /\ queued' = 0
    /\ UNCHANGED resourceSpec

Next == Receive \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ resourceSpec = "list"
    /\ state \in {"ready", "ignored", "crashed"}
    /\ queued = 0

ResourceSpecTypingSafety == state # "crashed"
=============================================================================
