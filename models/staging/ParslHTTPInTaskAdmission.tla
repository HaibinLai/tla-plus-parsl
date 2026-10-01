--------------------------- MODULE ParslHTTPInTaskAdmission ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Joint HTTP in-task admission contract.
 *
 * A response must have a successful status and must deliver exactly the
 * declared number of bytes before the wrapped user function may run.  The
 * Current branch represents the inspected wrapper, which ignores both
 * conditions; the Fixed branch rejects the transfer before task admission.
 ***************************************************************************)

CONSTANTS STATUS_OK, EXPECTED, RECEIVED, USE_FIXED

VARIABLES transfer, app
vars == <<transfer, app>>

Init ==
    /\ STATUS_OK \in BOOLEAN
    /\ EXPECTED \in 1..20
    /\ RECEIVED \in 0..20
    /\ USE_FIXED \in BOOLEAN
    /\ transfer = "fetching"
    /\ app = "blocked"

FinishFetch ==
    /\ transfer = "fetching"
    /\ IF USE_FIXED /\ STATUS_OK /\ RECEIVED = EXPECTED
          THEN /\ transfer' = "published"
               /\ app' = "ran"
          ELSE IF USE_FIXED
               THEN /\ transfer' = "rejected"
                    /\ app' = "blocked"
               ELSE /\ transfer' = "published"
                    /\ app' = "ran"

Next == FinishFetch \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ transfer \in {"fetching", "published", "rejected"}
    /\ app \in {"blocked", "ran"}

AdmissionSafety ==
    app = "ran" => STATUS_OK /\ RECEIVED = EXPECTED

=============================================================================
SPECIFICATION Spec

INVARIANTS
    TypeOK
    AdmissionSafety
