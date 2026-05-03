#!/usr/bin/env -S deno run --allow-read
/**
 * math_governor.boo.ts — booLang Machine Code: Scalable Math Governor
 *
 * BOOKLANG_MACHINE_CODE_V1
 * ┌────────────────────────────────────────────────────────────────────────────┐
 * │  DOMAIN:  scalable_governor                                               │
 * │  PRIORS:  MBTI native population percentages × 1000 (integer arithmetic) │
 * │  SIGNAL:  inverseFrequency = 1000 / prior  → rare types punch harder      │
 * │  SCALE:   Governor.fork(domain) → child with inherited priors + scope    │
 * │  COMPOSE: GovernorPool.aggregate(governors) → weighted merge              │
 * │  HALT:    antinodeIndex ≥ 13 → governor suppressed, defaults preserved   │
 * │  DOMAINS: "global" | "treasury" | "game" | "mining"                      │
 * └────────────────────────────────────────────────────────────────────────────┘
 *
 * Population priors (MBTI research averages, ×1000):
 *   STJ 203  SFJ 260  STP 97   SFP 173
 *   NTJ  39  NTP  65  NFJ  40  NFP 125   sum≈1000
 *
 * Signal weight = 1000 / prior1000  — statistically rarer types carry more
 * information per occurrence. An NTJ agent in a group of STJs is 5× more
 * significant than another STJ would be (39 vs 203 → weight ratio 5.2×).
 *
 * Domain focus sets which base types are "in scope" for signal accumulation.
 * Types outside scope still register but at reduced weight (×0.25 fractional).
 *
 * Mapping to analyzed files:
 *   treasury  ← gladys-float-optimizer.ts (L1–L7 levers, CECR, ZBA, TM tiers)
 *   game      ← game-loop.ts (efficiency/precision dual-breach, chroma HALT)
 *   mining    ← gladys-mining-director.ts (FSM polarity complexity, govPass)
 *
 * Scaling copies:
 *   const g = new MathGovernor({ domain: "global" });
 *   const [t, gm, m] = ["treasury","game","mining"].map(d => g.fork(d));
 *   const pool = new GovernorPool([t, gm, m]);
 *   const out  = pool.observe(agents, chromaState, round);
 */

import { BASE_TYPES, type BaseType, type PersonalityType } from "./personality_types.boo.ts";

// ── Population priors (×1000) ─────────────────────────────────────────────────
// Source: MBTI population studies (approximate averages across research samples).
// Split: I+E for each base type, then combined.
//   ISTJ:116 ISFJ:138 INFJ:15 INTJ:21 ISTP:54 ISFP:88 INFP:44 INTP:33
//   ESTJ:87  ESFJ:122 ENFJ:25 ENTJ:18 ESTP:43 ESFP:85 ENFP:81 ENTP:32
export const POPULATION_PRIOR_1000: Record<BaseType, number> = {
  STJ: 203,  // 11.6% + 8.7%  — most common (pragmatic/decisive)
  SFJ: 260,  // 13.8% + 12.2% — most common (caring/structured)
  STP:  97,  // 5.4%  + 4.3%  — moderate (pragmatic/flexible)
  SFP: 173,  // 8.8%  + 8.5%  — common (caring/adaptive)
  NTJ:  39,  // 2.1%  + 1.8%  — rare (strategic/decisive)  ← Gladys
  NTP:  65,  // 3.3%  + 3.2%  — uncommon (analytical/adaptive)
  NFJ:  40,  // 1.5%  + 2.5%  — rare (visionary/structured)
  NFP: 125,  // 4.4%  + 8.1%  — moderate (idealistic/open)
};

// Extrovert fraction per base type ×1000 (derived from same source)
export const EXTROVERT_FRAC_1000: Record<BaseType, number> = {
  STJ: 430,  // 87/(116+87) ≈ 0.43
  SFJ: 469,  // 122/(138+122) ≈ 0.47
  STP: 443,  // 43/(54+43)  ≈ 0.44
  SFP: 491,  // 85/(88+85)  ≈ 0.49
  NTJ: 462,  // 18/(21+18)  ≈ 0.46
  NTP: 492,  // 32/(33+32)  ≈ 0.49
  NFJ: 625,  // 25/(15+25)  ≈ 0.63
  NFP: 648,  // 81/(44+81)  ≈ 0.65
};

