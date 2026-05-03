// concept: Garzaro
// booLangID: anchor — derive via BLAKE3(pubkey ‖ chainID ‖ "gladys:math_governor")
// source: gladys/compiler/math_governor.boo
// verdict: ABSORB
// binary_compat: v2.7 PASS + v3.2 PASS
// grammar: boo-grammar.md BNF compliant
// depends: personality_types.boo (signalFor, priorFor, phaseFor, polarityFor,
//           amplifierFor, chromaCode — must be loaded in the same interpreter context)

// SCALABLE MATH GOVERNOR
//
// One governor pattern, four domain copies: global / treasury / game / mining.
// Each domain copy uses the same observe/apply functions with its own meta namespace.
// "Scale with copies of itself" = call observeForDomain(typeIdx, ..., domainId)
// for each agent, then call aggregatePool() to merge all four domains into one output.
//
// Domain focus types (in-scope = full signal weight; out-of-scope = ×250/1000):
//   global   → all 8 types
//   treasury → NTJ(7) STJ(3) SFJ(1) NFJ(5)   (float-optimizer L1–L7 / CECR / ZBA)
//   game     → NTJ(7) NTP(6) SFJ(1) STP(2)   (game-loop efficiency/precision/chroma)
//   mining   → STJ(3) STP(2) NTJ(7) NTP(6)   (mining-director FSM polarity)
//
// Modifier table (offset-from-1000; 1000=neutral, <1000=reduce, >1000=increase):
//   PEN modifiers by domain × type:
//     global:   SFP=1020 SFJ=1030 STP=990  STJ=1000 NFP=970 NFJ=980 NTP=960 NTJ=950
//     treasury: SFP=1030 SFJ=1050 STP=1000 STJ=1010 NFP=980 NFJ=960 NTP=950 NTJ=920
//     game:     SFP=1020 SFJ=1040 STP=980  STJ=1010 NFP=960 NFJ=970 NTP=950 NTJ=940
//     mining:   SFP=1020 SFJ=1030 STP=1010 STJ=1020 NFP=990 NFJ=990 NTP=970 NTJ=960
//   THR modifiers by domain × type:
//     global:   SFP=1030 SFJ=1040 STP=1000 STJ=1010 NFP=950 NFJ=960 NTP=960 NTJ=970
//     treasury: SFP=1040 SFJ=1060 STP=1010 STJ=1020 NFP=970 NFJ=940 NTP=940 NTJ=950
//     game:     SFP=1030 SFJ=1050 STP=1010 STJ=1020 NFP=940 NFJ=950 NTP=950 NTJ=960
//     mining:   SFP=1020 SFJ=1030 STP=1020 STJ=1030 NFP=980 NFJ=980 NTP=970 NTJ=980
//
// Antinodeindex computation (CIC Z4 x Z4):
//   a0 = typeIdx % 4                          (0..3: type quadrant)
//   a1 = suspRatio1000 / 250                  (0..3: suspension pressure)
//   antinodeIdx = (4 * a1) + a0               (0..15)
//   HALT when antinodeIdx >= FORBIDDEN_THRESHOLD (13)
//
// A/T amplification:
//   After computing signal-weighted modifier, scale by amplifierFor(extrovert, assertive).
//   This makes Gladys (INTJ-A, I+A=conflict→×850) slightly dampened vs ENTJ-A (E+A→×1150).
//
// Explicit parens: booLang parser is left-associative with no precedence.
//   All mixed * + expressions use explicit parens throughout.

// ── Domain sentinels ──────────────────────────────────────────────────────────

let DOM_GLOBAL   = 0
let DOM_TREASURY = 1
let DOM_GAME     = 2
let DOM_MINING   = 3

// ── Forbidden zone ────────────────────────────────────────────────────────────

let FORBIDDEN = 13
let HALTED    = 1
let PASS      = 0

