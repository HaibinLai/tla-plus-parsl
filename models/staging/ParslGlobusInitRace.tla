--------------------------- MODULE ParslGlobusInitRace ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Concurrent Globus staging initialization.
 *
 * Globus.init checks whether ~/.parsl exists and then calls os.mkdir.  Two
 * concurrent initializers can both observe absence; the second mkdir then
 * raises FileExistsError even though the desired directory is ready.  The
 * fixed branch treats that interleaving as successful initialization.
 ***************************************************************************)

CONSTANT USE_FIXED, DIRECTORY_ALREADY_CREATED

VARIABLES state, directoryReady
vars == <<state, directoryReady>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ DIRECTORY_ALREADY_CREATED \in BOOLEAN
    /\ state = "checking"
    /\ directoryReady = FALSE

CreateDirectory ==
    /\ state = "checking"
    /\ IF DIRECTORY_ALREADY_CREATED /\ ~USE_FIXED
          THEN /\ state' = "crashed"
               /\ directoryReady' = TRUE
          ELSE /\ state' = "ready"
               /\ directoryReady' = TRUE

Next == CreateDirectory \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ DIRECTORY_ALREADY_CREATED \in BOOLEAN
    /\ state \in {"checking", "ready", "crashed"}
    /\ directoryReady \in BOOLEAN

InitializationSafety == state # "crashed"

=============================================================================
