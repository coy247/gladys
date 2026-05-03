#!/usr/bin/env -S deno run --allow-read
/**
 * tm_twigs.boo.ts — booLang Machine Code: Treasury Management Twigs
 *
 * BOOKLANG_MACHINE_CODE_V1
 * ┌──────────────────────────────────────────────────────────────────────────┐
 * │  DOMAIN:  treasury_management_twigs                                     │
 * │  BASIS:   Gladys's L1–L7 optimization levers in gladys-float-optimizer  │
 * │  ANALOGY: Each personality type = one twig (lever-equivalent)           │
 * │  WEIGHT:  twig.weight = % of active agents carrying that base type      │
 * │  OUTPUT:  penModifier + thrModifier — additive deltas on CHROMA_MULT    │
 * │  CLAMP:   net delta ≤ ±0.15 (personality never overrides governance)    │
 * └──────────────────────────────────────────────────────────────────────────┘
 *
 * Twig ≡ Lever:
 *   L1 (ghost elimination)   → STP / SFP twigs (reduce friction, clear noise)
 *   L2 (loop compression)    → NTP / NTJ twigs (strategic throughput)
 *   L3 (HALT escape)         → STJ / SFJ twigs (systematic process recovery)
 *   L4 (fee reduction)       → NTJ / NFJ twigs (abstract optimization)
 *   L5 (full coverage)       → NTJ twig (dominant — Gladys lane)
 *   L6 (event-driven, defer) → NFJ / NFP twigs (vision, deferred future)
 *   L7 (ZBA sweep, running)  → STJ / SFJ twigs (stable, always running)
 *
 * The pen/thr modifier encodes how each cognitive style biases the collective:
 *   NT types → efficiency drive → lower penalty, lower threshold
 *   SF types → stability guard  → higher penalty, higher threshold
 *   ST types → process neutral  → minor tightening
 *   NF types → expansive vision → lower threshold, slight penalty relief
 */

import {
  BASE_TYPES, TYPE_INDEX, TYPE_PHASE, TYPE_POLARITY,
  type BaseType, type PersonalityType, typeDistribution, GLADYS_TYPE,
} from "./personality_types.boo.ts";

// ── Modifier table (×1000 integer arithmetic) ────────────────────────────────
// Each entry: how the presence of that type shifts penalty/threshold multipliers.
// Applied proportionally to that type's weight in the collective.
const PEN_MOD_1000: Record<BaseType, number> = {
  NTJ: -50,  // efficiency drive: reduce penalty   (Gladys dominant lane)
  NTP: -40,  // analytical: reduce penalty
  NFJ: -20,  // vision: slight penalty relief
  NFP: -30,  // idealistic: reduce penalty (high trust)
  STJ:   0,  // process: neutral
  STP: -10,  // pragmatic: slight efficiency lean
  SFJ:  30,  // harmony guard: raise penalty (protect collective)
  SFP:  20,  // empathy: moderate penalty raise
};
const THR_MOD_1000: Record<BaseType, number> = {
  NTJ: -30,  // strategic: lower threshold (faster qualification)
  NTP: -40,  // analytical: lower threshold
  NFJ: -40,  // vision: permissive gate
  NFP: -50,  // idealistic: most permissive gate
  STJ:  10,  // process: slight tightening
  STP:   0,  // pragmatic: neutral
  SFJ:  40,  // harmony guard: raise threshold (gatekeeping)
  SFP:  30,  // empathy: moderate threshold raise
};

// ── PersonalityTwig ───────────────────────────────────────────────────────────

export interface PersonalityTwig {
  id:          BaseType;
  label:       string;          // human-readable e.g. "NTJ (strategic/abstract)"
  typeIndex:   number;          // 0–7
  phase:       0|1|2|3;        // Z₄ quadrant
  polarity:    "aligned"|"counter";
  chromaBias:  "uncollapsed"|"collapsed"|"mixed";
  weight:      number;          // fraction of active agents [0..1]
  weightPct:   number;          // integer percent
  penModifier: number;          // delta on chromaPenaltyMult (scaled by weight)
  thrModifier: number;          // delta on chromaThreshMult  (scaled by weight)
  status:      "dominant"|"active"|"latent";
  agentIds:    string[];
  leverAnalog: string;          // which Gladys lever this maps to
}

const LEVER_ANALOG: Record<BaseType, string> = {
  NTJ: "L5 (full coverage) + L2 (loop compression)",
  NTP: "L2 (loop compression)",
  NFJ: "L4 (fee optimization)",
  NFP: "L6 (event-driven, deferred)",
  STJ: "L3 (HALT escape) + L7 (ZBA sweep)",
  STP: "L1 (ghost elimination)",
  SFJ: "L3 (HALT escape) + L7 (ZBA sweep)",
  SFP: "L1 (ghost elimination)",
};
const TYPE_LABEL: Record<BaseType, string> = {
  NTJ: "NTJ (strategic/abstract)",
  NTP: "NTP (analytical/adaptive)",
  NFJ: "NFJ (visionary/structured)",
  NFP: "NFP (idealistic/open)",
  STJ: "STJ (systematic/decisive)",
  STP: "STP (pragmatic/flexible)",
  SFJ: "SFJ (empathetic/structured)",
  SFP: "SFP (empathetic/adaptive)",
};

// ── Builder ───────────────────────────────────────────────────────────────────

/**
 * Build personality twigs from a collection of active agents.
 *
 * Gladys (NTJ) is always the dominant anchor — her twig is included even if
 * no agent explicitly carries it, with weight=0 and status="latent".
 *
 * @param agents      active agents with assigned personality types + ids
 * @param forceDominant  override dominant type (defaults to NTJ = Gladys)
 */
