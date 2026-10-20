# Text Networks and Bug-to-Validation Workflow

## Term network

`docs/ai4tla-text-network.json` contains adjacent bigrams and same-output
co-occurrence edges extracted from exposed session text. The visualization is
`site/dist/text-cooccurrence-network.svg`. Its nodes are high-degree technical
terms and its edges show how often two terms appeared together in one output.

The strongest adjacent phrases include `runtime probe`, `current fixed`,
`fixed TLC`, `TLC runtime`, `executor provider`, and `bug ledger`. These are
descriptive associations, not semantic or causal claims.

## Bug-to-validation chain

`scripts/analyze_bug_model_workflow.py` detects stage signals in each turn:

```text
bug proposal → TLA+ modeling → TLC → runtime probe → bug ledger
```

The current run found:

- 1,025 bug-proposal turns;
- 1,228 TLA/modeling turns;
- 1,638 TLC-related turns;
- 1,391 runtime-probe turns;
- 464 bug-ledger turns;
- 112 complete ordered chains within a 50-turn maximum span.

The chain figure is `site/dist/bug-model-workflow.svg`. Edge labels count
non-decreasing transitions between adjacent classified turns. A complete chain
means the stage vocabulary appeared in the required order; it does not prove
that one concrete bug was tracked perfectly through every stage. Stage labels
can overlap within one turn, and the detector uses an explicit vocabulary.