// ── Chroma alignment: which domain aligns with which chroma state ─────────────
// treasury + mining prefer collapsed (conservative);  game prefers uncollapsed.
// 1=isCollapsed_preferred  0=isUncollapsed_preferred  -1=neutral (global)
// Stored as two separate sentinels to avoid negatives.
let ALIGN_PREFERS_COLLAPSED   = 1
let ALIGN_PREFERS_UNCOLLAPSED = 2
let ALIGN_NEUTRAL             = 3

let ALIGN_GLOBAL   = ALIGN_NEUTRAL
let ALIGN_TREASURY = ALIGN_PREFERS_COLLAPSED
let ALIGN_GAME     = ALIGN_PREFERS_UNCOLLAPSED
let ALIGN_MINING   = ALIGN_PREFERS_COLLAPSED

// Scale factors (×1000) applied when chroma matches domain preference
let SCALE_ALIGNED   = 1150
let SCALE_MISALIGN  = 800
let SCALE_NEUTRAL   = 1000

// MAX delta (×1000): personality never shifts mult by more than ±0.20
let MAX_DELTA_1000 = 200

// ── Meta state: per-domain accumulators ───────────────────────────────────────
// Pattern: meta.gov.<domain>.<field>
// gl = global   tr = treasury   gm = game   mn = mining

meta.gov.gl.sig   = 0    // signal mass sum
meta.gov.gl.pen   = 0    // pen modifier sum (signal-weighted, offset-from-1000)
meta.gov.gl.thr   = 0    // thr modifier sum (signal-weighted, offset-from-1000)
meta.gov.gl.cpres = 0    // chroma pressure sum (+signal=E/A, -signal becomes subtraction)
meta.gov.gl.susp  = 0    // suspended agent count
meta.gov.gl.total = 0    // total agents observed
meta.gov.gl.gated  = 0    // 1 if halted, 0 if pass

meta.gov.tr.sig   = 0
meta.gov.tr.pen   = 0
meta.gov.tr.thr   = 0
meta.gov.tr.cpres = 0
meta.gov.tr.susp  = 0
meta.gov.tr.total = 0
meta.gov.tr.gated  = 0

meta.gov.gm.sig   = 0
meta.gov.gm.pen   = 0
meta.gov.gm.thr   = 0
meta.gov.gm.cpres = 0
meta.gov.gm.susp  = 0
meta.gov.gm.total = 0
meta.gov.gm.gated  = 0

meta.gov.mn.sig   = 0
meta.gov.mn.pen   = 0
meta.gov.mn.thr   = 0
meta.gov.mn.cpres = 0
meta.gov.mn.susp  = 0
meta.gov.mn.total = 0
meta.gov.mn.gated  = 0

// Pool output: result of aggregatePool()
meta.gov.pool.pen_delta = 0    // net signed pen delta (×1000, may be negative via subtraction)
meta.gov.pool.thr_delta = 0
meta.gov.pool.pen_mult  = 1000
meta.gov.pool.thr_mult  = 1000
meta.gov.pool.gated    = 0
meta.gov.pool.antinode  = 0
meta.gov.pool.sealed    = 0

// ── Modifier lookup: pen and thr by typeIndex × domain ───────────────────────
// Returns offset-from-1000 value.  1000 = no change.  950 = reduce by 50.
// Explicit parens not needed here (no mixed ops); included for clarity.

