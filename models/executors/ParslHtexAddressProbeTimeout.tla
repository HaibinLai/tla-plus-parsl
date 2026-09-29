--------------------------- MODULE ParslHtexAddressProbeTimeout ---------------------------
EXTENDS Naturals

(***************************************************************************
 * HTEX address probe timeout propagation.
 *
 * A configured timeout is rendered into the worker launch command.  The
 * current executor uses a truthiness check, so an explicit zero is omitted
 * and the worker-side CLI default is silently used instead.
 ***************************************************************************)

CONSTANTS TIMEOUT_KIND, USE_FIXED
VARIABLE state, emittedTimeout
vars == <<state, emittedTimeout>>

Init ==
    /\ TIMEOUT_KIND \in {"none", "zero", "positive"}
    /\ USE_FIXED \in BOOLEAN
    /\ state = "configured"
    /\ emittedTimeout = FALSE

ComposeCommand ==
    /\ state = "configured"
    /\ state' = "command-ready"
    /\ emittedTimeout' =
          IF TIMEOUT_KIND = "positive" THEN TRUE
          ELSE IF TIMEOUT_KIND = "zero" THEN USE_FIXED
          ELSE FALSE

Next == ComposeCommand \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ state \in {"configured", "command-ready"}
    /\ emittedTimeout \in BOOLEAN

TimeoutPropagationSafety ==
    state = "command-ready" /\ TIMEOUT_KIND # "none" => emittedTimeout

=============================================================================