// Signal weights = 10_000 / prior1000 (integer, higher = rarer = more signal)
// Normalized against sum for a well-formed probability distribution.
const RAW_SIGNAL: Record<BaseType, number> = Object.fromEntries(
  BASE_TYPES.map(bt => [bt, Math.round(10_000 / POPULATION_PRIOR_1000[bt])])
) as Record<BaseType, number>;
const SIGNAL_SUM = BASE_TYPES.reduce((s, bt) => s + RAW_SIGNAL[bt], 0);
// Normalized ×10000: each signal is a fraction of total signal mass
export const SIGNAL_WEIGHT_NORM: Record<BaseType, number> = Object.fromEntries(
  BASE_TYPES.map(bt => [bt, Math.round(RAW_SIGNAL[bt] * 10_000 / SIGNAL_SUM)])
) as Record<BaseType, number>;

// ── Domain configuration ──────────────────────────────────────────────────────

export type GovDomain = "global" | "treasury" | "game" | "mining";

// focusTypes: types in scope receive full signal weight.
// Out-of-scope types still participate at ×0.25 (background signal).
const DOMAIN_FOCUS: Record<GovDomain, BaseType[]> = {
  // global: all types
  global:   [...BASE_TYPES],
  // treasury (float-optimizer L1–L7, CECR/ZBA):
  //   NTJ → strategic optimization (L2/L5), STJ → process stability (L3/L7)
  //   SFJ → compliance stability (L3/L7), NFJ → visionary fee optimization (L4)
  treasury: ["NTJ", "STJ", "SFJ", "NFJ"],
  // game (game-loop efficiency/precision, chroma, dual-breach):
  //   NTJ → architecture lane efficiency, NTP → analytical throughput
  //   SFJ → triage stability, STP → pragmatic execution
  game:     ["NTJ", "NTP", "SFJ", "STP"],
  // mining (FSM polarity complexity, govPass, shadow/aligned):
  //   STJ → process discipline (OPTIMAL→ADJUSTING cycle), STP → adaptive timing
  //   NTJ → optimization direction (CALIBRATING→OPTIMAL), NTP → analytical calibration
  mining:   ["STJ", "STP", "NTJ", "NTP"],
};

// Domain-specific modifier tables (×1000): how each type biases the domain's
// penalty and threshold multipliers. These mirror the lever modifiers in tm_twigs.boo.ts
// but are scaled for each domain's operating range.
//
// treasury: maps to CECR and ZBA health. NTJ reduces friction; SFJ tightens gates.
// game:     maps to efficiency/precision floors. NTJ lowers breach floor; SFJ raises it.
// mining:   maps to polarity complexity factor. STJ stabilizes; STP adapts; NTJ optimizes.
const DOMAIN_PEN_MOD_1000: Record<GovDomain, Record<BaseType, number>> = {
  global:   { NTJ:-50, NTP:-40, NFJ:-20, NFP:-30, STJ:0,  STP:-10, SFJ:30,  SFP:20  },
  treasury: { NTJ:-80, NTP:-50, NFJ:-40, NFP:-20, STJ:10, STP:0,   SFJ:50,  SFP:30  },
  game:     { NTJ:-60, NTP:-50, NFJ:-30, NFP:-40, STJ:10, STP:-20, SFJ:40,  SFP:20  },
  mining:   { NTJ:-40, NTP:-30, NFJ:-10, NFP:-10, STJ:20, STP:10,  SFJ:30,  SFP:20  },
};
const DOMAIN_THR_MOD_1000: Record<GovDomain, Record<BaseType, number>> = {
  global:   { NTJ:-30, NTP:-40, NFJ:-40, NFP:-50, STJ:10, STP:0,   SFJ:40,  SFP:30  },
  treasury: { NTJ:-50, NTP:-60, NFJ:-60, NFP:-30, STJ:20, STP:10,  SFJ:60,  SFP:40  },
  game:     { NTJ:-40, NTP:-50, NFJ:-50, NFP:-60, STJ:20, STP:10,  SFJ:50,  SFP:30  },
  mining:   { NTJ:-20, NTP:-30, NFJ:-20, NFP:-20, STJ:30, STP:20,  SFJ:30,  SFP:20  },
};