function penModFor(typeIdx, domainId) {
  if domainId == DOM_GLOBAL {
    if typeIdx == IDX_SFP { return 1020 }
    if typeIdx == IDX_SFJ { return 1030 }
    if typeIdx == IDX_STP { return 990  }
    if typeIdx == IDX_STJ { return 1000 }
    if typeIdx == IDX_NFP { return 970  }
    if typeIdx == IDX_NFJ { return 980  }
    if typeIdx == IDX_NTP { return 960  }
    if typeIdx == IDX_NTJ { return 950  }
  }
  if domainId == DOM_TREASURY {
    if typeIdx == IDX_SFP { return 1030 }
    if typeIdx == IDX_SFJ { return 1050 }
    if typeIdx == IDX_STP { return 1000 }
    if typeIdx == IDX_STJ { return 1010 }
    if typeIdx == IDX_NFP { return 980  }
    if typeIdx == IDX_NFJ { return 960  }
    if typeIdx == IDX_NTP { return 950  }
    if typeIdx == IDX_NTJ { return 920  }
  }
  if domainId == DOM_GAME {
    if typeIdx == IDX_SFP { return 1020 }
    if typeIdx == IDX_SFJ { return 1040 }
    if typeIdx == IDX_STP { return 980  }
    if typeIdx == IDX_STJ { return 1010 }
    if typeIdx == IDX_NFP { return 960  }
    if typeIdx == IDX_NFJ { return 970  }
    if typeIdx == IDX_NTP { return 950  }
    if typeIdx == IDX_NTJ { return 940  }
  }
  if domainId == DOM_MINING {
    if typeIdx == IDX_SFP { return 1020 }
    if typeIdx == IDX_SFJ { return 1030 }
    if typeIdx == IDX_STP { return 1010 }
    if typeIdx == IDX_STJ { return 1020 }
    if typeIdx == IDX_NFP { return 990  }
    if typeIdx == IDX_NFJ { return 990  }
    if typeIdx == IDX_NTP { return 970  }
    if typeIdx == IDX_NTJ { return 960  }
  }
  return 1000
}

function thrModFor(typeIdx, domainId) {
  if domainId == DOM_GLOBAL {
    if typeIdx == IDX_SFP { return 1030 }
    if typeIdx == IDX_SFJ { return 1040 }
    if typeIdx == IDX_STP { return 1000 }
    if typeIdx == IDX_STJ { return 1010 }
    if typeIdx == IDX_NFP { return 950  }
    if typeIdx == IDX_NFJ { return 960  }
    if typeIdx == IDX_NTP { return 960  }
    if typeIdx == IDX_NTJ { return 970  }
  }
  if domainId == DOM_TREASURY {
    if typeIdx == IDX_SFP { return 1040 }
    if typeIdx == IDX_SFJ { return 1060 }
    if typeIdx == IDX_STP { return 1010 }
    if typeIdx == IDX_STJ { return 1020 }
    if typeIdx == IDX_NFP { return 970  }
    if typeIdx == IDX_NFJ { return 940  }
    if typeIdx == IDX_NTP { return 940  }
    if typeIdx == IDX_NTJ { return 950  }
  }
  if domainId == DOM_GAME {
    if typeIdx == IDX_SFP { return 1030 }
    if typeIdx == IDX_SFJ { return 1050 }
    if typeIdx == IDX_STP { return 1010 }
    if typeIdx == IDX_STJ { return 1020 }
    if typeIdx == IDX_NFP { return 940  }
    if typeIdx == IDX_NFJ { return 950  }
    if typeIdx == IDX_NTP { return 950  }
    if typeIdx == IDX_NTJ { return 960  }
  }
  if domainId == DOM_MINING {
    if typeIdx == IDX_SFP { return 1020 }
    if typeIdx == IDX_SFJ { return 1030 }
    if typeIdx == IDX_STP { return 1020 }
    if typeIdx == IDX_STJ { return 1030 }
    if typeIdx == IDX_NFP { return 980  }
    if typeIdx == IDX_NFJ { return 980  }
    if typeIdx == IDX_NTP { return 970  }
    if typeIdx == IDX_NTJ { return 980  }
  }
  return 1000
}

// ── inScope: is a typeIndex in focus for a given domain? ─────────────────────
// Returns 1 (full signal) or 0 (reduced to ×250/1000 in observe)

