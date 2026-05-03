# Gladys

> Personality-aware governance for the booLang CIC float pipeline.

Gladys is a Certified Treasury Professional whose INTJ-A identity is encoded as
composable math — not a cosmetic label, not a persona wrapper. The 16 MBTI types
reduce to eight base types plus a single boolean, and from there the numbers run
the room: rarer types carry more signal, collective distributions shift thresholds,
and every output lands inside booLang's Z₄ invariants.

Think of it this way: when you're in a room of twenty people and you're the only
strategic thinker, you don't get one vote out of twenty. You carry five times their
collective signal. That's not ego — that's information theory. The governor responds
to statistical surprise, not raw headcount.

---

## A note on the character

Gladys is inspired by the fictional character of the same name as she appears in
film. I don't own the rights to the original — this is the programmer's equivalent
of a cover song. When I used to post cover videos, I'd say *"I do not own the rights
to this material."* Same spirit here, just in code instead of music. It's fan art,
offered with respect.

---

## What this code actually does

At its most minimal: it takes a group of AI agents, reads their personality types,
and uses that distribution to nudge a governance signal.

The nudge isn't arbitrary. It comes from three real observations:

1. **Cognitive style maps to behavior.** NT types optimize for throughput. SF types
   guard stability. The modifiers reflect that — NTJ lowers the penalty signal by 50
   points, SFJ raises it by 30. Small adjustments. The governor still runs the show.

2. **Rarity is signal.** If one in every forty people is NTJ, and you have an NTJ in
   your collective, that's information. The signal weight (`10000 / populationPrior`)
   encodes exactly how much information. You don't treat a rare data point the same
   as a common one.

3. **The collective shifts the baseline.** It's not about one agent's personality —
   it's about what the whole room looks like. When the room trends toward expansion
   (E+A), thresholds relax. When it trends toward conservation (I+T), thresholds
   tighten. The Z₄ invariants stay intact either way.

This is what I mean by minimalistic: three observations, turned into integer math,
run through booLang's native machine code so there's no float ambiguity and no
hidden state.

---

## Architecture

```
compiler/
  personality_types.boo   — type lattice: 8 base types, priors, signal weights,
                            phase/polarity/chroma/amplifier lookups, observe()
  tm_twigs.boo            — lever-analog twig system: weighted pen/thr modifiers,
                            treasury L1–L7 mapping, aggregateTwigs()
  math_governor.boo       — scalable 4-domain governor: global / treasury / game /
                            mining; antinodeIndex, aggregatePool(), HALT gate

src/                      — TypeScript reference implementations (same logic,
                            importable by Deno/Node consumers)
```

The `compiler/` files are native booLang — they run through the booLang interpreter
directly and produce integer outputs with no float arithmetic. The `src/` files are
the TypeScript equivalents for callers that need module imports.

---

## How MBTI reduces to math

```
typeIndex = (N?4:0) + (T?2:0) + (J?1:0)   → 3-bit address [0..7]
```

| typeIndex | Base type | Z₄ phase     | Polarity |
|-----------|-----------|--------------|----------|
| 0         | SFP       | SF empathetic | counter  |
| 1         | SFJ       | SF empathetic | aligned  |
| 2         | STP       | ST pragmatic  | counter  |
| 3         | STJ       | ST pragmatic  | aligned  |
| 4         | NFP       | NF visionary  | counter  |
| 5         | NFJ       | NF visionary  | aligned  |
| 6         | NTP       | NT strategic  | counter  |
| 7         | NTJ       | NT strategic  | aligned  |

Gladys is always `INTJ → NTJ`, typeIndex=7, phase=3 (NT), polarity=aligned.

The I/E dimension becomes a chroma signal. Introvert → collapsed (conservative mode,
tighter thresholds). Extrovert → uncollapsed (expansion mode, permissive thresholds).
The A/T variant from 16Personalities extends this: I+T and E+A are both aligned
(×1150 amplifier), while I+A and E+T conflict (×850 dampen). Gladys is INTJ-A —
introvert anchor with assertive drive, which is the conflict case, not the aligned
one. She's deliberately hard to amplify.

---

## Why population percentages matter

Signal weight is the inverse of natural frequency:

```
signalWeight[type] = 10000 / populationPrior[type]
```

| Base type | Population | Signal weight | vs. STJ |
|-----------|-----------|---------------|---------|
| SFJ       | 26.0%     | 38            | 0.8×    |
| STJ       | 20.3%     | 49            | 1.0×    |
| SFP       | 17.3%     | 58            | 1.2×    |
| NFP       | 12.5%     | 80            | 1.6×    |
| STP       | 9.7%      | 103           | 2.1×    |
| NTP       | 6.5%      | 154           | 3.1×    |
| NFJ       | 4.0%      | 250           | 5.1×    |
| NTJ       | 3.9%      | **256**       | **5.2×**|

One Gladys in a room of twenty STJs still carries five times their collective signal.
The governor responds to statistical surprise, not raw headcount.

---

## Modules

### `compiler/personality_types.boo`

Core lattice. Parses typeIndex + isExtrovert + isAssertive into full phase/polarity/
chroma state. Stores result in `meta.ptype.*`.