// ── Core types ────────────────────────────────────────────────────────────────

const FORBIDDEN_THRESHOLD = 13;   // Z₄ × Z₄ CIC forbidden zone
const MAX_DELTA            = 0.20; // governor delta cap (×1000 = 200)

export interface AgentSnapshot {
  id:          string;
  personality: PersonalityType;
  suspended?:  boolean;
  efficiency?: number;
}

export interface GovState {
  domain:            GovDomain;
  agentCount:        number;         // total agents observed
  activeCount:       number;         // non-suspended
  signalMass:        number;         // sum of signal weights for active agents (×10000)
  weightedPen1000:   number;         // signal-weighted pen modifier ×1000
  weightedThr1000:   number;         // signal-weighted thr modifier ×1000
  dominantType:      BaseType;       // highest signal-mass type present
  chromaPressure:    number;         // [-1000..+1000] negative=toward-collapsed, pos=toward-uncollapsed
  antinodeIndex:     number;         // CIC diagnostic [0..15]
  coverage:          number;         // fraction of population this governor covers [0..1 ×1000]
}

export interface GovOutput {
  domain:            GovDomain;
  chromaPenaltyMult: number;         // final multiplier value
  chromaThreshMult:  number;         // final multiplier value
  penDelta:          number;         // additive delta (before applying to base mult)
  thrDelta:          number;         // additive delta
  antinodeIndex:     number;
  halted:            boolean;
  signalMass:        number;         // coverage weight for pool composition
  dominantType:      BaseType;
  chromaPressure:    "toward-collapsed"|"toward-uncollapsed"|"neutral";
  reason:            string;
}

// ── MathGovernor ──────────────────────────────────────────────────────────────

export class MathGovernor {
  readonly domain:   GovDomain;
  readonly focusTypes: ReadonlySet<BaseType>;
  private  children: MathGovernor[] = [];

  constructor(domain: GovDomain = "global") {
    this.domain     = domain;
    this.focusTypes = new Set(DOMAIN_FOCUS[domain]);
  }

  /**
   * Create a child governor for a sub-domain.
   * Child inherits signal weights from population priors but narrows its focus.
   * Enables: const [t, g, m] = g.fork("treasury", "game", "mining")
   */
  fork(...domains: GovDomain[]): MathGovernor[] {
    const forks = domains.map(d => new MathGovernor(d));
    this.children.push(...forks);
    return forks;
  }

