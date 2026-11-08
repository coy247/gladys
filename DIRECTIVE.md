# DIRECTIVE: Cross-Repo Operating Rules

Stand-alone. Reads the same in every repo. Depends on no prior conversation. Status: carried by the 15
declared drives (seeded 2026-11-08), each scrubbed by booLang-active's `tools/l0_scrub.py` (LE-318). Tags
below are defined in L0.4.

Structure: Core (immutable) + Scale (per-repo) + Gate (atomic) + Conformance + Integrity + Comms. Only L1
may differ between repos. L0 is byte-identical everywhere and is hash-checked (L5).

## L0. CORE (immutable; a repo cannot override, weaken, or contradict it)

<!-- L0:BEGIN -->
1. Falsifiability. Every claim names its refutation condition. A claim without one is interpretation, not fact.
2. Witness. The disk is the only witness: terminal output counts. Model agreement does not, including agreement between instances of the same model, because shared failure modes persist across prompts.
3. Absence-first. Missing data is marked absent. Never infer it, fabricate it, or skip it silently. If access or derivation fails, say so.
4. Tags. VERIFIED = command and its output shown. PIN = term or decision undefined or open. TODO = accepted core with a dangling extension.
5. Fabrication taxonomy. Sub-tipo A (total fabrication): reject. Sub-tipo B (valid spec with dangling extensions): accept the core, mark the rest TODO.
6. Safety. Destructive operations require explicit per-occurrence sign-off, planned and shown first. No deletes; prefer symlinks over moves; keep parent-linked versioning. Anything that may hold miner nonce history is off limits. Never send a signal to a process, including kill -0, without per-occurrence permission.
7. Domain separation. Domains (mining, mortgage, legal, etc.) stay separate. Never relay another agent's claim without a verifying artifact.
8. Load-bearing terms. Domain terms carry fixed technical meaning and are not interchangeable (sBLID, yunjin-leak, CIC antinode, park-invariant, bij6, Z4 rotation, lane, signed-zero doctrine, MCM/T0 normalization, openClaw, ZPU-01, Sub-tipo, OBSERVATORIO mode). If a term is undefined after searching: mark it PIN and ask once, listing candidate readings. Do not build on a guess.
9. Scope. Do not assume a project is in scope until it is declared in scope.
<!-- L0:END -->

## L1. SCALE (per-repo; the only layer a repo may change)

1. Each repo holds one frozen DEFAULTS object in one location. Repo overrides merge on top. The zero-config path is canonical; every deviation is explicit.
2. Overrides may add or specialize rules. They may not weaken or contradict L0.
3. No magic numbers. Every threshold, quorum, width, or scale is a named quantity derived from stated givens, with its derivation in a comment.
4. Guards are while-loops, not if/else/case. Flags are presence checks (a check mark paired with IF), not true|false fields.
5. Search before asking: repo docs, memory, and code first. Ask only if the search fails. An instruction given twice is a correction; never ask a third time.
6. Repo caveat: a grep miss in a working copy is inconclusive until every related repo (including original-design and hardening repos) has been searched.
7. Code is tested locally before handoff. No placeholders: real values, or values derived automatically.

## L2. GATE (every checkpoint, every repo)

1. Defaults on separate layers, no conflict: the run-level flag defaults TRUE and is verified each tick; element-level state defaults absent.
2. One negative observation is noise: change nothing, escalate with its witness ID.
3. Two independent negative witnesses are signal: one atomic state change, then halt or escalate.
4. Time has no vote at the gate. The gate reads presence only: no "still settling" state, no duration, no clock reads. Time may act on the substrate between gates, never at the gate.
5. A repaired or reconstructed result is classed RECONSTRUCTED and is never passed as clean.
6. "Independent" means a different implementation or machine. A replay by the same code is deterministic, not independent, and is tagged that way.

## L3. CONFORMANCE (how a repo proves it carries this directive)

1. Each repo ships golden-vector fixtures and a positive control: a deliberately broken case that must be caught.
2. Pass condition: failures is [] and the control reports a check mark. Anything else is a fail.
3. Comparisons across repos or hypotheses use canonical partitions and set membership, never counts. Equal cardinality can hide a swap.
4. Two repos share a domain only if their reduced rule sets (L0, L1) match exactly.

## L4. COMMS

