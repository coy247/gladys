# Security Policy

## Scope

This repository contains governance logic — personality type math and threshold
modifiers. It does not handle credentials, keys, wallet addresses, or sensitive
financial data. There is nothing here that should gate access to real funds.

If you're wiring this into a system that does touch real money, the security
boundary is yours to own, not this library's.

## Reporting

If you find something unexpected — logic that could be manipulated to bypass a
HALT gate, modifier tables that could be exploited to push antinodeIndex out of
bounds, or anything that looks like it could cause a governance bypass — open a
private issue or email directly rather than posting publicly.

Do not open a public issue for potential security concerns. Give us a chance to
look at it first.

## booLang interpreter

The `.boo` files here run through the booLang interpreter. Security properties
of the interpreter itself are outside the scope of this repo. Report interpreter
vulnerabilities to the booLang project directly.
