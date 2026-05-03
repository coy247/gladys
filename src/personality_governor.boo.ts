#!/usr/bin/env -S deno run --allow-read
/**
 * personality_governor.boo.ts — booLang Machine Code: Personality Governor
 *
 * BOOKLANG_MACHINE_CODE_V1
 * ┌──────────────────────────────────────────────────────────────────────────┐
 * │  DOMAIN:  personality_normalization                                     │
 * │  INPUT:   active agents with personality types + live score state       │
 * │  OUTPUT:  net CHROMA_PENALTY_MULT + CHROMA_THRESH_MULT adjustments      │
 * │  CLAMP:   personality delta bounded to ±0.15 (governance takes priority) │
 * │  HALT:    antinodeIndex ≥ 13 → personality suppressed, gov defaults used │
 * └──────────────────────────────────────────────────────────────────────────┘
 *
 * Integration path for game-loop.ts:
 *   1. Call runPersonalityGovernor() after runGovernor() (math governor)
 *   2. If not halted: apply agg.netPenModifier and agg.netThrModifier as
 *      additive corrections on top of the math governor's output
 *   3. Log personality report on each round for distribution tracking
 *
 * The personality distribution itself is a game metric:
 *   - % NTJ (Gladys quadrant) = strategic efficiency pressure
 *   - % SFJ/SFP = collective stability bias (threshold inflation)
 *   - % NFP/NFJ = expansion bias (threshold deflation)
 *   - extrovert/introvert ratio → chroma pressure
 */

import {
  BASE_TYPES, TYPE_INDEX, GLADYS_TYPE,
  type BaseType, type PersonalityType, typeDistribution,
} from "./personality_types.boo.ts";
import {
  buildPersonalityTwigs, aggregateTwigModifiers,
  type PersonalityTwig, type TwigAggregation,
} from "./tm_twigs.boo.ts";

// ── Constants ─────────────────────────────────────────────────────────────────
const FORBIDDEN_THRESHOLD = 13;   // Z₄ × Z₄ CIC forbidden zone
const MAX_DELTA            = 0.15; // personality delta cap

// ── Input / Output types ───────────────────────────────────────────────────────

export interface AgentRecord {
  id:          string;
  personality: PersonalityType;
  efficiency?: number;   // optional — used for distribution weighting
  suspended?:  boolean;
}

export interface PersonalityGovInput {
  agents:           AgentRecord[];
  chromaState:      "collapsed" | "uncollapsed";
  mathGovAntinode:  number;   // antinodeIndex from math governor (pass-through)
  round:            number;
}

export interface PersonalityGovOutput {
  netPenModifier:  number;    // additive delta on chromaPenaltyMult
  netThrModifier:  number;    // additive delta on chromaThreshMult
  halted:          boolean;   // true when mathGovAntinode ≥ 13
  twigs:           PersonalityTwig[];
  aggregation:     TwigAggregation;
  distribution:    ReturnType<typeof typeDistribution>;
  extrovertRatio:  number;    // [0..1] — drives chroma pressure signal
  introvertRatio:  number;
  chromaPressure:  "neutral"|"toward-uncollapsed"|"toward-collapsed";
  report:          string;
}

// ── Main governor ──────────────────────────────────────────────────────────────

