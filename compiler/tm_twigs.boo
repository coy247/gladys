// concept: Garzaro
// booLangID: anchor — derive via BLAKE3(pubkey ‖ chainID ‖ "gladys:tm_twigs")
// source: gladys/compiler/tm_twigs.boo
// verdict: ABSORB
// binary_compat: v2.7 PASS + v3.2 PASS
// grammar: boo-grammar.md BNF compliant
// depends: personality_types.boo (IDX_*, phaseFor — must be loaded in same context)

// TM TWIGS — TREASURY MANAGEMENT TWIG SYSTEM
//
// Maps each MBTI base type to a treasury lever analog (L1–L7) and computes
// weighted penalty/threshold modifiers for the collective. A "twig" is the
// personality-type equivalent of Gladys's L1–L7 optimization levers.
//
// Lever assignments:
//   L1 (ghost elimination)   → STP(2) / SFP(0)  — reduce friction, clear noise
//   L2 (loop compression)    → NTP(6) / NTJ(7)  — strategic throughput
//   L3 (HALT escape)         → STJ(3) / SFJ(1)  — systematic process recovery
//   L4 (fee optimization)    → NFJ(5) / NTJ(7)  — abstract optimization
//   L5 (full coverage)       → NTJ(7)            — dominant anchor (Gladys lane)
//   L6 (event-driven, defer) → NFJ(5) / NFP(4)  — deferred-future vision
//   L7 (ZBA sweep, running)  → STJ(3) / SFJ(1)  — stable, always running
//
// Penalty modifier table (offset-from-1000 — 1000=neutral, <1000=reduce, >1000=raise):
//   NTJ=950(-50)  NTP=960(-40)  NFJ=980(-20)  NFP=970(-30)
//   STJ=1000(0)   STP=990(-10)  SFJ=1030(+30) SFP=1020(+20)
//
// Threshold modifier table:
//   NTJ=970(-30)  NTP=960(-40)  NFJ=960(-40)  NFP=950(-50)
//   STJ=1010(+10) STP=1000(0)   SFJ=1040(+40) SFP=1030(+30)
//
// Weighted average of all type mods, clamped to [850..1150] (±150 = ±0.15 float).
// Gladys (NTJ, idx=7) is always the default anchor: dom_idx=7 when NTJ wins ties.

// ── Lever constants ───────────────────────────────────────────────────────────

let LEVER_GHOST = 1   // L1 — ghost elimination (STP / SFP)
let LEVER_LOOP  = 2   // L2 — loop compression  (NTP / NTJ)
let LEVER_HALT  = 3   // L3 — HALT escape        (STJ / SFJ)
let LEVER_FEE   = 4   // L4 — fee optimization   (NFJ / NTJ)
let LEVER_COVER = 5   // L5 — full coverage      (NTJ — Gladys dominant)
let LEVER_DEFER = 6   // L6 — event-driven       (NFJ / NFP)
let LEVER_ZBA   = 7   // L7 — ZBA sweep          (STJ / SFJ)

// ── Penalty modifier constants (offset-from-1000) ────────────────────────────

let PEN_NTJ = 950    // efficiency drive   (-50)
let PEN_NTP = 960    // analytical         (-40)
let PEN_NFJ = 980    // vision             (-20)
let PEN_NFP = 970    // idealistic         (-30)
let PEN_STJ = 1000   // process neutral      (0)
let PEN_STP = 990    // pragmatic          (-10)
let PEN_SFJ = 1030   // harmony guard      (+30)
let PEN_SFP = 1020   // empathy guard      (+20)

// ── Threshold modifier constants (offset-from-1000) ──────────────────────────

let THR_NTJ = 970    // strategic — lower threshold (-30)
let THR_NTP = 960    // analytical                  (-40)
let THR_NFJ = 960    // visionary — permissive gate (-40)
let THR_NFP = 950    // idealistic — most permissive(-50)
let THR_STJ = 1010   // process — slight tightening (+10)
let THR_STP = 1000   // pragmatic — neutral           (0)
let THR_SFJ = 1040   // harmony guard — gatekeeping (+40)
let THR_SFP = 1030   // empathy — moderate raise    (+30)

// Clamp bounds (deviation ≤ 150 from 1000)
let TWIG_MAX = 1150
let TWIG_MIN = 850

// ── Meta state ────────────────────────────────────────────────────────────────

