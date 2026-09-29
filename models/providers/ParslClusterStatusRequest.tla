--------------------------- MODULE ParslClusterStatusRequest ---------------------------
EXTENDS Naturals, Sequences

(***************************************************************************
 * Common ClusterProvider.status API semantics.
 *
 * The provider-specific _status poll updates local resource records once per
 * API call.  The public result is then projected in the caller's requested
 * sequence, so duplicate job IDs remain duplicate output positions.
 ***************************************************************************)

Jobs == {"J1", "J2"}
Request == <<"J1", "J1", "J2">>
Statuses == {"PENDING", "RUNNING", "COMPLETED"}

VARIABLES pollCount, resources, result
vars == <<pollCount, resources, result>>

Init ==
    /\ pollCount = 0
    /\ resources = [j \in Jobs |-> "PENDING"]
    /\ result = <<>>

PollAndProject ==
    /\ pollCount = 0
    /\ pollCount' = 1
    /\ resources' = [j \in Jobs |-> "RUNNING"]
    /\ result' = <<"RUNNING", "RUNNING", "RUNNING">>

Next ==
    \/ PollAndProject
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ pollCount \in 0..1
    /\ resources \in [Jobs -> Statuses]
    /\ result \in Seq(Statuses)

SingleBackendPoll == pollCount = 1 => Len(result) = Len(Request)
DuplicateProjection == Len(result) = Len(Request) => result[1] = result[2]
OrderProjection == Len(result) = Len(Request) => result[3] = resources["J2"]

=============================================================================
