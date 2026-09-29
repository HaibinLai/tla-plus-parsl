--------------------------- MODULE ParslTimeLimitedOpenTimeout ---------------------------
EXTENDS Naturals

(***************************************************************************
 * time_limited_open file-wait boundary.
 *
 * wait_for_file currently yields after its polling horizon even when the
 * path never appears; time_limited_open then calls open() and exposes a raw
 * FileNotFoundError.  USE_FIXED models returning an explicit timeout before
 * attempting the open.
 *************************************************************************** *)

CONSTANT FILE_PRESENT, USE_FIXED

VARIABLES state, openAttempted
vars == <<state, openAttempted>>

Init ==
    /\ FILE_PRESENT \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state = "waiting"
    /\ openAttempted = FALSE

WaitCompletes ==
    /\ state = "waiting"
    /\ IF FILE_PRESENT
       THEN /\ state' = "opened"
            /\ openAttempted' = TRUE
       ELSE IF USE_FIXED
            THEN /\ state' = "timed-out"
                 /\ openAttempted' = FALSE
            ELSE /\ state' = "open-failed"
                 /\ openAttempted' = TRUE

Next ==
    \/ WaitCompletes
    \/ UNCHANGED vars

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ FILE_PRESENT \in BOOLEAN
    /\ USE_FIXED \in BOOLEAN
    /\ state \in {"waiting", "opened", "timed-out", "open-failed"}
    /\ openAttempted \in BOOLEAN

MissingFileSafety ==
    ~FILE_PRESENT /\ state # "waiting" => state = "timed-out"

NoOpenAfterTimeout ==
    state = "timed-out" => ~openAttempted

=============================================================================