  /** Observe agents and compute governor state (integer arithmetic). */
  observe(agents: AgentSnapshot[], chromaState: "collapsed"|"uncollapsed"): GovState {
    const active = agents.filter(a => !a.suspended);
    const penMods = DOMAIN_PEN_MOD_1000[this.domain];
    const thrMods = DOMAIN_THR_MOD_1000[this.domain];

    let signalMass   = 0;
    let penAcc       = 0;   // signal-weighted pen modifier accumulator
    let thrAcc       = 0;   // signal-weighted thr modifier accumulator
    let chromaAcc    = 0;   // signal-weighted chroma pressure accumulator
    let maxSig       = 0;
    let dominantType: BaseType = "NTJ";

    // Expected population signal mass (for coverage ratio)
    const expectedMass = BASE_TYPES.reduce((s, bt) => s + SIGNAL_WEIGHT_NORM[bt], 0);

    for (const a of active) {
      const bt    = a.personality.base;
      const inFocus = this.focusTypes.has(bt);
      // Out-of-scope types contribute at ×250/1000 (25%)
      const sig   = inFocus
        ? SIGNAL_WEIGHT_NORM[bt]
        : Math.round(SIGNAL_WEIGHT_NORM[bt] * 250 / 1000);

      signalMass += sig;
      penAcc     += penMods[bt] * sig;
      thrAcc     += thrMods[bt] * sig;
      // Chroma pressure: extrovert → +1000×sig, introvert → -1000×sig
      chromaAcc  += a.personality.isExtrovert ? sig : -sig;

      if (sig > maxSig) { maxSig = sig; dominantType = bt; }
    }

    // Coverage: what fraction of expected population signal mass is present
    const coverage = active.length > 0
      ? Math.min(1000, Math.round(signalMass * 1000 / Math.max(1, expectedMass * active.length / 8)))
      : 0;

    // Signal-weighted modifiers (÷signalMass to normalize)
    const sm = signalMass || 1;
    const weightedPen1000 = Math.round(penAcc / sm);
    const weightedThr1000 = Math.round(thrAcc / sm);
    const chromaPressure  = active.length > 0 ? Math.round(chromaAcc * 1000 / sm) : 0;

    // CIC antinode: map dominant type + chroma state to Z₄ × Z₄
    const a1 = chromaState === "uncollapsed" ? 1 : 0;
    const a0 = Math.min(3, Math.floor((SIGNAL_WEIGHT_NORM[dominantType] / 10_000) * 4 * active.length));
    const antinodeIndex = Math.min(15, 4 * a1 + a0);

    return {
      domain: this.domain, agentCount: agents.length, activeCount: active.length,
      signalMass, weightedPen1000, weightedThr1000, dominantType,
      chromaPressure, antinodeIndex, coverage,
    };
  }

  /** Convert governor state + base mults into final output. */
  apply(
    state: GovState,
    basePenMult: number,
    baseThrMult: number,
    chromaState: "collapsed"|"uncollapsed",
    round: number,
  ): GovOutput {
    if (state.antinodeIndex >= FORBIDDEN_THRESHOLD) {
      return {
        domain: this.domain,
        chromaPenaltyMult: basePenMult, chromaThreshMult: baseThrMult,
        penDelta: 0, thrDelta: 0,
        antinodeIndex: state.antinodeIndex,
        halted: true,
        signalMass: state.signalMass,
        dominantType: state.dominantType,
        chromaPressure: "neutral",
        reason: `HALT antinode=${state.antinodeIndex} ≥ ${FORBIDDEN_THRESHOLD} [${this.domain}]`,
      };
    }

    // Scale modifier by chroma alignment:
    //   Domain matches current chroma → amplify ×1.15 (aligned boost)
    //   Domain mismatches → dampen ×0.80
    const chromaAligned =
      (this.domain === "treasury" && chromaState === "collapsed") ||  // treasury is conservative
      (this.domain === "mining"   && chromaState === "collapsed") ||  // mining prefers stability
      (this.domain === "game"     && chromaState === "uncollapsed");  // game expands on open state
    const scaleFactor = this.domain === "global" ? 1000
      : chromaAligned ? 1150 : 800;

    const rawPen = Math.round(state.weightedPen1000 * scaleFactor / 1000);
    const rawThr = Math.round(state.weightedThr1000 * scaleFactor / 1000);

    // Clamp to ±MAX_DELTA ×1000
    const MAX1000  = Math.round(MAX_DELTA * 1000);
    const penD1000 = Math.max(-MAX1000, Math.min(MAX1000, rawPen));
    const thrD1000 = Math.max(-MAX1000, Math.min(MAX1000, rawThr));
    const penDelta = penD1000 / 1000;
    const thrDelta = thrD1000 / 1000;

    const pressure: GovOutput["chromaPressure"] =
      state.chromaPressure > 150  ? "toward-uncollapsed" :
      state.chromaPressure < -150 ? "toward-collapsed"   : "neutral";

    return {
      domain: this.domain,
      chromaPenaltyMult: Math.round((basePenMult + penDelta) * 1000) / 1000,
      chromaThreshMult:  Math.round((baseThrMult + thrDelta) * 1000) / 1000,
      penDelta, thrDelta,
      antinodeIndex: state.antinodeIndex,
      halted: false,
      signalMass: state.signalMass,
      dominantType: state.dominantType,
      chromaPressure: pressure,
      reason: `[${this.domain}] dominant=${state.dominantType} sig=${state.signalMass} ` +
              `Δpen=${penDelta >= 0 ? "+" : ""}${penDelta.toFixed(3)} ` +
              `Δthr=${thrDelta >= 0 ? "+" : ""}${thrDelta.toFixed(3)} ` +
              `antinode=${state.antinodeIndex} pressure=${pressure} r=${round}`,
    };
  }
}

