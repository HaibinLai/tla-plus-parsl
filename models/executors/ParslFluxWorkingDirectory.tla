--------------------------- MODULE ParslFluxWorkingDirectory ---------------------------
EXTENDS Naturals, Sequences

(***************************************************************************
 * The Flux executor writes task files below workingDir, but the current
 * _submit_single_job path sets JobspecV1.cwd from the submitting process's
 * current directory.  A relative task path can therefore resolve outside the
 * configured executor directory.  USE_FIXED models propagating workingDir.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES workingDir, callerDir, jobCwd, relativePath, resolvedPath
vars == <<workingDir, callerDir, jobCwd, relativePath, resolvedPath>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ workingDir = "/executor-work"
    /\ callerDir = "/submitter"
    /\ jobCwd = ""
    /\ relativePath = "result.txt"
    /\ resolvedPath = ""

ComposeJob ==
    /\ jobCwd' = IF USE_FIXED THEN workingDir ELSE callerDir
    /\ UNCHANGED <<workingDir, callerDir, relativePath, resolvedPath>>

ResolveRelativePath ==
    /\ jobCwd # ""
    /\ resolvedPath' = jobCwd \o "/" \o relativePath
    /\ UNCHANGED <<workingDir, callerDir, jobCwd, relativePath>>

Next == ComposeJob \/ ResolveRelativePath \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ workingDir \in STRING
    /\ callerDir \in STRING
    /\ jobCwd \in STRING
    /\ relativePath \in STRING
    /\ resolvedPath \in STRING

WorkingDirectorySafety ==
    resolvedPath = "" \/ resolvedPath = workingDir \o "/" \o relativePath

=============================================================================
