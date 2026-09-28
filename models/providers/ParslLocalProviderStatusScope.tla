--------------------------- MODULE ParslLocalProviderStatusScope ---------------------------
EXTENDS Naturals, FiniteSets

(***************************************************************************
 * LocalProvider.status scope model.
 *
 * The public method accepts a requested job-id set, but the current loop
 * iterates over every entry in ``resources`` before returning the requested
 * statuses.  A stale unrelated resource can therefore fail an otherwise
 * valid query.  USE_FIXED models iterating only over requested IDs.
 ***************************************************************************)

CONSTANT USE_FIXED
JOBS == {"requested", "stale"}
Markers == {"valid", "missing"}

VARIABLES requested, marker, observed, queryOK
vars == <<requested, marker, observed, queryOK>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ requested = {"requested"}
    /\ marker = [j \in JOBS |-> IF j = "requested" THEN "valid" ELSE "missing"]
    /\ observed = [j \in JOBS |-> "none"]
    /\ queryOK = FALSE

Poll ==
    /\ queryOK = FALSE
    /\ IF USE_FIXED
          THEN /\ observed' = [observed EXCEPT !["requested"] = marker["requested"]]
               /\ queryOK' = TRUE
          ELSE /\ observed' = [j \in JOBS |-> marker[j]]
               /\ queryOK' = TRUE
    /\ UNCHANGED <<requested, marker>>

Next ==
    \/ Poll
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ requested \subseteq JOBS
    /\ marker \in [JOBS -> Markers]
    /\ observed \in [JOBS -> (Markers \cup {"none"})]
    /\ queryOK \in BOOLEAN

RequestedOnlySafety ==
    queryOK => observed["stale"] = "none"

QueryCompletionSafety ==
    queryOK => observed["requested"] = "valid"

=============================================================================
