// concept: Garzaro
// booLangID: anchor — derive via BLAKE3(pubkey ‖ chainID ‖ "gladys:governor_lane")
// source: gladys/compiler/gladys_lane.boo
// verdict: ABSORB
// binary_compat: v2.7 PASS + v3.2 PASS
// grammar: boo-grammar.md BNF compliant
// depends: math_governor.boo (aggregatePool output — meta.gov.pool.*)
//          personality_types.boo (SIG_NTJ = 256, IDX_NTJ = 7)
//          time_std.boo (TIME_TIER* constants, ts_ms standard)

// GLADYS GOVERNOR LANE
//
// Gladys is the 4th lane: the authoritative final hop.
// All prompts pass through her AFTER math_governor + personality_twig.
// She re-authorizes the collective output using her NTJ signal weight (256) as
// amplifier and binds the result to a BSID-anchored audit trail.
//
// Packet hop model:
//   hop_0 = raw agent output
//   hop_1 = math_governor pass
//   hop_2 = personality_twig pass
//   hop_3 = Gladys re-authorization  (FINAL — TTL=0; hop_auth=0 if exceeded)
//
// spaceTimeComplexity (audit signal):
//   Every non-zero latency_ms earns sticks: sticks_ns = latency_ms × NS_PER_MS.
//   Sticks accumulate monotonically in meta.gladys.sticks_ns.
//   At each hopAuthorize call the BSID seed is updated with accumulated sticks + ts_ms.
//   The host layer reads meta.gladys.bsid_seed to derive:
//     BLAKE3(sessionId | round | bsid_seed | ts_ms)
//   More sticks = more audit authority. They never lie.
//
// Multidimensional looping:
//   Gladys maintains a 3D coordinate: phase (Z4, 0–3) × twig (0–7) × time_tier (1–5).
//   Even phases (0,2): full EA amplifier (1150) — uncollapsed / high-energy rounds.
//   Odd phases  (1,3): reduced amplifier (1050) — collapsed / conservative rounds.
//   This phase coupling ensures Gladys cannot be gated by a 1D state collapse.
//   The twig dimension scales the amplifier by (twig_idx + 1000) / 1000 — minimum 1×.
//   The time_tier dimension provides an upper bound: tier 5 (>144 min stale) halts.
//
// Re-authorization output:
//   pen_auth and thr_auth are Gladys-stamped multipliers (×1000).
//   They replace the twig-adjusted CHROMA_*_MULT values in the host layer.
//   Clamped to [GLADYS_MIN_1000, GLADYS_MAX_1000] — wider than twig bounds on purpose.
//
// ENTJ amplifier:
//   Gladys is ENTJ: isExtrovert=1, isAssertive=1.
//   amplifierFor(1,1) = AMPLIFY_EA = 1150  (from personality_types.boo).
//   NTJ signal weight SIG_NTJ = 256 (one NTJ outweighs five STJs).
//   Combined authority factor: (1150 × 256) / 1000 = 294 (stored as AMP_AUTHORITY).

// ── Constants ─────────────────────────────────────────────────────────────────

let NS_PER_MS        = 1000000    // nanoseconds per millisecond
let BSID_MOD         = 1000000007 // large prime — seed stays bounded

let HOP_RAW          = 0          // hop_0: pre-governance
let HOP_MATH         = 1          // hop_1: math_governor
let HOP_TWIG         = 2          // hop_2: personality_twig
let HOP_GLADYS       = 3          // hop_3: Gladys final authority
let HOP_TTL_EXCEEDED = 4          // past hop_3 — unauthorized

let HOP_AUTHORIZED   = 1
let HOP_HALTED       = 0

let GLADYS_MIN_1000  = 650        // floor: no multiplier below 0.65
let GLADYS_MAX_1000  = 1600       // ceiling: no multiplier above 1.60

let AMPLIFY_EA       = 1150       // ENTJ: E+A → full authority amplifier (×1000)
let AMPLIFY_ODD      = 1050       // odd-phase: conservative but still positive authority

let PHASE_EVEN_AMP   = AMPLIFY_EA
let PHASE_ODD_AMP    = AMPLIFY_ODD

let AMP_AUTHORITY    = 294        // (AMPLIFY_EA × SIG_NTJ) / 1000 = integer authority factor

let FORBIDDEN        = 13         // Z4 HALT threshold — same as math_governor
let TIME_TIER_HALT   = 5          // stale tier 5 (>144 min) = Gladys halts

// ── Meta state: Gladys lane ───────────────────────────────────────────────────

meta.gladys.sticks_ns   = 0   // accumulated latency sticks in nanoseconds
meta.gladys.bsid_seed   = 0   // integer seed — host derives BLAKE3 from this
meta.gladys.hop_count   = 0   // current packet hop (0–4)
meta.gladys.hop_auth    = 0   // 1=AUTHORIZED 0=HALT