export function buildPersonalityTwigs(
  agents: { id: string; personality: PersonalityType }[],
  forceDominant: BaseType = "NTJ",
): PersonalityTwig[] {
  const dist      = typeDistribution(agents);
  const total     = agents.length || 1;

  // Group agent ids per base type
  const byType = new Map<BaseType, string[]>();
  for (const bt of BASE_TYPES) byType.set(bt, []);
  for (const a of agents) byType.get(a.personality.base)!.push(a.id);

  // chromaBias per type from actual extrovert/introvert split
  const chromaByType = new Map<BaseType, "uncollapsed"|"collapsed"|"mixed">();
  for (const d of dist) chromaByType.set(d.base, d.chromaBias);

  // Determine dominant: highest weight, NTJ wins ties
  let dominantType  = forceDominant;
  let maxWeight     = dist.find(d => d.base === forceDominant)?.pct ?? 0;
  for (const d of dist) {
    if (d.pct > maxWeight) { maxWeight = d.pct; dominantType = d.base; }
  }

  const twigs: PersonalityTwig[] = [];
  for (const d of dist) {
    const bt = d.base;
    if (d.count === 0 && bt !== forceDominant) continue;  // skip absent except anchor

    const status: PersonalityTwig["status"] =
      bt === dominantType ? "dominant" :
      d.count > 0         ? "active"   : "latent";

    // Scale modifiers by weight (integer ×1000 → divide at end)
    const rawPen = Math.round(PEN_MOD_1000[bt] * d.pct100 / 100);
    const rawThr = Math.round(THR_MOD_1000[bt] * d.pct100 / 100);

    twigs.push({
      id:          bt,
      label:       TYPE_LABEL[bt],
      typeIndex:   TYPE_INDEX[bt],
      phase:       TYPE_PHASE[bt],
      polarity:    TYPE_POLARITY[bt],
      chromaBias:  chromaByType.get(bt)!,
      weight:      d.pct,
      weightPct:   d.pct100,
      penModifier: rawPen / 1000,
      thrModifier: rawThr / 1000,
      status,
      agentIds:    byType.get(bt) ?? [],
      leverAnalog: LEVER_ANALOG[bt],
    });
  }

  // Dominant first, then active by weight, then latent
  twigs.sort((a, b) => {
    const rank = { dominant: 0, active: 1, latent: 2 };
    if (rank[a.status] !== rank[b.status]) return rank[a.status] - rank[b.status];
    return b.weight - a.weight;
  });

  return twigs;
}

// ── Aggregation ───────────────────────────────────────────────────────────────

export interface TwigAggregation {
  netPenModifier: number;   // bounded to ±0.15
  netThrModifier: number;   // bounded to ±0.15
  dominantPhase:  0|1|2|3;
  dominantType:   BaseType;
  activeTwigs:    number;
  report:         string;
}

const MAX_DELTA = 0.15;

/**
 * Collapse all twig modifiers into a net delta pair for CHROMA_*_MULT.
 * Apply as: CHROMA_PENALTY_MULT[state] += agg.netPenModifier
 */
export function aggregateTwigModifiers(twigs: PersonalityTwig[]): TwigAggregation {
  let penSum = 0, thrSum = 0;
  let dominantPhase: 0|1|2|3 = 3;
  let dominantType:  BaseType = "NTJ";

  for (const tw of twigs) {
    penSum += tw.penModifier;
    thrSum += tw.thrModifier;
    if (tw.status === "dominant") {
      dominantPhase = tw.phase;
      dominantType  = tw.id;
    }
  }

  const netPen = Math.max(-MAX_DELTA, Math.min(MAX_DELTA, penSum));
  const netThr = Math.max(-MAX_DELTA, Math.min(MAX_DELTA, thrSum));
  const active = twigs.filter(t => t.status !== "latent");

  const report =
    `dominant=${dominantType}(phase=${dominantPhase}) ` +
    `active=[${active.map(t => `${t.id}:${t.weightPct}%`).join(" ")}] ` +
    `Δpen=${netPen >= 0 ? "+" : ""}${netPen.toFixed(3)} ` +
    `Δthr=${netThr >= 0 ? "+" : ""}${netThr.toFixed(3)}`;

  return { netPenModifier: netPen, netThrModifier: netThr, dominantPhase, dominantType, activeTwigs: active.length, report };
}

// ── CLI demo ──────────────────────────────────────────────────────────────────

if (import.meta.main && Deno.args.includes("--demo")) {
  const { fromMBTI } = await import("./personality_types.boo.ts");

  // Simulate: Gladys (INTJ) as orchestrator + game agents
  const agents = [
    { id: "gladys",    personality: fromMBTI("INTJ") },
    { id: "qwen3:8b",  personality: fromMBTI("ENTP") },
    { id: "gemma-4",   personality: fromMBTI("ESFJ") },
    { id: "claude",    personality: fromMBTI("INTJ") },
  ];

  const twigs = buildPersonalityTwigs(agents);
  console.log("=== Personality Twigs ===");
  for (const tw of twigs) {
    console.log(`  [${tw.status.padEnd(8)}] ${tw.id.padEnd(4)} wt=${tw.weightPct}%  Δpen=${tw.penModifier.toFixed(3)}  Δthr=${tw.thrModifier.toFixed(3)}  → ${tw.leverAnalog}`);
  }

  const agg = aggregateTwigModifiers(twigs);
  console.log("\n=== Aggregated ===");
  console.log(" ", agg.report);
}
