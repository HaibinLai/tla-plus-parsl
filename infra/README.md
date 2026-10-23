# Communication evidence runner

This is a small, deliberately finite implementation of the repository's
source-to-model evidence chain. The manifest covers three CommandClient
transport/concurrency findings: BUG-214, BUG-238, and BUG-239. It does not
replace the larger TLC or Python regression suites.

`communication-cases.json` pins the inspected Parsl revision and maps each
finding to a source symbol, TLA+ model, Current and Fixed configurations,
invariant, runtime probe, and canonical bug-ledger row. The validator checks
that each path exists, that the source symbol and invariant exist, that both
configs name the invariant, and that the ledger row names the model and probe.

To validate links only:

```sh
python3 infra/verify_cases.py --validate-only --parsl-source /path/to/pinned/parsl
```

To run the three complete cases:

```sh
python3 infra/verify_cases.py \
  --parsl-source /path/to/pinned/parsl \
  --java /path/to/java \
  --tla-jar /path/to/tla2tools.jar \
  --python /path/to/parsl-venv/bin/python \
  --output /path/to/local-results.json
```

The Current result counts as a pass only if TLC emits a trace naming the
manifest's exact invariant. A generic nonzero exit, parser error, or timeout
does not count. The Fixed result requires TLC's explicit no-error completion.
The Python probe must exit successfully. Run the runner tests with
`python3 -m unittest tests.test_infra_verify_cases`.

This validates *links and executable outcomes*, not exhaustive source fidelity
or the correctness of a proposed Parsl fix. The Fixed model is a candidate
protocol; these commands do not patch Parsl. Raw run results should be kept as
local or CI artifacts rather than committed as evergreen test claims.

On 2026-10-23, the three manifest cases passed locally against Parsl revision
`139caab94a7f2eb306512f9107b992c825974de8` and TLC 2.19: each Current
configuration produced the named invariant violation, each Fixed configuration
completed without error, and each Python probe exited successfully. The four
runner classification unit tests also passed. This dated result is a smoke
check, not a substitute for a fresh run in a new environment.