function inScope(typeIdx, domainId) {
  if domainId == DOM_GLOBAL { return 1 }
  if domainId == DOM_TREASURY {
    if typeIdx == IDX_NTJ { return 1 }
    if typeIdx == IDX_STJ { return 1 }
    if typeIdx == IDX_SFJ { return 1 }
    if typeIdx == IDX_NFJ { return 1 }
    return 0
  }
  if domainId == DOM_GAME {
    if typeIdx == IDX_NTJ { return 1 }
    if typeIdx == IDX_NTP { return 1 }
    if typeIdx == IDX_SFJ { return 1 }
    if typeIdx == IDX_STP { return 1 }
    return 0
  }
  if domainId == DOM_MINING {
    if typeIdx == IDX_STJ { return 1 }
    if typeIdx == IDX_STP { return 1 }
    if typeIdx == IDX_NTJ { return 1 }
    if typeIdx == IDX_NTP { return 1 }
    return 0
  }
  return 0
}

// ── antinodeIndex: CIC Z4×Z4 coordinate ──────────────────────────────────────
// a0 = typeIdx % 4: unrolled (no mixed-op precedence risk)
// a1 = suspRatio1000 / 250: maps [0..999] → [0..3]
// antinodeIdx = (4 * a1) + a0

function a0From(typeIdx) {
  if typeIdx == 0 { return 0 }
  if typeIdx == 1 { return 1 }
  if typeIdx == 2 { return 2 }
  if typeIdx == 3 { return 3 }
  if typeIdx == 4 { return 0 }
  if typeIdx == 5 { return 1 }
  if typeIdx == 6 { return 2 }
  if typeIdx == 7 { return 3 }
  return 0
}

function antinodeIndex(typeIdx, suspRatio1000) {
  let a0 = a0From(typeIdx)
  let a1 = suspRatio1000 / 250
  if a1 > 3 { a1 = 3 }
  return (4 * a1) + a0
}

// ── chroma scale factor: align domain preference with current chromaState ─────
// isCollapsed: 1=collapsed 0=uncollapsed (caller passes from live state)

function chromaScale(domainId, isCollapsed) {
  if domainId == DOM_GLOBAL { return SCALE_NEUTRAL }
  if domainId == DOM_TREASURY {
    if isCollapsed == 1 { return SCALE_ALIGNED }
    return SCALE_MISALIGN
  }
  if domainId == DOM_GAME {
    if isCollapsed == 0 { return SCALE_ALIGNED }
    return SCALE_MISALIGN
  }
  if domainId == DOM_MINING {
    if isCollapsed == 1 { return SCALE_ALIGNED }
    return SCALE_MISALIGN
  }
  return SCALE_NEUTRAL
}

// ── clamp1000: clamp delta to [-MAX_DELTA_1000, +MAX_DELTA_1000] ─────────────
// boo has no negative literals; we return the magnitude + a sign flag.
// sign: 1=positive 0=negative (or zero)
// Returns the clamped magnitude (always non-negative).

function clampMag(mag) {
  if mag > MAX_DELTA_1000 { return MAX_DELTA_1000 }
  return mag
}

// ── Domain-specific observe functions (one per domain = one "copy") ───────────
//
// observeGlobal / observeTreasury / observeGame / observeMining
//
// Arguments:
//   typeIdx:     0–7
//   isExtrovert: 1=E 0=I
//   isAssertive: 1=A 0=T
//   isSuspended: 1=yes 0=no
//
// Each accumulates into its own meta.gov.* namespace.
// The host layer calls the relevant function(s) once per agent.
// After all agents are observed, call apply* or aggregatePool.

