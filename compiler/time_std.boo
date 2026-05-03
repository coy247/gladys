// concept: Garzaro
// booLangID: anchor — derive via BLAKE3(pubkey ‖ chainID ‖ "gladys:time_std")
// source: gladys/compiler/time_std.boo
// verdict: ABSORB
// binary_compat: v2.7 PASS + v3.2 PASS
// grammar: boo-grammar.md BNF compliant

// TIME STANDARD FOR booLang
//
// booLang is integer-only. Time is no exception.
//
// CANONICAL FORM: integer epoch milliseconds (Unix time × 1000)
//   meta.time.ts_ms = integer, always ≥ 0
//   Resolution: 1ms — sufficient for all kanban and governance operations.
//   Source: host runtime provides NOW_MS via injected constant before execution.
//
// ISO STRINGS ARE OUTPUT-ONLY:
//   Never store an ISO timestamp in meta state.
//   ISO conversion happens at the display/logging boundary, outside the .boo layer.
//   A .boo file that stores "2026-05-03T09:00:00.000Z" as state is non-compliant.
//
// FIELD NAME CONVENTION:
//   ts_ms        integer epoch ms — stored state (canonical)
//   ts_offset    integer ms offset from a base ts_ms — for relative durations
//   age_ms       computed: NOW_MS - ts_ms — always non-negative
//   stale        1 if age_ms > threshold, 0 if fresh
//
// FALLBACK RULE:
//   If ts_ms is absent or unknown, stale = 1. Never default to 0 (epoch 1970).
//   A missing timestamp is unknown, not ancient.
//   In TypeScript bridge: `ts = entry.ts_ms ?? entry.ts ?? null; age = ts ? NOW - ts : Infinity`
//
// THRESHOLDS:
//   All staleness/expiry thresholds are expressed in integer milliseconds.
//   No minutes or hours as floats — multiply cleanly.
//   1 minute  =  60000 ms
//   5 minutes = 300000 ms
//   1 hour    = 3600000 ms
//   1 day     = 86400000 ms

// ── NOW injection ─────────────────────────────────────────────────────────────
//
// The host runtime MUST inject NOW_MS before calling any function in this module.
// booLang has no system clock access. The host resolves it once per tick.
//
// meta.time.now_ms     = injected by runtime (integer epoch ms)
// meta.time.tick_id    = monotonic tick counter (integer, starts at 0)
//
// Usage pattern:
//   observeTime()     — snapshot now_ms into meta.time.ts_ms for a named event
//   ageOf(ts_ms)      — returns integer ms elapsed since ts_ms
//   isStale(ts_ms, threshold_ms) — 1 if elapsed ≥ threshold_ms, 0 otherwise

// ── Constants ─────────────────────────────────────────────────────────────────

let TIME_MIN_MS  = 60000
let TIME_5MIN_MS = 300000
let TIME_HOUR_MS = 3600000
let TIME_DAY_MS  = 86400000

// Z4 harmonic² thresholds (antinode² × TIME_MIN_MS):
//   tier 1: 1²  =   1 min =  60000 ms
//   tier 2: 2²  =   4 min = 240000 ms
//   tier 3: 4²  =  16 min = 960000 ms
//   tier 4: 8²  =  64 min = 3840000 ms
//   tier 5: 12² = 144 min = 8640000 ms

let TIME_TIER1_MS = 60000
let TIME_TIER2_MS = 240000
let TIME_TIER3_MS = 960000
let TIME_TIER4_MS = 3840000
let TIME_TIER5_MS = 8640000

// ── State ─────────────────────────────────────────────────────────────────────

meta.time.now_ms   = 0    // injected by host runtime before each tick
meta.time.tick_id  = 0    // monotonic counter
meta.time.ts_ms    = 0    // last event timestamp
meta.time.age_ms   = 0    // age of last event at time of last check
meta.time.stale    = 0    // 1 if last age exceeded active threshold
meta.time.sealed   = 0

// ── Functions ─────────────────────────────────────────────────────────────────

function observeTime()
  // Record current tick as a timestamped event.
  // Host must have set meta.time.now_ms before calling.
  meta.time.ts_ms  = meta.time.now_ms
  meta.time.age_ms = 0
  meta.time.stale  = 0
  return meta.time.ts_ms
end

function ageOf(ts_ms)
  // Returns integer ms elapsed since ts_ms.
  // If ts_ms = 0 (not set), returns TIME_DAY_MS as sentinel (treat as stale).
  if ts_ms == 0
    return TIME_DAY_MS
  end
  let age = meta.time.now_ms - ts_ms
  if age < 0
    return 0
  end
  return age
end

function isStale(ts_ms, threshold_ms)
  // Returns 1 if elapsed time since ts_ms >= threshold_ms.
  // Returns 1 if ts_ms = 0 (unknown = treat as stale, never as fresh).
  if ts_ms == 0
    return 1
  end
  let age = ageOf(ts_ms)
  if age >= threshold_ms
    return 1
  end
  return 0
end

function staleTier(ts_ms)
  // Returns the Z4 tier of staleness (0=fresh through 5=catastrophic).
  // Tier 0: within grace (< tier 1 threshold)
  // Tier 5: catastrophic (≥ tier 5 threshold = 144 min)
  if ts_ms == 0
    return 5
  end
  let age = ageOf(ts_ms)
  if age >= TIME_TIER5_MS
    return 5
  end
  if age >= TIME_TIER4_MS
    return 4
  end
  if age >= TIME_TIER3_MS
    return 3
  end
  if age >= TIME_TIER2_MS
    return 2
  end
  if age >= TIME_TIER1_MS
    return 1
  end
  return 0
end

function zeroize()
  meta.time.now_ms  = 0
  meta.time.tick_id = 0
  meta.time.ts_ms   = 0
  meta.time.age_ms  = 0
  meta.time.stale   = 0
  meta.time.sealed  = 0
end