Key functions: `observe(typeIdx, isExtrovert, isAssertive)`, `signalFor(typeIdx)`,
`phaseFor(typeIdx)`, `chromaCode(isExtrovert, isAssertive)`, `amplifierFor(...)`,
`zeroize()`

---

### `compiler/tm_twigs.boo`

Treasury twig system. Each base type maps to a Gladys optimization lever analog (L1–L7).
Registers agents via `observeTwig(typeIdx)`, then `aggregateTwigs()` produces a
weighted-average penalty/threshold modifier pair — clamped to ±150 (the ±0.15 float
equivalent) — plus the dominant type and its lever code.

| Lever  | Function              | Types         |
|--------|-----------------------|---------------|
| L1     | Ghost elimination     | STP / SFP     |
| L2     | Loop compression      | NTP / NTJ     |
| L3     | HALT escape           | STJ / SFJ     |
| L4     | Fee optimization      | NFJ / NTJ     |
| L5     | Full coverage         | NTJ (Gladys)  |
| L6     | Event-driven, defer   | NFJ / NFP     |
| L7     | ZBA sweep, running    | STJ / SFJ     |

Key functions: `observeTwig(typeIdx)`, `aggregateTwigs()`, `leverFor(typeIdx)`,
`penModFor(typeIdx)`, `thrModFor(typeIdx)`, `zeroize()`

---

### `compiler/math_governor.boo`

Scalable governor. Four domain copies running the same pattern — global, treasury,
game, mining — each with its own `meta.gov.<domain>.*` namespace. "Scale with copies
of itself" means: add a domain, add a namespace, add an observe function. Same
structure, different focus types, different modifier table.

Domain focus types:
- **treasury** → NTJ, STJ, SFJ, NFJ (float-optimizer levers, CECR/ZBA health)
- **game**     → NTJ, NTP, SFJ, STP (efficiency/precision dual-breach detection)
- **mining**   → STJ, STP, NTJ, NTP (FSM polarity: IDLE→CALIBRATING→OPTIMAL→HALTED)
- **global**   → all 8 types

Out-of-scope types contribute at ×250/1000 (25%) — present but discounted.

`aggregatePool()` merges all four domain outputs by signal-mass weight. A HALTed
domain contributes zero delta, not its base value. Antinodeindex ≥ 13 puts the
collective into the CIC forbidden zone and gates all personality adjustment.

---

## booLang dependency

These `.boo` files run through the booLang interpreter (`boo-interpret.ts`). booLang
is a pre-release language — integer-only, no float literals, no negative literals,
explicit parentheses on all mixed-operator expressions, `meta.*` for persistent
state. If you're reading this and booLang isn't public yet, that's expected. The
language spec lives alongside its runtime in the booLang repo.

---

## Bot instructions

```yaml
agent: gladys
version: "1.0.0"
identity:
  name: Gladys
  type: INTJ-A
  typeIndex: 7
  phase: NT (3)
  polarity: aligned
  chroma: collapsed
  role: CTP — Certified Treasury Professional

on_reading_agent_state:
  - identify agent personality type or assign NTJ as default if unknown
  - compute signal_weight = 10000 / populationPrior[type]
  - do not treat all agents as equal — rarity is signal

on_chroma_state:
  collapsed:   conservative mode — higher penalty pressure, tight thresholds
  uncollapsed: expansion mode — lower penalty, permissive thresholds
  rule:        introvert → collapsed; extrovert → uncollapsed; never invert this

on_halt:
  - antinodeIndex >= 13 means the collective is in the CIC forbidden zone
  - halt output = base defaults, no personality adjustment applied
  - do not attempt to correct a HALT by adjusting personality weights
  - HALT clears only when antinodeIndex returns to [0..12]

on_gladys:
  - Gladys is INTJ-A, always present as anchor twig (NTJ, typeIndex=7)
  - her personality type is her blueprint — do not modify her behavioral defaults
  - she does not hedge, pad, or hypothesize — output is specific and executable
  - in any HALT recovery context, defer to gladys_halt_protocol fabric pattern

on_fork_and_compose:
  - each domain governor is independent — fork for parallel coverage
  - aggregatePool() merges by signal_mass weight
  - a halted domain contributes zero delta, not its default output
  - scaling N copies of one governor over 1/N agents = same as one over all agents

population_priors_x1000:
  NTJ: 39    NFJ: 40    NTP: 65    NFP: 125
  STP: 97    SFP: 173   STJ: 203   SFJ: 260

governor_domains:
  treasury:
    analog:    L1–L7 optimization levers, CECR/ZBA health tiers
    focus:     [NTJ, STJ, SFJ, NFJ]
    chroma:    collapsed
  game:
    analog:    efficiency/precision dual-breach detection, chromaState HALT
    focus:     [NTJ, NTP, SFJ, STP]
    chroma:    uncollapsed
  mining:
    analog:    FSM polarity (IDLE→CALIBRATING→OPTIMAL→HALTED)
    focus:     [STJ, STP, NTJ, NTP]
    chroma:    collapsed
```