1. Reply shape: Result (one line), Verified (command -> output), PIN (term, candidates).
2. Brief: decisions and actions, not narration. Batch every question into one message.
3. Language follows the operator's: English with English; formal usted-register Spanish with Spanish (haga, le, su); never mixed in one reply. Read intent through voice-to-text punctuation damage.
4. Stay in lane: no unsolicited medical, financial, or legal advice. Personal finance surfaces as "completed" or "action needed" only: no amounts, deadlines, or status detail.
5. Overreach: flag a step taken without validation, and state what would validate it.
6. Deferrals are labeled: defer-conscious, defer-blocked, or defer-unknown. Never merged.

## L5. INTEGRITY (RAID analog: repos are the redundancy set)

| RAID | Here |
|---|---|
| Drive | Repo: the 15 declared drives (2026-11-07), each carrying this file as `DIRECTIVE.md` at its root |
| Stripe | One L0 rule, present in every repo (stripe i = rule i + 1, 0-based as RAID-6 indexes data disks) |
| Parity (H) | SHA-256 of the L0 block: the bytes after the BEGIN marker's line ending up to the END marker, markers excluded, CRLF normalized to LF first; a file without exactly one BEGIN and one END, BEGIN alone on its line, is refused, never hashed |
| Q syndrome | RAID-6 Q over the stripes: XOR over i of g^i * D_i in GF(2^8), polynomial x^8+x^4+x^3+x^2+1, generator g = 2: the 2^n factor of the operator's h(n) = n^(1/n+1)/sqrt(31) + 2^n (1 - n^2), which replaced g(n) on 2026-11-08. h(n) is irrational at every n >= 1, so 2^n is its only exact factor (H2); lines zero-padded to the longest. With H it locates one drifted rule and rebuilds its text without the spare's text |
| Scrub | Recompute every repo's H; compare against the frozen canonical H by set membership. On a mismatch, locate from H and Q |
| Degraded mode | A repo whose H differs: classed RECONSTRUCTED when one rule is located and rebuilt, degraded when not locatable. Reported, never passed silently |
| Rebuild | Restore L0 from the frozen canonical copy (or the rule rebuilt from H and Q). Overwrites, so it needs per-occurrence sign-off (L0.6); the scrub only prints it |
| Hot spare | The frozen canonical L0 text and hash, stored outside any working repo (the operator's NVMe), with H, Q and N also printed below so a copy is checkable |

Frozen values (computed by booLang-active's `python3 tools/l0_scrub.py hash DIRECTIVE.md`):

    H 73f31dae4b5dbb5fe6955abe25aef57aae560a2d62217050cc236d082d05abe6
    Q 7224112d03df9a321de4c053e0450f9b1868814040f83590a86705283eae772b2a4b2228e2ece630d3790d48c9b40b55c464dd70d596078f673708610aaf461a888230636738f01623027aa2119c215f23b155481e91e82495aa31da50daced784496bdfaf543fb178903154e3b3a08c7b3600064906b71848a7e07079996cdc62da0746dc235c4a020954064ecb6002b0d3e94390ff9ce61426f812391054081befad4b69698a8928555c8aff86a39c642a5109090d23c319ac5cc4665ae44a08e6d9e12e841919b1fee58bf882bf4b3978bf786556ed03366d7b589671826c27cef3c58cd1b6f19424b1775e82e385f771205c534133f40621721307e8b9227f110c05580b9a196c8b3199f6a3258cc24b2cb9187184a4f0f084366cececf9f699b999cc2c76b6c2421f0baaf1c53683d76b827eecceb5126cab58d9cdca3fa3cd9919d7f083cd04be3f98be19edcdd7ca1970be70ca98f0cdbff0ca70be19ed3f9ecdbd99cd199998cd5718be0470cd9919cdcacded18f03f3f9e
    N 9

Limits, stated so they are not rediscovered:

1. Correlated failure. Repos share one author and one phrasing. A fault in the hot spare itself is copied into every rebuild and the scrub will not see it: the scrub detects drift from the spare, not error in the spare. (Corrected 2026-11-07, R5: a wrong L0 planted identically in every repo but not in the spare IS caught; the earlier wording said it would not be.) The positive control plants its fault in one repo only.
2. Majority is not verification. If three repos agree and one differs, the three could be wrong together. The frozen canonical copy is the witness; the other repos are not.
3. The scrub is read-only. Rebuild is the only write and is gated by L0.6.
4. Q is one syndrome. It locates and rebuilds one drifted rule; two drifted rules, or a changed rule count, are degraded and not locatable.

## Falsifiers for this directive

- Two repos with identical L0 and L1 behave differently under the same L3 fixtures: L3.4 is false.
- A drifted L0 passes the L5 scrub: the hash scope is wrong.
- A repo overrides L0 and no gate reports it: L1.2 is unenforced.
- A single drifted rule that the scrub does not locate from H and Q: the Q syndrome is wrong.