function observeGlobal(typeIdx, isExtrovert, isAssertive, isSuspended) {
  let sig = signalFor(typeIdx)
  let pen = penModFor(typeIdx, DOM_GLOBAL)
  let thr = thrModFor(typeIdx, DOM_GLOBAL)
  let amp = amplifierFor(isExtrovert, isAssertive)
  // signal-weighted, A/T-amplified accumulation
  // pen * sig = signal-weighted offset sum; amplifier applied at apply time
  meta.gov.gl.sig   = meta.gov.gl.sig + sig
  meta.gov.gl.pen   = meta.gov.gl.pen + (pen * sig)
  meta.gov.gl.thr   = meta.gov.gl.thr + (thr * sig)
  // chroma pressure: uncollapsed signal (E=1 or A=1 both contribute)
  // E+A: full +sig.  E+T or I+A: half sig.  I+T: zero.
  if isExtrovert == 1 {
    if isAssertive == 1 {
      meta.gov.gl.cpres = meta.gov.gl.cpres + sig
    }
    if isAssertive == 0 {
      meta.gov.gl.cpres = meta.gov.gl.cpres + (sig / 2)
    }
  }
  if isExtrovert == 0 {
    if isAssertive == 1 {
      meta.gov.gl.cpres = meta.gov.gl.cpres + (sig / 2)
    }
  }
  meta.gov.gl.susp  = meta.gov.gl.susp + isSuspended
  meta.gov.gl.total = meta.gov.gl.total + 1
  return sig
}

function observeTreasury(typeIdx, isExtrovert, isAssertive, isSuspended) {
  let sig    = signalFor(typeIdx)
  let scoped = inScope(typeIdx, DOM_TREASURY)
  if scoped == 0 { sig = sig / 4 }
  let pen = penModFor(typeIdx, DOM_TREASURY)
  let thr = thrModFor(typeIdx, DOM_TREASURY)
  meta.gov.tr.sig   = meta.gov.tr.sig + sig
  meta.gov.tr.pen   = meta.gov.tr.pen + (pen * sig)
  meta.gov.tr.thr   = meta.gov.tr.thr + (thr * sig)
  if isExtrovert == 1 {
    if isAssertive == 1 { meta.gov.tr.cpres = meta.gov.tr.cpres + sig }
    if isAssertive == 0 { meta.gov.tr.cpres = meta.gov.tr.cpres + (sig / 2) }
  }
  if isExtrovert == 0 {
    if isAssertive == 1 { meta.gov.tr.cpres = meta.gov.tr.cpres + (sig / 2) }
  }
  meta.gov.tr.susp  = meta.gov.tr.susp + isSuspended
  meta.gov.tr.total = meta.gov.tr.total + 1
  return sig
}

function observeGame(typeIdx, isExtrovert, isAssertive, isSuspended) {
  let sig    = signalFor(typeIdx)
  let scoped = inScope(typeIdx, DOM_GAME)
  if scoped == 0 { sig = sig / 4 }
  let pen = penModFor(typeIdx, DOM_GAME)
  let thr = thrModFor(typeIdx, DOM_GAME)
  meta.gov.gm.sig   = meta.gov.gm.sig + sig
  meta.gov.gm.pen   = meta.gov.gm.pen + (pen * sig)
  meta.gov.gm.thr   = meta.gov.gm.thr + (thr * sig)
  if isExtrovert == 1 {
    if isAssertive == 1 { meta.gov.gm.cpres = meta.gov.gm.cpres + sig }
    if isAssertive == 0 { meta.gov.gm.cpres = meta.gov.gm.cpres + (sig / 2) }
  }
  if isExtrovert == 0 {
    if isAssertive == 1 { meta.gov.gm.cpres = meta.gov.gm.cpres + (sig / 2) }
  }
  meta.gov.gm.susp  = meta.gov.gm.susp + isSuspended
  meta.gov.gm.total = meta.gov.gm.total + 1
  return sig
}

