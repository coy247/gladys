#!/usr/bin/env -S deno run --allow-read
/**
 * personality_types.boo.ts — booLang Machine Code: Personality Type Lattice
 *
 * BOOKLANG_MACHINE_CODE_V1
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │  DOMAIN:  personality_lattice                                           │
 * │  SCALE:   16 MBTI → 8 base types + isExtrovert:boolean (default true)  │
 * │  AXIS_1:  N/S  — intuition vs sensing     (bit 2)                      │
 * │  AXIS_2:  T/F  — thinking vs feeling      (bit 1)                      │
 * │  AXIS_3:  J/P  — judging vs perceiving    (bit 0)                      │
 * │  BOOL:    isExtrovert — E(true) / I(false), default true               │
 * │  PHASE:   Z₄ quadrant: ST=0, SF=1, NF=2, NT=3                         │
 * │  POLARITY: J=aligned, P=counter  (mirrors booLang polarity axis)       │
 * │  CHROMA:  isExtrovert→uncollapsed, introvert→collapsed                 │
 * └─────────────────────────────────────────────────────────────────────────┘
 *
 * Domain reductive approach:
 *   typeIndex = (N?4:0) + (T?2:0) + (J?1:0)  →  3-bit address [0..7]
 *   isExtrovert is an orthogonal boolean, NOT a type index bit.
 *   Percentage of each type across a population = distribution metric.
 *
 * Usage:
 *   import { fromMBTI, typeDistribution, GLADYS_TYPE } from "./personality_types.boo.ts";
 *   const t = fromMBTI("INTJ");   // → { base: "NTJ", isExtrovert: false, label: "INTJ" }
 */

// ── 8 base types ─────────────────────────────────────────────────────────────

export const BASE_TYPES = ["STJ","STP","SFJ","SFP","NTJ","NTP","NFJ","NFP"] as const;
export type  BaseType   = typeof BASE_TYPES[number];

// 3-bit typeIndex: (N?4:0)+(T?2:0)+(J?1:0)
export const TYPE_INDEX: Record<BaseType, number> = {
  SFP: 0,  // S=0 F=0 P=0 → 0
  SFJ: 1,  // S=0 F=0 J=1 → 1
  STP: 2,  // S=0 T=2 P=0 → 2
  STJ: 3,  // S=0 T=2 J=1 → 3
  NFP: 4,  // N=4 F=0 P=0 → 4
  NFJ: 5,  // N=4 F=0 J=1 → 5
  NTP: 6,  // N=4 T=2 P=0 → 6
  NTJ: 7,  // N=4 T=2 J=1 → 7  ← Gladys (INTJ)
};

// Z₄ quadrant (cognitive axis pairing)
export const TYPE_PHASE: Record<BaseType, 0|1|2|3> = {
  STJ: 0, STP: 0,   // ST → pragmatic / systematic
  SFJ: 1, SFP: 1,   // SF → empathetic / concrete
  NFJ: 2, NFP: 2,   // NF → intuitive / humanistic
  NTJ: 3, NTP: 3,   // NT → strategic / abstract  (Gladys quadrant)
};

// J/P → polarity (mirrors booLang polarity axis)
export const TYPE_POLARITY: Record<BaseType, "aligned"|"counter"> = {
  STJ: "aligned", SFJ: "aligned", NTJ: "aligned", NFJ: "aligned",
  STP: "counter", SFP: "counter", NTP: "counter", NFP: "counter",
};

// ── Full PersonalityType ──────────────────────────────────────────────────────

export interface PersonalityType {
  base:        BaseType;
  isExtrovert: boolean;   // E=true (default), I=false
  label:       string;    // canonical 4-letter MBTI code e.g. "INTJ"
  typeIndex:   number;    // 0–7
  phase:       0|1|2|3;  // Z₄ quadrant
  polarity:    "aligned"|"counter";
  chromaBias:  "uncollapsed"|"collapsed";  // E→uncollapsed, I→collapsed
}

