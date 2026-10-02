-------------------- MODULE ParslZipDuplicateReadiness --------------------
EXTENDS Naturals

(***************************************************************************
 * Zip duplicate-member readiness.
 *
 * A stage-out cleanup failure can leave one archive member, and a retry can
 * append a second member with the same name.  ZipFile.read then returns the
 * latest bytes, so a stage-in/DataFuture can become ready while the archive
 * still has ambiguous history.  The fixed branch gates readiness on a unique
 * member name.
 *************************************************************************** *)

CONSTANT USE_FIXED

States == {"empty", "published", "retried", "ready", "rejected"}

VARIABLES state, memberCount, dataReady, consumerValue
vars == <<state, memberCount, dataReady, consumerValue>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ state = "empty"
    /\ memberCount = 0
    /\ dataReady = FALSE
    /\ consumerValue = "none"

PublishFirst ==
    /\ state = "empty"
    /\ state' = "published"
    /\ memberCount' = 1
    /\ UNCHANGED <<dataReady, consumerValue>>

RetryAfterCleanupFailure ==
    /\ state = "published"
    /\ state' = "retried"
    /\ memberCount' = 2
    /\ UNCHANGED <<dataReady, consumerValue>>

PublishReadiness ==
    /\ state \in {"published", "retried"}
    /\ IF USE_FIXED /\ memberCount = 1
          THEN state' = "ready"
               /\ dataReady' = TRUE
          ELSE IF USE_FIXED
               THEN state' = "rejected"
                    /\ dataReady' = FALSE
               ELSE state' = "ready"
                    /\ dataReady' = TRUE
    /\ UNCHANGED <<memberCount, consumerValue>>

Consume ==
    /\ state = "ready"
    /\ dataReady
    /\ state' = "ready"
    /\ consumerValue' = IF memberCount = 1 THEN "unique" ELSE "ambiguous"
    /\ UNCHANGED <<memberCount, dataReady>>

Next ==
    \/ PublishFirst
    \/ RetryAfterCleanupFailure
    \/ PublishReadiness
    \/ Consume
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in States
    /\ memberCount \in 0..2
    /\ dataReady \in BOOLEAN
    /\ consumerValue \in {"none", "unique", "ambiguous"}

ReadinessUniqueness == dataReady => memberCount = 1
ConsumerSafety == consumerValue # "ambiguous"

=============================================================================
