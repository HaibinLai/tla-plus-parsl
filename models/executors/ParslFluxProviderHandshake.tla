--------------------------- MODULE ParslFluxProviderHandshake ---------------------------
EXTENDS Naturals

(***************************************************************************
 * FluxExecutor startup handshake.
 *
 * The executor first provisions a provider job, then waits for two messages
 * from the remote manager: the Flux package path and the Flux instance URI.
 * The concrete _check_provider_job helper polls provider.status only when the
 * ZMQ socket has no message.  This small model makes the resulting race
 * explicit: a queued handshake message can be accepted after the provider
 * has already become terminal.  The Fixed branch validates provider liveness
 * before publishing executor readiness.
 ***************************************************************************)

CONSTANT USE_FIXED

ProviderStates == {"active", "terminal"}
Phases == {"await_package", "await_uri", "ready", "failed"}

VARIABLES provider, phase, packageMessage, uriMessage, executorReady,
          startupFailure, taskQueued, taskState
vars == <<provider, phase, packageMessage, uriMessage, executorReady,
          startupFailure, taskQueued, taskState>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ provider = "active"
    /\ phase = "await_package"
    /\ packageMessage = FALSE
    /\ uriMessage = FALSE
    /\ executorReady = FALSE
    /\ startupFailure = FALSE
    /\ taskQueued = FALSE
    /\ taskState = "none"

ProviderTerminates ==
    /\ provider = "active"
    /\ provider' = "terminal"
    /\ executorReady' = IF USE_FIXED THEN FALSE ELSE executorReady
    /\ taskQueued' = IF USE_FIXED THEN FALSE ELSE taskQueued
    /\ taskState' = IF USE_FIXED /\ taskState = "queued"
                       THEN "failed" ELSE taskState
    /\ UNCHANGED <<phase, packageMessage, uriMessage, startupFailure>>

PackageArrives ==
    /\ phase = "await_package"
    /\ packageMessage = FALSE
    /\ packageMessage' = TRUE
    /\ UNCHANGED <<provider, phase, uriMessage, executorReady,
                    startupFailure, taskQueued, taskState>>

AcceptPackage ==
    /\ phase = "await_package"
    /\ packageMessage
    /\ IF USE_FIXED /\ provider = "terminal"
          THEN /\ phase' = "failed"
               /\ startupFailure' = TRUE
               /\ UNCHANGED executorReady
          ELSE /\ phase' = "await_uri"
               /\ startupFailure' = FALSE
               /\ UNCHANGED executorReady
    /\ packageMessage' = FALSE
    /\ UNCHANGED <<provider, uriMessage, taskQueued, taskState>>

UriArrives ==
    /\ phase = "await_uri"
    /\ uriMessage = FALSE
    /\ uriMessage' = TRUE
    /\ UNCHANGED <<provider, phase, packageMessage, executorReady,
                    startupFailure, taskQueued, taskState>>

AcceptUri ==
    /\ phase = "await_uri"
    /\ uriMessage
    /\ IF USE_FIXED /\ provider = "terminal"
          THEN /\ phase' = "failed"
               /\ startupFailure' = TRUE
               /\ executorReady' = FALSE
          ELSE /\ phase' = "ready"
               /\ startupFailure' = FALSE
               /\ executorReady' = TRUE
    /\ uriMessage' = FALSE
    /\ UNCHANGED <<provider, packageMessage, taskQueued, taskState>>

PollProviderFailure ==
    /\ provider = "terminal"
    /\ phase \in {"await_package", "await_uri"}
    /\ phase' = "failed"
    /\ startupFailure' = TRUE
    /\ executorReady' = FALSE
    /\ UNCHANGED <<provider, packageMessage, uriMessage, taskQueued, taskState>>

QueueTask ==
    /\ phase = "ready"
    /\ executorReady
    /\ ~taskQueued
    /\ taskQueued' = TRUE
    /\ taskState' = "queued"
    /\ UNCHANGED <<provider, phase, packageMessage, uriMessage, executorReady,
                    startupFailure>>

RunTask ==
    /\ taskQueued
    /\ executorReady
    /\ taskState = "queued"
    /\ taskState' = "done"
    /\ UNCHANGED <<provider, phase, packageMessage, uriMessage, executorReady,
                    startupFailure, taskQueued>>

Next ==
    \/ ProviderTerminates
    \/ PackageArrives
    \/ AcceptPackage
    \/ UriArrives
    \/ AcceptUri
    \/ PollProviderFailure
    \/ QueueTask
    \/ RunTask
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ provider \in ProviderStates
    /\ phase \in Phases
    /\ packageMessage \in BOOLEAN
    /\ uriMessage \in BOOLEAN
    /\ executorReady \in BOOLEAN
    /\ startupFailure \in BOOLEAN
    /\ taskQueued \in BOOLEAN
    /\ taskState \in {"none", "queued", "done", "failed"}

NoReadyAfterProviderTermination ==
    provider = "terminal" => ~executorReady

NoTaskBeforeReady ==
    taskState = "queued" => executorReady

StartupFailureIsTerminal ==
    startupFailure => phase = "failed" /\ ~executorReady

=============================================================================