function observeMining(typeIdx, isExtrovert, isAssertive, isSuspended) {
  let sig    = signalFor(typeIdx)
  let scoped = inScope(typeIdx, DOM_MINING)
  if scoped == 0 { sig = sig / 4 }
  let pen = penModFor(typeIdx, DOM_MINING)
  let thr = thrModFor(typeIdx, DOM_MINING)
  meta.gov.mn.sig   = meta.gov.mn.sig + sig
  meta.gov.mn.pen   = meta.gov.mn.pen + (pen * sig)
  meta.gov.mn.thr   = meta.gov.mn.thr + (thr * sig)
  if isExtrovert == 1 {
    if isAssertive == 1 { meta.gov.mn.cpres = meta.gov.mn.cpres + sig }
    if isAssertive == 0 { meta.gov.mn.cpres = meta.gov.mn.cpres + (sig / 2) }
  }
  if isExtrovert == 0 {
    if isAssertive == 1 { meta.gov.mn.cpres = meta.gov.mn.cpres + (sig / 2) }
  }
  meta.gov.mn.susp  = meta.gov.mn.susp + isSuspended
  meta.gov.mn.total = meta.gov.mn.total + 1
  return sig
}

// ── applyDomain: compute pen/thr deltas from accumulated domain state ─────────
// domainId:    DOM_*
// isCollapsed: 1=collapsed 0=uncollapsed
// dominantIdx: typeIndex of the agent with highest signal in this domain
//              (caller tracks this by comparing signalFor across observed agents)
//
// Returns pen delta ×1000 stored in meta.gov.pool.pen_delta/thr_delta.
// Sign convention: values > 1000 are positive deltas; values < 1000 are negative.
// Caller reads: if rawPen > 1000 → delta = rawPen-1000 (add); else delta = 1000-rawPen (subtract)

function applyDomain(domainId, isCollapsed, dominantIdx) {
  let sig   = 0
  let pen   = 0
  let thr   = 0
  let susp  = 0
  let total = 0

  if domainId == DOM_GLOBAL {
    sig   = meta.gov.gl.sig
    pen   = meta.gov.gl.pen
    thr   = meta.gov.gl.thr
    susp  = meta.gov.gl.susp
    total = meta.gov.gl.total
  }
  if domainId == DOM_TREASURY {
    sig   = meta.gov.tr.sig
    pen   = meta.gov.tr.pen
    thr   = meta.gov.tr.thr
    susp  = meta.gov.tr.susp
    total = meta.gov.tr.total
  }
  if domainId == DOM_GAME {
    sig   = meta.gov.gm.sig
    pen   = meta.gov.gm.pen
    thr   = meta.gov.gm.thr
    susp  = meta.gov.gm.susp
    total = meta.gov.gm.total
  }
  if domainId == DOM_MINING {
    sig   = meta.gov.mn.sig
    pen   = meta.gov.mn.pen
    thr   = meta.gov.mn.thr
    susp  = meta.gov.mn.susp
    total = meta.gov.mn.total
  }

  if sig == 0 { return PASS }

  // Weighted average offset (÷ sig): represents the collective's modifier direction
  let penAvg = pen / sig
  let thrAvg = thr / sig

  // Antinode check: suspRatio1000 × dominantIdx determines CIC coordinate
  let suspRatio1000 = 0
  if total > 0 { suspRatio1000 = (susp * 1000) / total }
  let antinode = antinodeIndex(dominantIdx, suspRatio1000)

  if antinode >= FORBIDDEN {
    if domainId == DOM_GLOBAL   { meta.gov.gl.gated = HALTED }
    if domainId == DOM_TREASURY { meta.gov.tr.gated = HALTED }
    if domainId == DOM_GAME     { meta.gov.gm.gated = HALTED }
    if domainId == DOM_MINING   { meta.gov.mn.gated = HALTED }
    return HALTED
  }

  // Chroma alignment scale
  let cScale = chromaScale(domainId, isCollapsed)

  // Apply scale: (avgOffset - 1000) × cScale / 1000 + 1000 = scaled offset
  // Decompose: if penAvg >= 1000 → positive delta; else negative delta.
  // Store as raw scaled offset — caller converts to signed delta.
  let penScaled = 0
  let thrScaled = 0

  if penAvg >= 1000 {
    let penMag = ((penAvg - 1000) * cScale) / 1000
    penScaled  = 1000 + penMag
  }
  if penAvg < 1000 {
    let penMag = ((1000 - penAvg) * cScale) / 1000
    penScaled  = 1000 - penMag
  }

  if thrAvg >= 1000 {
    let thrMag = ((thrAvg - 1000) * cScale) / 1000
    thrScaled  = 1000 + thrMag
  }
  if thrAvg < 1000 {
    let thrMag = ((1000 - thrAvg) * cScale) / 1000
    thrScaled  = 1000 - thrMag
  }

  // Clamp magnitude of delta to MAX_DELTA_1000
  if penScaled >= 1000 {
    let delta = penScaled - 1000
    let clamped = clampMag(delta)
    penScaled = 1000 + clamped
  }
  if penScaled < 1000 {
    let delta = 1000 - penScaled
    let clamped = clampMag(delta)
    penScaled = 1000 - clamped
  }

  if thrScaled >= 1000 {
    let delta = thrScaled - 1000
    let clamped = clampMag(delta)
    thrScaled = 1000 + clamped
  }
  if thrScaled < 1000 {
    let delta = 1000 - thrScaled
    let clamped = clampMag(delta)
    thrScaled = 1000 - clamped
  }

  // Write domain antinode to pool for reporting
  meta.gov.pool.antinode = antinode

  // Emit domain result into pool accumulators (weighted by signal mass for pool merge)
  // Pool accumulates: sum(penScaled × sig) / sum(sig)
  // Caller (aggregatePool) reads the individual domain meta.gov.*.pen/thr/sig.
  // We re-use pen/thr fields in meta to store the scaled values post-apply.
  if domainId == DOM_GLOBAL {
    meta.gov.gl.pen = penScaled
    meta.gov.gl.thr = thrScaled
  }
  if domainId == DOM_TREASURY {
    meta.gov.tr.pen = penScaled
    meta.gov.tr.thr = thrScaled
  }
  if domainId == DOM_GAME {
    meta.gov.gm.pen = penScaled
    meta.gov.gm.thr = thrScaled
  }
  if domainId == DOM_MINING {
    meta.gov.mn.pen = penScaled
    meta.gov.mn.thr = thrScaled
  }

  return PASS
}