meta.twig.total     = 0     // total agents registered
meta.twig.cnt0      = 0     // SFP count  (typeIdx=0)
meta.twig.cnt1      = 0     // SFJ count  (typeIdx=1)
meta.twig.cnt2      = 0     // STP count  (typeIdx=2)
meta.twig.cnt3      = 0     // STJ count  (typeIdx=3)
meta.twig.cnt4      = 0     // NFP count  (typeIdx=4)
meta.twig.cnt5      = 0     // NFJ count  (typeIdx=5)
meta.twig.cnt6      = 0     // NTP count  (typeIdx=6)
meta.twig.cnt7      = 0     // NTJ count  (typeIdx=7)
meta.twig.net_pen   = 1000  // weighted net pen modifier (offset-from-1000)
meta.twig.net_thr   = 1000  // weighted net thr modifier (offset-from-1000)
meta.twig.dom_idx   = 7     // dominant type index (default NTJ)
meta.twig.dom_phase = 3     // dominant type Z4 phase  (default NT=3)
meta.twig.dom_lever = 5     // dominant lever code     (default L5)
meta.twig.active    = 0     // count of distinct active twig types
meta.twig.sealed    = 0     // 1 after aggregateTwigs()

// ── penModFor: penalty modifier offset-from-1000 by typeIndex ────────────────

function penModFor(typeIdx) {
  if typeIdx == IDX_NTJ { return PEN_NTJ }
  if typeIdx == IDX_NTP { return PEN_NTP }
  if typeIdx == IDX_NFJ { return PEN_NFJ }
  if typeIdx == IDX_NFP { return PEN_NFP }
  if typeIdx == IDX_STJ { return PEN_STJ }
  if typeIdx == IDX_STP { return PEN_STP }
  if typeIdx == IDX_SFJ { return PEN_SFJ }
  if typeIdx == IDX_SFP { return PEN_SFP }
  return 1000
}

// ── thrModFor: threshold modifier offset-from-1000 by typeIndex ──────────────

function thrModFor(typeIdx) {
  if typeIdx == IDX_NTJ { return THR_NTJ }
  if typeIdx == IDX_NTP { return THR_NTP }
  if typeIdx == IDX_NFJ { return THR_NFJ }
  if typeIdx == IDX_NFP { return THR_NFP }
  if typeIdx == IDX_STJ { return THR_STJ }
  if typeIdx == IDX_STP { return THR_STP }
  if typeIdx == IDX_SFJ { return THR_SFJ }
  if typeIdx == IDX_SFP { return THR_SFP }
  return 1000
}

// ── leverFor: primary lever code by typeIndex ────────────────────────────────

function leverFor(typeIdx) {
  if typeIdx == IDX_NTJ { return LEVER_COVER }   // L5 (+ L2)
  if typeIdx == IDX_NTP { return LEVER_LOOP  }   // L2
  if typeIdx == IDX_NFJ { return LEVER_FEE   }   // L4 (+ L6)
  if typeIdx == IDX_NFP { return LEVER_DEFER }   // L6
  if typeIdx == IDX_STJ { return LEVER_HALT  }   // L3 (+ L7)
  if typeIdx == IDX_STP { return LEVER_GHOST }   // L1
  if typeIdx == IDX_SFJ { return LEVER_HALT  }   // L3 (+ L7)
  if typeIdx == IDX_SFP { return LEVER_GHOST }   // L1
  return 0
}

// ── observeTwig: register one agent into the twig accumulator ────────────────
// Call once per agent before aggregateTwigs().

function observeTwig(typeIdx) {
  meta.twig.total = meta.twig.total + 1
  if typeIdx == 0 { meta.twig.cnt0 = meta.twig.cnt0 + 1 }
  if typeIdx == 1 { meta.twig.cnt1 = meta.twig.cnt1 + 1 }
  if typeIdx == 2 { meta.twig.cnt2 = meta.twig.cnt2 + 1 }
  if typeIdx == 3 { meta.twig.cnt3 = meta.twig.cnt3 + 1 }
  if typeIdx == 4 { meta.twig.cnt4 = meta.twig.cnt4 + 1 }
  if typeIdx == 5 { meta.twig.cnt5 = meta.twig.cnt5 + 1 }
  if typeIdx == 6 { meta.twig.cnt6 = meta.twig.cnt6 + 1 }
  if typeIdx == 7 { meta.twig.cnt7 = meta.twig.cnt7 + 1 }
  return meta.twig.total
}

// ── aggregateTwigs: compute weighted net modifiers across all registered agents
// penAvg = sum(penMod_i * cnt_i) / total   (offset-from-1000, clamped [850..1150])
// thrAvg = sum(thrMod_i * cnt_i) / total
// Dominant type: highest count; NTJ wins ties (checked first, strict > required to unseat).