/** Parse a 4-letter MBTI code into a full PersonalityType. */
export function fromMBTI(code: string): PersonalityType {
  const u = code.toUpperCase().trim();
  if (u.length !== 4) throw new Error(`MBTI code must be 4 letters, got: "${code}"`);
  const isExtrovert = u[0] === "E";
  const n = u[1] === "N";
  const t = u[2] === "T";
  const j = u[3] === "J";
  const base: BaseType = `${n?"N":"S"}${t?"T":"F"}${j?"J":"P"}` as BaseType;
  return {
    base,
    isExtrovert,
    label:      u,
    typeIndex:  TYPE_INDEX[base],
    phase:      TYPE_PHASE[base],
    polarity:   TYPE_POLARITY[base],
    chromaBias: isExtrovert ? "uncollapsed" : "collapsed",
  };
}

/** All 16 MBTI types as PersonalityType objects. */
export const ALL_16: PersonalityType[] = [
  "ISTJ","ISFJ","INFJ","INTJ",
  "ISTP","ISFP","INFP","INTP",
  "ESTJ","ESFJ","ENFJ","ENTJ",
  "ESTP","ESFP","ENFP","ENTP",
].map(fromMBTI);

// ── Gladys anchor ─────────────────────────────────────────────────────────────
// Gladys is always INTJ: introvert, NT quadrant, J-aligned, collapsed chroma bias
export const GLADYS_TYPE: PersonalityType = fromMBTI("INTJ");

// ── Distribution ─────────────────────────────────────────────────────────────

export interface TypeDistribution {
  base:       BaseType;
  count:      number;
  pct:        number;    // 0.0–1.0
  pct100:     number;    // integer percentage
  isExtrovertCount: number;
  introvertCount:   number;
  chromaBias: "uncollapsed"|"collapsed"|"mixed";
}

/**
 * Compute type distribution across a population.
 * Returns all 8 base types (zero-count types included for completeness).
 */
export function typeDistribution(
  agents: { personality: PersonalityType }[],
): TypeDistribution[] {
  const total  = agents.length;
  const counts = new Map<BaseType, { n: number; ext: number }>();
  for (const bt of BASE_TYPES) counts.set(bt, { n: 0, ext: 0 });
  for (const a of agents) {
    const c = counts.get(a.personality.base)!;
    c.n++;
    if (a.personality.isExtrovert) c.ext++;
  }
  return BASE_TYPES.map(bt => {
    const { n, ext } = counts.get(bt)!;
    const intro = n - ext;
    const pct   = total > 0 ? n / total : 0;
    return {
      base:       bt,
      count:      n,
      pct,
      pct100:     Math.round(pct * 100),
      isExtrovertCount: ext,
      introvertCount:   intro,
      chromaBias: (n === 0 ? "mixed" : ext === n ? "uncollapsed" : intro === n ? "collapsed" : "mixed") as "uncollapsed"|"collapsed"|"mixed",
    };
  }).sort((a, b) => b.count - a.count || TYPE_INDEX[a.base] - TYPE_INDEX[b.base]);
}

// ── CLI demo ──────────────────────────────────────────────────────────────────

if (import.meta.main && Deno.args.includes("--demo")) {
  console.log("=== 8 Base Types (3-bit lattice) ===");
  for (const bt of BASE_TYPES) {
    console.log(`  ${bt}  idx=${TYPE_INDEX[bt]}  phase=${TYPE_PHASE[bt]}  polarity=${TYPE_POLARITY[bt]}`);
  }
  console.log("\n=== All 16 MBTI types ===");
  for (const t of ALL_16) {
    console.log(`  ${t.label}  base=${t.base}  idx=${t.typeIndex}  phase=${t.phase}  chroma=${t.chromaBias}`);
  }
  console.log(`\nGladys: ${JSON.stringify(GLADYS_TYPE, null, 2)}`);
}
