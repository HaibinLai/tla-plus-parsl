--------------------------- MODULE ParslBashAppOutcome ---------------------------
EXTENDS Integers

(***************************************************************************
 * Small model of parsl.app.bash.remote_side_bash_executor.
 * A bash app first runs a shell command, then checks declared output files,
 * and only then resolves its Future.  stdout is a side effect, not the
 * Future value.  A non-zero exit must prevent output validation/resolution.
 ***************************************************************************)

VARIABLES phase, exitCode, stdoutReady, outputReady, futureState
vars == <<phase, exitCode, stdoutReady, outputReady, futureState>>

Phases == {"new", "running", "exited", "validated", "resolved"}
FutureStates == {"pending", "success", "failure"}

Init ==
    /\ phase = "new"
    /\ exitCode = -1
    /\ stdoutReady = FALSE
    /\ outputReady = FALSE
    /\ futureState = "pending"

Start ==
    /\ phase = "new"
    /\ phase' = "running"
    /\ UNCHANGED <<exitCode, stdoutReady, outputReady, futureState>>

ExitSuccess ==
    /\ phase = "running"
    /\ exitCode' = 0
    /\ phase' = "exited"
    /\ UNCHANGED <<stdoutReady, outputReady, futureState>>

ExitFailure ==
    /\ phase = "running"
    /\ exitCode' \in (-10)..(-1)
    /\ phase' = "exited"
    /\ UNCHANGED <<stdoutReady, outputReady, futureState>>

WriteStdout ==
    /\ phase = "exited"
    /\ stdoutReady' = TRUE
    /\ UNCHANGED <<phase, exitCode, outputReady, futureState>>

ValidateOutputs ==
    /\ phase = "exited"
    /\ exitCode = 0
    /\ outputReady' = TRUE
    /\ phase' = "validated"
    /\ UNCHANGED <<exitCode, stdoutReady, futureState>>

ResolveSuccess ==
    /\ phase = "validated"
    /\ outputReady
    /\ futureState' = "success"
    /\ phase' = "resolved"
    /\ UNCHANGED <<exitCode, stdoutReady, outputReady>>

ResolveFailure ==
    /\ phase = "exited"
    /\ exitCode # 0
    /\ futureState' = "failure"
    /\ phase' = "resolved"
    /\ UNCHANGED <<exitCode, stdoutReady, outputReady>>

Next ==
    \/ Start
    \/ ExitSuccess
    \/ ExitFailure
    \/ WriteStdout
    \/ ValidateOutputs
    \/ ResolveSuccess
    \/ ResolveFailure
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in Phases
    /\ exitCode \in (-10)..0
    /\ stdoutReady \in BOOLEAN
    /\ outputReady \in BOOLEAN
    /\ futureState \in FutureStates

ExitGate == futureState = "success" => exitCode = 0
OutputGate == outputReady => exitCode = 0
FailureGate == futureState = "failure" => exitCode # 0
TerminalStable == futureState # "pending" => phase = "resolved"
StdoutDoesNotResolve == stdoutReady => futureState # "success" \/ outputReady

=============================================================================
SPECIFICATION Spec
INVARIANTS TypeOK ExitGate OutputGate FailureGate TerminalStable StdoutDoesNotResolve
