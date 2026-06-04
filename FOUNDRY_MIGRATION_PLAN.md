# Foundry Adoption Plan (alongside Truffle)

Add Foundry next to Truffle. Existing JS/Truffle tests stay as-is; **new tests go
in `foundry-tests/`**. No contract rewrites. Phase 0 + Phase 1 only.

## Requirements
- No rewrite of the 73 contracts (all pin exact `0.7.5`).
- OpenZeppelin pinned to the exact npm version `@openzeppelin/contracts@3.2.2-solc-0.7`
  via remapping (not a git tag).
- New tests in `foundry-tests/`. Truffle keeps working.

## Phase 0 — Setup & parity
1. `yarn install` (provides the pinned OZ package).
2. `foundry.toml` mirroring `truffle-config.js`: `solc=0.7.5`, `evm_version=istanbul`,
   `optimizer=true`, `optimizer_runs=200`, `src=contracts`, `out=out`,
   `test=foundry-tests`, `cache_path=forge-cache`.
3. `remappings.txt`:
   ```
   @openzeppelin/contracts/=node_modules/@openzeppelin/contracts/
   forge-std/=lib/forge-std/src/
   ```
4. `.gitignore`: add `out/`, `forge-cache/`, `broadcast/`.
5. `forge build` → all 73 compile; spot-check bytecode vs Truffle `build/`.

## Phase 1 — Coexistence & first test
1. Install `forge-std` pinned to a tag that compiles under 0.7.5 (chosen
   empirically; fallback: minimal local `Vm`/`ds-test`).
2. First test in `foundry-tests/` importing a real contract (e.g. `AMBMock`);
   `forge test` green.
3. Add `package.json` scripts: `forge:build`, `forge:test` (leave existing ones).

## Out of scope
Porting JS tests, AAVE/Compound docker harness, `deploy/` scripts, solc/OZ bumps,
removing Truffle.

## Notes
- Both toolchains resolve OZ from the same `node_modules` → one pinned version.
- Outputs don't collide: Truffle `build/`, Foundry `out/` + `forge-cache/`.
- Contracts pin exact `0.7.5`, so every test importing them compiles under 0.7.5
  (hence the forge-std constraint). CI must `yarn install` before `forge build`.