// ── aggregatePool: merge treasury + game + mining into one output ─────────────
// Call after observeTreasury + observeGame + observeMining for all agents,
// then call applyDomain for each.
//
// dominantTrIdx, dominantGmIdx, dominantMnIdx: highest-signal typeIndex per domain.
// isCollapsed: 1=collapsed 0=uncollapsed
// basePen1000, baseThr1000: current CHROMA_*_MULT × 1000 (e.g. 1200 for 1.20)
//
// Writes final output to meta.gov.pool.*
// Returns 1 if any domain halted, 0 if all pass.

function aggregatePool(dominantTrIdx, dominantGmIdx, dominantMnIdx, isCollapsed, basePen1000, baseThr1000) {
  let trHalt = applyDomain(DOM_TREASURY, isCollapsed, dominantTrIdx)
  let gmHalt = applyDomain(DOM_GAME,     isCollapsed, dominantGmIdx)
  let mnHalt = applyDomain(DOM_MINING,   isCollapsed, dominantMnIdx)

  // Collect non-halted domain outputs (signal-mass-weighted merge)
  let totalSig = 0
  let penAcc   = 0
  let thrAcc   = 0

  if trHalt == PASS {
    totalSig = totalSig + meta.gov.tr.sig
    penAcc   = penAcc + (meta.gov.tr.pen * meta.gov.tr.sig)
    thrAcc   = thrAcc + (meta.gov.tr.thr * meta.gov.tr.sig)
  }
  if gmHalt == PASS {
    totalSig = totalSig + meta.gov.gm.sig
    penAcc   = penAcc + (meta.gov.gm.pen * meta.gov.gm.sig)
    thrAcc   = thrAcc + (meta.gov.gm.thr * meta.gov.gm.sig)
  }
  if mnHalt == PASS {
    totalSig = totalSig + meta.gov.mn.sig
    penAcc   = penAcc + (meta.gov.mn.pen * meta.gov.mn.sig)
    thrAcc   = thrAcc + (meta.gov.mn.thr * meta.gov.mn.sig)
  }

  if totalSig == 0 {
    // All domains halted — return base multipliers unchanged
    meta.gov.pool.pen_mult  = basePen1000
    meta.gov.pool.thr_mult  = baseThr1000
    meta.gov.pool.pen_delta = 0
    meta.gov.pool.thr_delta = 0
    meta.gov.pool.gated    = 1
    meta.gov.pool.sealed    = 1
    return 1
  }

  // Weighted average offset
  let netPen = penAcc / totalSig
  let netThr = thrAcc / totalSig

  // Convert offset to signed delta and apply to base
  let finalPen = basePen1000
  let finalThr = baseThr1000

  if netPen >= 1000 {
    let d = netPen - 1000
    finalPen = basePen1000 + d
  }
  if netPen < 1000 {
    let d = 1000 - netPen
    if finalPen > d {
      finalPen = basePen1000 - d
    }
  }

  if netThr >= 1000 {
    let d = netThr - 1000
    finalThr = baseThr1000 + d
  }
  if netThr < 1000 {
    let d = 1000 - netThr
    if finalThr > d {
      finalThr = baseThr1000 - d
    }
  }

  meta.gov.pool.pen_mult  = finalPen
  meta.gov.pool.thr_mult  = finalThr
  meta.gov.pool.pen_delta = netPen
  meta.gov.pool.thr_delta = netThr
  meta.gov.pool.gated    = 0
  meta.gov.pool.sealed    = 1

  return PASS
}

