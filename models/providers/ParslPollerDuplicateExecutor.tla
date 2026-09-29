--------------------------- MODULE ParslPollerDuplicateExecutor ---------------------------
EXTENDS Naturals, Sequences

(***************************************************************************
 * JobStatusPoller executor registration.
 *
 * add_executors stores pollable executors in a list.  The current method
 * appends every call, so repeated registration of the same executor causes
 * duplicate polling and duplicate scale-in work.  The fixed branch makes
 * registration idempotent.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES registrations, addCalls
vars == <<registrations, addCalls>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ registrations = <<>>
    /\ addCalls = 0

AddExecutor ==
    /\ addCalls < 2
    /\ registrations' =
          IF USE_FIXED
          THEN IF Len(registrations) = 0 THEN Append(registrations, "E")
               ELSE registrations
          ELSE Append(registrations, "E")
    /\ addCalls' = addCalls + 1

Next == AddExecutor \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ registrations \in Seq(STRING)
    /\ addCalls \in 0..2

UniqueExecutorRegistration ==
    Len(registrations) <= 1

=============================================================================