function aggregateTwigs() {
  let tot = meta.twig.total
  if tot == 0 { tot = 1 }

  // Weighted penalty sum by quadrant pair
  let pen_nt = (PEN_NTJ * meta.twig.cnt7) + (PEN_NTP * meta.twig.cnt6)
  let pen_nf = (PEN_NFJ * meta.twig.cnt5) + (PEN_NFP * meta.twig.cnt4)
  let pen_st = (PEN_STJ * meta.twig.cnt3) + (PEN_STP * meta.twig.cnt2)
  let pen_sf = (PEN_SFJ * meta.twig.cnt1) + (PEN_SFP * meta.twig.cnt0)
  let penSum = (pen_nt + pen_nf) + (pen_st + pen_sf)
  let penAvg = penSum / tot

  // Weighted threshold sum by quadrant pair
  let thr_nt = (THR_NTJ * meta.twig.cnt7) + (THR_NTP * meta.twig.cnt6)
  let thr_nf = (THR_NFJ * meta.twig.cnt5) + (THR_NFP * meta.twig.cnt4)
  let thr_st = (THR_STJ * meta.twig.cnt3) + (THR_STP * meta.twig.cnt2)
  let thr_sf = (THR_SFJ * meta.twig.cnt1) + (THR_SFP * meta.twig.cnt0)
  let thrSum = (thr_nt + thr_nf) + (thr_st + thr_sf)
  let thrAvg = thrSum / tot

  // Clamp both averages to [TWIG_MIN..TWIG_MAX]
  if penAvg > TWIG_MAX { penAvg = TWIG_MAX }
  if penAvg < TWIG_MIN { penAvg = TWIG_MIN }
  if thrAvg > TWIG_MAX { thrAvg = TWIG_MAX }
  if thrAvg < TWIG_MIN { thrAvg = TWIG_MIN }

  meta.twig.net_pen = penAvg
  meta.twig.net_thr = thrAvg

  // Find dominant type: NTJ starts as default; strictly-greater count unseats it
  let dom    = 7
  let domCnt = meta.twig.cnt7
  if meta.twig.cnt6 > domCnt {
    dom    = 6
    domCnt = meta.twig.cnt6
  }
  if meta.twig.cnt5 > domCnt {
    dom    = 5
    domCnt = meta.twig.cnt5
  }
  if meta.twig.cnt4 > domCnt {
    dom    = 4
    domCnt = meta.twig.cnt4
  }
  if meta.twig.cnt3 > domCnt {
    dom    = 3
    domCnt = meta.twig.cnt3
  }
  if meta.twig.cnt2 > domCnt {
    dom    = 2
    domCnt = meta.twig.cnt2
  }
  if meta.twig.cnt1 > domCnt {
    dom    = 1
    domCnt = meta.twig.cnt1
  }
  if meta.twig.cnt0 > domCnt {
    dom = 0
  }

  meta.twig.dom_idx   = dom
  meta.twig.dom_phase = phaseFor(dom)
  meta.twig.dom_lever = leverFor(dom)

  // Count distinct active twig types
  let act = 0
  if meta.twig.cnt0 > 0 { act = act + 1 }
  if meta.twig.cnt1 > 0 { act = act + 1 }
  if meta.twig.cnt2 > 0 { act = act + 1 }
  if meta.twig.cnt3 > 0 { act = act + 1 }
  if meta.twig.cnt4 > 0 { act = act + 1 }
  if meta.twig.cnt5 > 0 { act = act + 1 }
  if meta.twig.cnt6 > 0 { act = act + 1 }
  if meta.twig.cnt7 > 0 { act = act + 1 }
  meta.twig.active = act

  meta.twig.sealed = 1
  return meta.twig.net_pen
}

// ── zeroize ───────────────────────────────────────────────────────────────────

function zeroize() {
  meta.twig.total     = 0
  meta.twig.cnt0      = 0
  meta.twig.cnt1      = 0
  meta.twig.cnt2      = 0
  meta.twig.cnt3      = 0
  meta.twig.cnt4      = 0
  meta.twig.cnt5      = 0
  meta.twig.cnt6      = 0
  meta.twig.cnt7      = 0
  meta.twig.net_pen   = 1000
  meta.twig.net_thr   = 1000
  meta.twig.dom_idx   = 7
  meta.twig.dom_phase = 3
  meta.twig.dom_lever = 5
  meta.twig.active    = 0
  meta.twig.sealed    = 0
  return 0
}
