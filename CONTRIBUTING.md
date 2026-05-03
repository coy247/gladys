# Contributing

This is a focused, opinionated project. Before contributing, read the README —
especially the booLang constraints section. A lot of decisions that look wrong
are actually grammar requirements.

## Ground rules

- Native `.boo` files in `compiler/` use integer-only arithmetic. No floats,
  no negative literals, no unparenthesized mixed expressions. If the booLang
  interpreter rejects your change, that's the grammar enforcing invariants.

- Modifier values use offset-from-1000 encoding. `950` means `-50 from neutral`.
  Do not introduce actual negative numbers.

- Gladys (NTJ, typeIndex=7) is always the default anchor. She wins ties. Do not
  change this behavior without a strong reason spelled out in the PR.

- The personality modifiers are grounded in MBTI population research. Changes to
  the modifier tables should cite a reasoning, not just tweak numbers.

## Workflow

1. Fork and create a branch (`feature/your-thing` or `fix/what-broke`)
2. Make your change. Run the interpreter tests before opening a PR.
3. Open a PR with a clear description of what changed and why.

## Testing

```sh
deno run --allow-read scripts/test_personality_types.ts
deno run --allow-read scripts/test_tm_twigs.ts
deno run --allow-read scripts/test_math_governor.ts
```

There are no automated CI hooks yet. Manual verification through the booLang
interpreter is the current gate.

## Questions

If booLang isn't public yet and something in the `.boo` files doesn't make sense,
that's expected. The language is pre-release. Open an issue and we'll explain it.
