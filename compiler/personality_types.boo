// concept: Garzaro
// booLangID: anchor — derive via BLAKE3(pubkey ‖ chainID ‖ "gladys:personality_types")
// source: gladys/compiler/personality_types.boo
// verdict: ABSORB
// binary_compat: v2.7 PASS + v3.2 PASS
// grammar: boo-grammar.md BNF compliant

// PERSONALITY TYPE LATTICE
//
// 16 MBTI → 8 base types + isExtrovert (1=E, 0=I) + isAssertive (1=A, 0=T)
//
// typeIndex = (isN * 4) + (isT * 2) + (isJ * 1)   — 3-bit address [0..7]
//   SFP=0  SFJ=1  STP=2  STJ=3  NFP=4  NFJ=5  NTP=6  NTJ=7 (Gladys)
//
// Z4 phase (cognitive axis quadrant):
//   typeIdx % 4 → 0=ST (pragmatic)  1=SF (empathetic)
//                 2=NF (visionary)  3=NT (strategic)  ← Gladys
//
// Polarity (J/P axis):
//   typeIdx % 2 → 1=J (aligned)  0=P (counter)
//
// A/T variant (16Personalities extension):
//   A (Assertive) → uncollapsed bias — confident, low stress reactivity
//   T (Turbulent) → collapsed bias   — self-critical, high stress reactivity
//   Gladys is INTJ-A: typeIdx=7, isExtrovert=0, isAssertive=1
//
// Combined chroma signal (I/E × A/T):
//   E+A → chromaCode=3  (doubly uncollapsed — strong expansion)
//   E+T → chromaCode=2  (conflicting — dampen modifier ×850/1000)
//   I+A → chromaCode=1  (conflicting — dampen modifier ×850/1000)
//   I+T → chromaCode=0  (doubly collapsed — strong conservation)
//
// Population priors (×1000, MBTI research averages):
//   SFP=173  SFJ=260  STP=97   STJ=203
//   NFP=125  NFJ=40   NTP=65   NTJ=39
//
// Signal weight = 10000 / prior — rarer types carry more information per agent.
//   NTJ: 10000/39 = 256   (5.2× signal of STJ)
//   NFJ: 10000/40 = 250
//   NTP: 10000/65 = 153
//   NFP: 10000/125 = 80
//   STP: 10000/97  = 103
//   SFP: 10000/173 = 58
//   STJ: 10000/203 = 49
//   SFJ: 10000/260 = 38

// ── Type index constants ───────────────────────────────────────────────────────

let IDX_SFP = 0
let IDX_SFJ = 1
let IDX_STP = 2
let IDX_STJ = 3
let IDX_NFP = 4
let IDX_NFJ = 5
let IDX_NTP = 6
let IDX_NTJ = 7

// Gladys is always INTJ-A
let GLADYS_IDX        = 7
let GLADYS_EXTROVERT  = 0
let GLADYS_ASSERTIVE  = 1

// Z4 phase sentinels
let PHASE_ST = 0
let PHASE_SF = 1
let PHASE_NF = 2
let PHASE_NT = 3

// Polarity sentinels
let POLARITY_ALIGNED  = 1
let POLARITY_COUNTER  = 0

// Chroma codes (combined I/E × A/T signal)
let CHROMA_CODE_COLLAPSED    = 0   // I+T — doubly conservative
let CHROMA_CODE_IA_CONFLICT  = 1   // I+A — introvert anchor + assertive drive
let CHROMA_CODE_ET_CONFLICT  = 2   // E+T — extrovert drive + turbulent reactivity
let CHROMA_CODE_UNCOLLAPSED  = 3   // E+A — doubly expansive

// Amplifier scale constants (×1000)
let AMPLIFIER_ALIGNED   = 1150   // I/E and A/T agree → ×1.15
let AMPLIFIER_CONFLICT  = 850    // I/E and A/T conflict → ×0.85
let AMPLIFIER_NEUTRAL   = 1000   // no variant info

// Forbidden zone
let FORBIDDEN_THRESHOLD = 13

// ── Population priors (×1000) ─────────────────────────────────────────────────

let PRIOR_SFP = 173
let PRIOR_SFJ = 260
let PRIOR_STP = 97
let PRIOR_STJ = 203
let PRIOR_NFP = 125
let PRIOR_NFJ = 40
let PRIOR_NTP = 65
let PRIOR_NTJ = 39

// Signal weights: 10000 / prior (integer approximation)
let SIG_SFP = 58
let SIG_SFJ = 38
let SIG_STP = 103
let SIG_STJ = 49
let SIG_NFP = 80
let SIG_NFJ = 250
let SIG_NTP = 154
let SIG_NTJ = 256

// Signal weight sum (for normalization reference)
let SIG_SUM = 988

// ── Meta state: last parsed type ──────────────────────────────────────────────

meta.ptype.idx       = 0
meta.ptype.extrovert = 1
meta.ptype.assertive = 1
meta.ptype.phase     = 0
meta.ptype.polarity  = 0
meta.ptype.chroma    = 0
meta.ptype.signal    = 0
meta.ptype.sealed    = 0

// ── priorFor: population prior ×1000 by typeIndex ────────────────────────────

