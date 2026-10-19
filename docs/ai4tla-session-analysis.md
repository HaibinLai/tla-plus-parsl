# Codex Session Activity Analysis

This document records a first-pass, privacy-conscious analysis of the local
Codex session used for the Parsl/TLA+ project. The raw session file is kept
outside the repository and is not intended for GitHub publication.

## Source

The source was copied to a temporary analysis directory:

```text
/tmp/tla-parsl-session-analysis/rollout-2026-09-28T07-20-43-01a0e6e3-2d48-7021-8b5e-bde1b784e019.jsonl
```

The original file is approximately 531 MB. The analysis intentionally did not
export prompt text, encrypted content, credentials, or arbitrary tool output.

## First-pass measurements

| Measure | Value |
|---|---:|
| Session time range | 2026-09-28 to 2026-10-19 |
| Total JSONL records | 207,428 |
| `response_item` records | 88,324 |
| `event_msg` records | 87,663 |
| `token_usage_record` records | 29,212 |
| `turn_context` records | 1,904 |
| Compaction events | 124 |
| Distinct turn IDs observed | 1,783 |
| Inter-agent communication metadata records | 38 |

The observed model labels were:

```text
gpt-5.6-luna  1,468 turn-context records
gpt-5.6-sol     260 turn-context records
gpt-5.6-terra   155 turn-context records
gpt-6-sol        21 turn-context records
```

These counts are activity metadata, not a measure of model quality. A turn
context may be emitted more than once, and the session contains compaction and
aborted-turn records.

## What this makes possible

The session log can be joined with repository evidence to reconstruct a useful
timeline:

1. map turn timestamps to `git log` commits;
2. identify turns that updated TLA+ modules, probes, bug ledgers, or reports;
3. separate source-reading, model-writing, testing, documentation, and
   coordination phases;
4. compare subagent communication metadata with actual repository changes;
5. measure how often compaction, retries, or aborted turns occurred before a
   successful change.

## Important limitations

This is not a transcript export. Some content is encrypted or represented only
by metadata, and the current first pass intentionally ignores free-form text.
Therefore it can establish activity and chronology, but not yet reliably judge
the correctness of every agent decision. A later analysis should use explicit
allow-listed fields and redact paths, secrets, and user-identifying data.

The raw session remains in `/tmp`; it is ephemeral and should not be treated as
the project archive. The durable research record is the repository evidence:
commits, TLA+ modules, runtime probes, bug ledger entries, and progress logs.

## Repository alignment

The reproducible extractor is `scripts/analyze_codex_session.py`. It produces
`docs/ai4tla-session-analysis.json` and records only allow-listed repository
path mentions and commit metadata. The current run found 1,965 repository
commits, all temporally within five minutes of a session event; the median
nearest-event distance was 0.407 seconds (maximum 2.768 seconds). This shows
that the local log and Git history overlap closely in time, but it does not
prove causality between a particular turn and a commit.

Across the commit history, changed-file categories were counted as follows:

```text
documentation   2,747
other           1,823
tla_config      1,621
analysis_script 1,019
tla               768
runtime_probe     609
bug_ledger        600
```

The session contains 818 mentions of allow-listed repository paths in exposed
text fields. The most frequently mentioned paths include
`docs/bug-ledger.md` (77), `docs/coverage-matrix.md` (80), and several core
model and report files. These counts are a lower bound because many tool
outputs are not exposed as plain text and are deliberately not decrypted.

An offline dashboard is generated at
`site/dist/session-analysis.html`. It shows daily session volume, changed-file
categories, and a scrollable commit-to-session alignment table.

The repository inventory captured alongside the session is 676 TLA+ modules,
1,478 TLC configuration files, 490 runtime-probe files, nine categorized bug
ledger files, and 317 unique numeric bug IDs in the canonical ledger. These are
repository inventory counts, not claims that every file was semantically
inspected in every turn.