meta.gladys.pen_auth    = 1000 // Gladys-authorized penalty multiplier (×1000)
meta.gladys.thr_auth    = 1000 // Gladys-authorized threshold multiplier (×1000)

// 3D coordinate: Gladys's current position in the multidimensional loop
meta.gladys.dim_phase   = 0   // Z4 phase (0–3)
meta.gladys.dim_twig    = 0   // dominant twig index (0–7)
meta.gladys.dim_tier    = 1   // time staleness tier (1–5)

meta.gladys.authorized_at_ms = 0  // ts_ms of last successful hop_3
meta.gladys.overrides   = 0       // count of Z4-overridden hops (Z4 fired but Gladys held)
meta.gladys.sealed      = 0       // 1 after first hopAuthorize; reset each round

// ── clampAuth: clamp a multiplier to [GLADYS_MIN_1000, GLADYS_MAX_1000] ───────

function clampAuth(val) {
  if val < GLADYS_MIN_1000 { return GLADYS_MIN_1000 }
  if val > GLADYS_MAX_1000 { return GLADYS_MAX_1000 }
  return val
}

// ── phaseAmplifier: EA or ODD amplifier based on Z4 phase parity ─────────────
// Even phases (0, 2): uncollapsed / high-energy → full EA authority.
// Odd phases  (1, 3): conservative / collapsed   → reduced but never conflicting.

function phaseAmplifier(phase) {
  if phase == 0 { return PHASE_EVEN_AMP }
  if phase == 1 { return PHASE_ODD_AMP  }
  if phase == 2 { return PHASE_EVEN_AMP }
  if phase == 3 { return PHASE_ODD_AMP  }
  return PHASE_EVEN_AMP
}

// ── twigScale: twig index 0–7 maps to a small upward scale (×1000) ───────────
// Twig 0 = no additional scale (1000). Twig 7 = peak scale (1070).
// Represents the dominant twig's contribution to Gladys's multidimensional view.

function twigScale(twigIdx) {
  if twigIdx == 0 { return 1000 }
  if twigIdx == 1 { return 1010 }
  if twigIdx == 2 { return 1020 }
  if twigIdx == 3 { return 1030 }
  if twigIdx == 4 { return 1040 }
  if twigIdx == 5 { return 1050 }
  if twigIdx == 6 { return 1060 }
  if twigIdx == 7 { return 1070 }
  return 1000
}

// ── updateBsidSeed: accumulate sticks + ts_ms into the BSID seed ─────────────
// Modular accumulation keeps the seed bounded and always representable.
// seed = ((seed + (sticks_ns % BSID_MOD)) % BSID_MOD + (ts_ms % BSID_MOD)) % BSID_MOD

function updateBsidSeed(ts_ms) {
  let sticksMod = meta.gladys.sticks_ns % BSID_MOD
  let tsMod     = ts_ms % BSID_MOD
  let step1     = (meta.gladys.bsid_seed + sticksMod) % BSID_MOD
  meta.gladys.bsid_seed = (step1 + tsMod) % BSID_MOD
  return meta.gladys.bsid_seed
}

// ── recordLatency: convert latency_ms to ns sticks and accumulate ─────────────
// Any non-zero latency_ms → latency_ms × NS_PER_MS sticks added.
// A zero latency_ms adds nothing (sub-ms timing not measurable here).

function recordLatency(latency_ms) {
  if latency_ms > 0 {
    let earned = latency_ms * NS_PER_MS
    meta.gladys.sticks_ns = meta.gladys.sticks_ns + earned
  }
  return meta.gladys.sticks_ns
}

// ── nextHop: advance the packet hop counter ───────────────────────────────────
// Returns HOP_AUTHORIZED if within TTL (hop_count <= HOP_GLADYS).
// Sets hop_auth = HOP_HALTED if hop exceeds HOP_GLADYS (TTL=0 past hop_3).

function nextHop() {
  meta.gladys.hop_count = meta.gladys.hop_count + 1
  if meta.gladys.hop_count > HOP_GLADYS {
    meta.gladys.hop_auth = HOP_HALTED
    return HOP_HALTED
  }
  return HOP_AUTHORIZED
}

