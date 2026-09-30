--------------------------- MODULE ParslMPIMalformedResultCleanup ---------------------------
EXTENDS Naturals

(***************************************************************************
 * MPITaskScheduler.get_result decodes a worker payload before returning
 * allocated nodes.  A corrupt pickle currently escapes get_result; the
 * ferry loop catches it and continues, but the task allocation remains held
 * and no terminal result is delivered.  USE_FIXED releases the allocation
 * and publishes an explicit decode failure.
 *************************************************************************** *)

CONSTANT USE_FIXED

VARIABLES allocation, payload, phase
vars == <<allocation, payload, phase>>

Init ==
    /\ USE_FIXED \in BOOLEAN
    /\ allocation = "held"
    /\ payload = "corrupt"
    /\ phase = "queued"

DecodeResult ==
    /\ phase = "queued"
    /\ payload = "corrupt"
    /\ IF USE_FIXED
          THEN /\ allocation' = "released"
               /\ phase' = "failed"
          ELSE /\ allocation' = "held"
               /\ phase' = "decode-error"
    /\ UNCHANGED payload

Done ==
    /\ phase \in {"failed", "decode-error"}
    /\ UNCHANGED vars

Next == DecodeResult \/ Done
Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ USE_FIXED \in BOOLEAN
    /\ allocation \in {"held", "released"}
    /\ payload = "corrupt"
    /\ phase \in {"queued", "failed", "decode-error"}

NoDecodeLeak ==
    phase = "decode-error" => allocation = "released"

DecodeFailureTerminal ==
    phase = "failed" => allocation = "released"

=============================================================================