// ── resetDomain: clear one domain's accumulators between rounds ───────────────

function resetGlobal() {
  meta.gov.gl.sig   = 0
  meta.gov.gl.pen   = 0
  meta.gov.gl.thr   = 0
  meta.gov.gl.cpres = 0
  meta.gov.gl.susp  = 0
  meta.gov.gl.total = 0
  meta.gov.gl.gated  = 0
  return 0
}

function resetTreasury() {
  meta.gov.tr.sig   = 0
  meta.gov.tr.pen   = 0
  meta.gov.tr.thr   = 0
  meta.gov.tr.cpres = 0
  meta.gov.tr.susp  = 0
  meta.gov.tr.total = 0
  meta.gov.tr.gated  = 0
  return 0
}

function resetGame() {
  meta.gov.gm.sig   = 0
  meta.gov.gm.pen   = 0
  meta.gov.gm.thr   = 0
  meta.gov.gm.cpres = 0
  meta.gov.gm.susp  = 0
  meta.gov.gm.total = 0
  meta.gov.gm.gated  = 0
  return 0
}

function resetMining() {
  meta.gov.mn.sig   = 0
  meta.gov.mn.pen   = 0
  meta.gov.mn.thr   = 0
  meta.gov.mn.cpres = 0
  meta.gov.mn.susp  = 0
  meta.gov.mn.total = 0
  meta.gov.mn.gated  = 0
  return 0
}

function resetPool() {
  meta.gov.pool.pen_delta = 0
  meta.gov.pool.thr_delta = 0
  meta.gov.pool.pen_mult  = 1000
  meta.gov.pool.thr_mult  = 1000
  meta.gov.pool.gated    = 0
  meta.gov.pool.antinode  = 0
  meta.gov.pool.sealed    = 0
  return 0
}

// ── zeroize: full reset of all state ─────────────────────────────────────────

function zeroize() {
  resetGlobal()
  resetTreasury()
  resetGame()
  resetMining()
  resetPool()
  return 0
}