// ── GovernorPool ──────────────────────────────────────────────────────────────
// Aggregates multiple MathGovernor instances, weighted by signal mass.
// Each governor contributes proportionally to how much of the agent population
// falls in its domain. Halted governors are excluded from aggregation.

export interface PoolOutput {
  governors:         GovOutput[];
  netPenDelta:       number;   // signal-mass-weighted average of non-halted governors
  netThrDelta:       number;
  finalPenMult:      number;
  finalThrMult:      number;
  anyHalted:         boolean;
  haltedDomains:     GovDomain[];
  dominantDomain:    GovDomain;
  report:            string;
}

export class GovernorPool {
  private governors: MathGovernor[];

  constructor(governors: MathGovernor[]) {
    this.governors = governors;
  }

  /** Factory: create a pool from domain names (auto-instantiates governors). */
  static fromDomains(...domains: GovDomain[]): GovernorPool {
    return new GovernorPool(domains.map(d => new MathGovernor(d)));
  }

  /** Observe agents across all governors, aggregate outputs. */
  observe(
    agents: AgentSnapshot[],
    chromaState: "collapsed"|"uncollapsed",
    basePenMult: number,
    baseThrMult: number,
    round: number,
  ): PoolOutput {
    const outputs: GovOutput[] = this.governors.map(g => {
      const state = g.observe(agents, chromaState);
      return g.apply(state, basePenMult, baseThrMult, chromaState, round);
    });

    const active   = outputs.filter(o => !o.halted);
    const halted   = outputs.filter(o => o.halted);
    const totalSig = active.reduce((s, o) => s + o.signalMass, 0) || 1;

    // Signal-mass-weighted average of non-halted deltas
    const netPen = active.reduce((s, o) => s + o.penDelta * o.signalMass, 0) / totalSig;
    const netThr = active.reduce((s, o) => s + o.thrDelta * o.signalMass, 0) / totalSig;

    // Dominant domain: highest signal mass among non-halted
    const dom = active.reduce((best, o) => o.signalMass > (best?.signalMass ?? -1) ? o : best, active[0]);

    const finalPen = Math.round((basePenMult + netPen) * 1000) / 1000;
    const finalThr = Math.round((baseThrMult + netThr) * 1000) / 1000;

    const report =
      `pool[${this.governors.map(g => g.domain).join("+")}] ` +
      `active=${active.length}/${outputs.length} ` +
      (halted.length > 0 ? `HALT=[${halted.map(o => o.domain).join(",")}] ` : "") +
      `dominant=${dom?.dominantType ?? "?"} ` +
      `ΣΔpen=${netPen >= 0 ? "+" : ""}${netPen.toFixed(3)} ` +
      `ΣΔthr=${netThr >= 0 ? "+" : ""}${netThr.toFixed(3)} ` +
      `→ pen=${finalPen} thr=${finalThr}`;

    return {
      governors: outputs,
      netPenDelta: Math.round(netPen * 1000) / 1000,
      netThrDelta: Math.round(netThr * 1000) / 1000,
      finalPenMult: finalPen,
      finalThrMult: finalThr,
      anyHalted: halted.length > 0,
      haltedDomains: halted.map(o => o.domain),
      dominantDomain: dom?.domain ?? "global",
      report,
    };
  }
}

