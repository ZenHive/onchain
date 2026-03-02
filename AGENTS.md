# AGENTS.md

## Source of Truth

`CLAUDE.md` is the canonical and always-up-to-date instruction file for this repository.

If anything in this file differs from `CLAUDE.md`, follow `CLAUDE.md`.

## Project Summary

Shared Ethereum/blockchain library for the portfolio. Provides read (`eth_call`) and write (transaction signing) capabilities using `signet` as the sole Ethereum dependency.

## Core Architecture

- `signet` is the only Ethereum dependency (RPC, ABI, signing, crypto).
- Consumers can configure RPC via `config :signet` or pass URL per call.
- Standard return format: `{:ok, result} | {:error, {:tag, reason}}`.
- Use plain structs with `defstruct` + `@enforce_keys`.
- Consumers use path dependency: `{:onchain, path: "../onchain"}`.

## Consumers

- `blockwatch` (Aave monitoring, read-only)
- `aave_sim` (Aave simulation, read-only)
- `ccxt_ex` (exchange trading, DEX signing planned)

## Module Layout

```text
lib/onchain/
  hex.ex
  address.ex
  abi.ex
  decimal.ex
  rpc.ex
  signer.ex
  erc20.ex
  aave/
    math.ex
    contracts.ex
    pool.ex
    oracle.ex
    types/
```

## Testing Expectations

- Unit tests for pure functions.
- Integration tests for RPC calls require `ETHEREUM_RPC_URL`.
- Never silently skip credential-dependent tests.
- Use `flunk/1` with actionable setup instructions when credentials are missing.

## Included Global Guidance

`CLAUDE.md` includes shared guidance via `@include` entries (across instances, critical rules, skills awareness, prioritization, task writing, web command, code style, development philosophy, documentation guidelines, agent economy, API integration, development commands, Elixir patterns/setup, test/dialyzer JSON, and library design).

For full and current instructions, read `CLAUDE.md`.

## Codex Skills Mapping

This repository also has local Codex skills that correspond to the `CLAUDE.md` include topics (for example: `core-critical-rules`, `core-skills-awareness`, `core-task-prioritization`, `core-task-writing`, `core-web-command`, `core-code-style`, `core-development-philosophy`, `core-documentation-guidelines`, `core-agent-economy`, `core-api-integration`, `core-development-commands`, `core-elixir-patterns`, `core-elixir-setup`, `core-ex-unit-json`, `core-dialyzer-json`, `core-library-design`).

Use those skills for execution workflows, but treat `CLAUDE.md` as the canonical source of policy and intent.
