--------------------------- MODULE ParslCondorSubmitWhitespace ---------------------------
EXTENDS Naturals

(***************************************************************************
 * Condor submit output contains human-readable whitespace.  The current
 * parser uses fixed positions after ``split(" ")``; repeated spaces insert
 * empty tokens and produce the literal cluster token instead of the numeric
 * cluster ID.  USE_FIXED models whitespace-normalizing tokenization.
 ***************************************************************************)

CONSTANT USE_FIXED

VARIABLES phase, firstJobId
vars == <<phase, firstJobId>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ phase = "ready"
    /\ firstJobId = "none"

SubmitWithRepeatedSpaces ==
    /\ phase = "ready"
    /\ phase' = "submitted"
    /\ firstJobId' = IF USE_FIXED THEN "118907.0" ELSE "cluster0"

Next == SubmitWithRepeatedSpaces \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ phase \in {"ready", "submitted"}
    /\ firstJobId \in {"none", "118907.0", "cluster0"}

JobIdSafety ==
    phase = "submitted" => firstJobId = "118907.0"

=============================================================================