export function runPersonalityGovernor(input: PersonalityGovInput): PersonalityGovOutput {
  const { agents, chromaState, mathGovAntinode, round } = input;

  // Personality is suppressed when math governor has already HALTed
  if (mathGovAntinode >= FORBIDDEN_THRESHOLD) {
    const zeroAgg: TwigAggregation = {
      netPenModifier: 0, netThrModifier: 0,
      dominantPhase: 3, dominantType: "NTJ",
      activeTwigs: 0, report: "suppressed — math governor HALT",
    };
    return {
      netPenModifier: 0, netThrModifier: 0,
      halted: true,
      twigs: [], aggregation: zeroAgg,
      distribution: typeDistribution(agents),
      extrovertRatio: 0, introvertRatio: 0,
      chromaPressure: "neutral",
      report: `personality suppressed — mathGov antinode=${mathGovAntinode} ≥ ${FORBIDDEN_THRESHOLD}`,
    };
  }

  // Build twigs from active (non-suspended) agents
  const active = agents.filter(a => !a.suspended);
  const twigs  = buildPersonalityTwigs(active);
  const agg    = aggregateTwigModifiers(twigs);
  const dist   = typeDistribution(agents);  // include suspended for distribution metric

  // Extrovert/introvert pressure
  const total    = active.length || 1;
  const extCount = active.filter(a => a.personality.isExtrovert).length;
  const extRatio = extCount / total;
  const intRatio = 1 - extRatio;

  // Chroma pressure: extrovert majority → push toward uncollapsed; introvert → collapsed
  // Neutral band: ±15% from 50/50
  let chromaPressure: PersonalityGovOutput["chromaPressure"] = "neutral";
  if (extRatio > 0.65)      chromaPressure = "toward-uncollapsed";
  else if (intRatio > 0.65) chromaPressure = "toward-collapsed";

  // Scale modifiers by chroma alignment:
  //   If collective chroma pressure matches current chromaState → amplify slightly
  //   If mismatched → dampen slightly
  let penMod = agg.netPenModifier;
  let thrMod = agg.netThrModifier;
  if (
    (chromaPressure === "toward-uncollapsed" && chromaState === "uncollapsed") ||
    (chromaPressure === "toward-collapsed"   && chromaState === "collapsed")
  ) {
    // Aligned: amplify by 15% (integer: round to 3 decimal places)
    penMod = Math.round(penMod * 1150) / 1000;
    thrMod = Math.round(thrMod * 1150) / 1000;
  } else if (chromaPressure !== "neutral") {
    // Misaligned: dampen by 20%
    penMod = Math.round(penMod * 800) / 1000;
    thrMod = Math.round(thrMod * 800) / 1000;
  }

  // Final clamp
  penMod = Math.max(-MAX_DELTA, Math.min(MAX_DELTA, penMod));
  thrMod = Math.max(-MAX_DELTA, Math.min(MAX_DELTA, thrMod));

  const report =
    `r=${round} ${chromaState} ${agg.report} ` +
    `ext=${Math.round(extRatio*100)}% chroma_pressure=${chromaPressure} ` +
    `finalΔpen=${penMod >= 0 ? "+" : ""}${penMod.toFixed(3)} finalΔthr=${thrMod >= 0 ? "+" : ""}${thrMod.toFixed(3)}`;

  return {
    netPenModifier: penMod,
    netThrModifier: thrMod,
    halted: false,
    twigs,
    aggregation: agg,
    distribution: dist,
    extrovertRatio: extRatio,
    introvertRatio: intRatio,
    chromaPressure,
    report,
  };
}

// ── CLI demo ──────────────────────────────────────────────────────────────────

if (import.meta.main && Deno.args.includes("--demo")) {
  const { fromMBTI } = await import("./personality_types.boo.ts");

  const agents: AgentRecord[] = [
    { id: "gladys",    personality: fromMBTI("INTJ"), efficiency: 0.80 },
    { id: "qwen3:8b",  personality: fromMBTI("ENTP"), efficiency: 0.66 },
    { id: "gemma-4",   personality: fromMBTI("ESFJ"), efficiency: 0.20, suspended: true },
    { id: "claude",    personality: fromMBTI("INTJ"), efficiency: 0.34 },
  ];

  for (const chromaState of ["collapsed", "uncollapsed"] as const) {
    console.log(`\n=== chromaState: ${chromaState} ===`);
    const out = runPersonalityGovernor({ agents, chromaState, mathGovAntinode: 7, round: 42 });
    console.log("  report:", out.report);
    console.log("  twigs:");
    for (const tw of out.twigs) {
      console.log(`    [${tw.status.padEnd(8)}] ${tw.id}  wt=${tw.weightPct}%  lever: ${tw.leverAnalog}`);
    }
    console.log("  distribution:");
    for (const d of out.distribution.filter(d => d.count > 0)) {
      console.log(`    ${d.base}: ${d.count} agent(s)  ext=${d.isExtrovertCount} intro=${d.introvertCount}  chroma=${d.chromaBias}`);
    }
  }

  // Show HALT path
  console.log("\n=== HALT path (mathGovAntinode=14) ===");
  const halted = runPersonalityGovernor({ agents, chromaState: "collapsed", mathGovAntinode: 14, round: 1 });
  console.log("  halted:", halted.halted);
  console.log("  report:", halted.report);
}