function priorFor(typeIdx) {
  if typeIdx == IDX_SFP { return PRIOR_SFP }
  if typeIdx == IDX_SFJ { return PRIOR_SFJ }
  if typeIdx == IDX_STP { return PRIOR_STP }
  if typeIdx == IDX_STJ { return PRIOR_STJ }
  if typeIdx == IDX_NFP { return PRIOR_NFP }
  if typeIdx == IDX_NFJ { return PRIOR_NFJ }
  if typeIdx == IDX_NTP { return PRIOR_NTP }
  if typeIdx == IDX_NTJ { return PRIOR_NTJ }
  return 1000
}

// ── signalFor: inverse-frequency signal weight by typeIndex ───────────────────

function signalFor(typeIdx) {
  if typeIdx == IDX_SFP { return SIG_SFP }
  if typeIdx == IDX_SFJ { return SIG_SFJ }
  if typeIdx == IDX_STP { return SIG_STP }
  if typeIdx == IDX_STJ { return SIG_STJ }
  if typeIdx == IDX_NFP { return SIG_NFP }
  if typeIdx == IDX_NFJ { return SIG_NFJ }
  if typeIdx == IDX_NTP { return SIG_NTP }
  if typeIdx == IDX_NTJ { return SIG_NTJ }
  return 1
}

// ── phaseFor: Z4 quadrant by typeIndex ───────────────────────────────────────
// typeIdx % 4: 0=ST 1=SF 2=NF 3=NT
// Explicit unroll: no % operator ambiguity in mixed expressions.

function phaseFor(typeIdx) {
  if typeIdx == 0 { return PHASE_ST }
  if typeIdx == 1 { return PHASE_SF }
  if typeIdx == 2 { return PHASE_NF }
  if typeIdx == 3 { return PHASE_NT }
  if typeIdx == 4 { return PHASE_ST }
  if typeIdx == 5 { return PHASE_SF }
  if typeIdx == 6 { return PHASE_NF }
  if typeIdx == 7 { return PHASE_NT }
  return PHASE_ST
}

// ── polarityFor: J=aligned(1) P=counter(0) by typeIndex ─────────────────────
// typeIdx % 2: 0=P(counter) 1=J(aligned)

function polarityFor(typeIdx) {
  if typeIdx == 0 { return POLARITY_COUNTER  }
  if typeIdx == 1 { return POLARITY_ALIGNED  }
  if typeIdx == 2 { return POLARITY_COUNTER  }
  if typeIdx == 3 { return POLARITY_ALIGNED  }
  if typeIdx == 4 { return POLARITY_COUNTER  }
  if typeIdx == 5 { return POLARITY_ALIGNED  }
  if typeIdx == 6 { return POLARITY_COUNTER  }
  if typeIdx == 7 { return POLARITY_ALIGNED  }
  return POLARITY_COUNTER
}

// ── chromaCode: combined I/E × A/T signal ────────────────────────────────────
// Both aligned with expansion (E+A or I+T for contraction) → amplify.
// I/E conflicts with A/T → dampen.

function chromaCode(isExtrovert, isAssertive) {
  if isExtrovert == 1 {
    if isAssertive == 1 { return CHROMA_CODE_UNCOLLAPSED }
    return CHROMA_CODE_ET_CONFLICT
  }
  if isAssertive == 1 { return CHROMA_CODE_IA_CONFLICT }
  return CHROMA_CODE_COLLAPSED
}

// ── amplifierFor: ×1000 scale factor from combined chroma code ───────────────
// Aligned (E+A or I+T) → ×1150 (15% amplification)
// Conflicting (E+T or I+A) → ×850 (15% dampening)

function amplifierFor(isExtrovert, isAssertive) {
  if isExtrovert == 1 {
    if isAssertive == 1 { return AMPLIFIER_ALIGNED }
    return AMPLIFIER_CONFLICT
  }
  if isAssertive == 1 { return AMPLIFIER_CONFLICT }
  return AMPLIFIER_ALIGNED
}

// ── observe: parse agent type into meta.ptype ─────────────────────────────────
// typeIdx:     0–7 (3-bit type address)
// isExtrovert: 1=E 0=I
// isAssertive: 1=A 0=T  (pass 1 as default when variant unknown)

function observe(typeIdx, isExtrovert, isAssertive) {
  meta.ptype.idx       = typeIdx
  meta.ptype.extrovert = isExtrovert
  meta.ptype.assertive = isAssertive
  meta.ptype.phase     = phaseFor(typeIdx)
  meta.ptype.polarity  = polarityFor(typeIdx)
  meta.ptype.chroma    = chromaCode(isExtrovert, isAssertive)
  meta.ptype.signal    = signalFor(typeIdx)
  meta.ptype.sealed    = 1
  return typeIdx
}

// ── zeroize ───────────────────────────────────────────────────────────────────

function zeroize() {
  meta.ptype.idx       = 0
  meta.ptype.extrovert = 1
  meta.ptype.assertive = 1
  meta.ptype.phase     = 0
  meta.ptype.polarity  = 0
  meta.ptype.chroma    = 0
  meta.ptype.signal    = 0
  meta.ptype.sealed    = 0
  return 0
}