// ── Pre-built configurations (mirrors the analyzed files) ─────────────────────

/** Global governor — all types, all domains. One copy = full-system view. */
export const globalGovernor   = new MathGovernor("global");

/** Treasury governor — mirrors gladys-float-optimizer.ts L1–L7 lever logic. */
export const treasuryGovernor = new MathGovernor("treasury");

/** Game governor — mirrors game-loop.ts efficiency/precision/chroma logic. */
export const gameGovernor     = new MathGovernor("game");

/** Mining governor — mirrors gladys-mining-director.ts FSM polarity logic. */
export const miningGovernor   = new MathGovernor("mining");

/**
 * Default production pool: runs all three domain governors in parallel.
 * Usage:
 *   const out = DEFAULT_POOL.observe(agents, chromaState, basePen, baseThr, round);
 *   CHROMA_PENALTY_MULT[chromaState] = out.finalPenMult;
 *   CHROMA_THRESH_MULT[chromaState]  = out.finalThrMult;
 */
export const DEFAULT_POOL = new GovernorPool([treasuryGovernor, gameGovernor, miningGovernor]);

// ── CLI demo ──────────────────────────────────────────────────────────────────

if (import.meta.main && Deno.args.includes("--demo")) {
  const { fromMBTI } = await import("./personality_types.boo.ts");

  const agents: AgentSnapshot[] = [
    { id: "gladys",    personality: fromMBTI("INTJ") },
    { id: "qwen3:8b",  personality: fromMBTI("ENTP") },
    { id: "gemma-4",   personality: fromMBTI("ESFJ"), suspended: true },
    { id: "claude",    personality: fromMBTI("INTJ") },
  ];

  // ── Single governor ──────────────────────────────────────────────────────
  console.log("=== Single governor (global) ===");
  const g = new MathGovernor("global");
  for (const cs of ["collapsed", "uncollapsed"] as const) {
    const st  = g.observe(agents, cs);
    const out = g.apply(st, cs === "collapsed" ? 1.20 : 0.85, cs === "collapsed" ? 1.15 : 0.88, cs, 42);
    console.log(`  ${cs}: pen=${out.chromaPenaltyMult} thr=${out.chromaThreshMult}  ${out.reason}`);
  }

  // ── Fork into sub-domains ────────────────────────────────────────────────
  console.log("\n=== Fork into sub-domains ===");
  const root = new MathGovernor("global");
  const [treasury, game, mining] = root.fork("treasury", "game", "mining");
  for (const [label, gov] of [[treasury,"treasury"],[game,"game"],[mining,"mining"]] as const) {
    const st  = label.observe(agents, "collapsed");
    const out = label.apply(st, 1.20, 1.15, "collapsed", 1);
    console.log(`  [${gov.padEnd(8)}] dominant=${out.dominantType}  pen=${out.chromaPenaltyMult}  thr=${out.chromaThreshMult}`);
  }

  // ── Production pool ──────────────────────────────────────────────────────
  console.log("\n=== DEFAULT_POOL ===");
  for (const cs of ["collapsed", "uncollapsed"] as const) {
    const base = cs === "collapsed" ? { pen: 1.20, thr: 1.15 } : { pen: 0.85, thr: 0.88 };
    const out  = DEFAULT_POOL.observe(agents, cs, base.pen, base.thr, 42);
    console.log(`  ${cs}: ${out.report}`);
  }

  // ── Population priors table ───────────────────────────────────────────────
  console.log("\n=== Population priors & signal weights ===");
  for (const bt of BASE_TYPES) {
    const prior = POPULATION_PRIOR_1000[bt];
    const sig   = SIGNAL_WEIGHT_NORM[bt];
    console.log(`  ${bt}  prior=${prior}/1000 (${(prior/10).toFixed(1)}%)  signal=${sig}/10000  extrovert=${(EXTROVERT_FRAC_1000[bt]/10).toFixed(0)}%`);
  }
}