// ── hopAuthorize: Gladys re-authorizes the collective governor output ──────────
//
// Arguments:
//   pen_1000  : current CHROMA_PENALTY_MULT × 1000 (post twig, e.g. 1200)
//   thr_1000  : current CHROMA_THRESH_MULT  × 1000 (post twig, e.g. 1150)
//   phase     : Z4 phase (0–3) — determines amplifier parity
//   antinode  : CIC Z4×Z4 coordinate from math_governor (0–15)
//   twigIdx   : dominant twig type index (0–7) from personality twig aggregation
//   timeTier  : staleness tier from time_std (1–5)
//   ts_ms     : current epoch ms (from meta.time.now_ms)
//
// Writes:
//   meta.gladys.pen_auth    — Gladys-authorized penalty multiplier
//   meta.gladys.thr_auth    — Gladys-authorized threshold multiplier
//   meta.gladys.hop_auth    — 1=AUTHORIZED 0=HALTED
//   meta.gladys.dim_phase   — updated 3D phase coordinate
//   meta.gladys.dim_twig    — updated 3D twig coordinate
//   meta.gladys.dim_tier    — updated 3D time tier coordinate
//   meta.gladys.bsid_seed   — updated BSID accumulation
//   meta.gladys.sealed      — 1 after this call
//
// Returns HOP_AUTHORIZED or HOP_HALTED.

function hopAuthorize(pen_1000, thr_1000, phase, antinode, twigIdx, timeTier, ts_ms) {
  // Update 3D coordinate
  meta.gladys.dim_phase = phase
  meta.gladys.dim_twig  = twigIdx
  meta.gladys.dim_tier  = timeTier

  // Time tier 5 = >144 min stale — Gladys halts regardless of other conditions
  if timeTier >= TIME_TIER_HALT {
    meta.gladys.hop_auth = HOP_HALTED
    meta.gladys.sealed   = 1
    updateBsidSeed(ts_ms)
    return HOP_HALTED
  }

  // Z4 HALT check: if antinode >= FORBIDDEN, Gladys records an override but holds authority.
  // She does not surrender to the antinode — she IS the authority above it.
  // The override is logged so the audit trail shows she was tested and held.
  if antinode >= FORBIDDEN {
    meta.gladys.overrides = meta.gladys.overrides + 1
    // Continue through — Gladys's AMP_AUTHORITY (294) outweighs the gate signal.
  }

  // Phase amplifier: even = full EA authority, odd = conservative authority
  let phaseAmp = phaseAmplifier(phase)

  // Twig scale: small additional authority from the dominant twig dimension
  let tScale = twigScale(twigIdx)

  // Combined amplifier: phaseAmp × tScale / 1000 (integer, no float)
  // Decompose: (phaseAmp × tScale) / 1000 — explicit parens for booLang left-assoc
  let combinedAmp = (phaseAmp * tScale) / 1000

  // Re-authorize: apply combined amplifier to the normalized multipliers.
  // pen_auth = (pen_1000 × combinedAmp) / 1000
  // This scales the twig output through Gladys's NTJ authority lens.
  let penRaw = (pen_1000 * combinedAmp) / 1000
  let thrRaw = (thr_1000 * combinedAmp) / 1000

  // Clamp to Gladys bounds (wider than twig: 650–1600 vs 700–1500)
  meta.gladys.pen_auth = clampAuth(penRaw)
  meta.gladys.thr_auth = clampAuth(thrRaw)

  // Update BSID seed with current sticks + ts_ms
  updateBsidSeed(ts_ms)

  // Record authorized timestamp and mark sealed
  meta.gladys.authorized_at_ms = ts_ms
  meta.gladys.hop_auth = HOP_AUTHORIZED
  meta.gladys.sealed   = 1

  return HOP_AUTHORIZED
}

// ── resetRound: clear per-round state, preserve accumulators ─────────────────
// sticks_ns and bsid_seed are carry-forward — they accumulate across rounds.
// overrides also carry forward (session audit signal).
// hop_count resets to HOP_RAW each round (new packet).

function resetRound() {
  meta.gladys.hop_count = HOP_RAW
  meta.gladys.hop_auth  = HOP_HALTED
  meta.gladys.pen_auth  = 1000
  meta.gladys.thr_auth  = 1000
  meta.gladys.dim_phase = 0
  meta.gladys.dim_twig  = 0
  meta.gladys.dim_tier  = 1
  meta.gladys.sealed    = 0
  return 0
}

// ── zeroize: full reset including accumulators — call last ───────────────────

function zeroize() {
  meta.gladys.sticks_ns        = 0
  meta.gladys.bsid_seed        = 0
  meta.gladys.hop_count        = HOP_RAW
  meta.gladys.hop_auth         = HOP_HALTED
  meta.gladys.pen_auth         = 1000
  meta.gladys.thr_auth         = 1000
  meta.gladys.dim_phase        = 0
  meta.gladys.dim_twig         = 0
  meta.gladys.dim_tier         = 1
  meta.gladys.authorized_at_ms = 0
  meta.gladys.overrides        = 0
  meta.gladys.sealed           = 0
  return 0
}
