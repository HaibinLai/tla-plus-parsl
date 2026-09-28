--------------------------- MODULE ParslFilePathResolution ---------------------------
EXTENDS Naturals

(***************************************************************************
 * File.filepath resolution in parsl/data_provider/files.py.
 *
 * A File has immutable URL metadata and a mutable site-local annotation.
 * The annotation wins when present.  A local file: URL can be used without
 * staging; a remote URL must have a local_path before an app can read it.
 ***************************************************************************)

Schemes == {"file", "https", "ftp", "globus"}
Paths == {"/input", "/worker/input", "none"}
Resolutions == {"unresolved", "local", "staged", "error"}

VARIABLES scheme, localPath, resolution, readAllowed
vars == <<scheme, localPath, resolution, readAllowed>>

Init ==
    /\ scheme = "file"
    /\ localPath = "none"
    /\ resolution = "unresolved"
    /\ readAllowed = FALSE

AttachRemoteURL ==
    /\ resolution = "unresolved"
    /\ scheme = "file"
    /\ scheme' = "https"
    /\ localPath' = localPath
    /\ resolution' = resolution
    /\ readAllowed' = readAllowed

AnnotateLocalPath ==
    /\ resolution = "unresolved"
    /\ localPath = "none"
    /\ scheme \in Schemes
    /\ localPath' = "/worker/input"
    /\ UNCHANGED <<scheme, resolution, readAllowed>>

ResolveFileURL ==
    /\ resolution = "unresolved"
    /\ scheme = "file"
    /\ localPath = "none"
    /\ resolution' = "local"
    /\ readAllowed' = TRUE
    /\ UNCHANGED <<scheme, localPath>>

ResolveStagedPath ==
    /\ resolution = "unresolved"
    /\ localPath # "none"
    /\ resolution' = "staged"
    /\ readAllowed' = TRUE
    /\ UNCHANGED <<scheme, localPath>>

RejectUnstagedRemote ==
    /\ resolution = "unresolved"
    /\ scheme # "file"
    /\ localPath = "none"
    /\ resolution' = "error"
    /\ readAllowed' = FALSE
    /\ UNCHANGED <<scheme, localPath>>

Next ==
    \/ AttachRemoteURL
    \/ AnnotateLocalPath
    \/ ResolveFileURL
    \/ ResolveStagedPath
    \/ RejectUnstagedRemote
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ scheme \in Schemes
    /\ localPath \in Paths
    /\ resolution \in Resolutions
    /\ readAllowed \in BOOLEAN

ResolutionSafety ==
    /\ resolution = "local" => scheme = "file" /\ localPath = "none"
    /\ resolution = "staged" => localPath # "none"
    /\ resolution = "error" => ~readAllowed

NoRemoteGuess ==
    resolution = "unresolved" /\ scheme # "file" /\ localPath = "none"
        => ~readAllowed

=============================================================================
