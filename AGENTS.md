# AGENTS.md

## Source of Truth

`CLAUDE.md` is the canonical and always-up-to-date instruction file for this repository.

If anything in this file differs from `CLAUDE.md`, follow `CLAUDE.md`.

## Roadmap Review Stance

- Treat `ROADMAP.md` tasks as implementation prompts, not full specifications.
- Apply the same stance to Claude Code plans: treat them as execution prompts and assume Claude can handle routine implementation details autonomously.
- Do not escalate obvious implementation details (for example nonce mode, provider paging, token ABI edge cases) unless they change task intent, violate explicit project rules, or indicate a real architectural conflict.
- When reviewing Ethereum roadmap content, evaluate within the repository's declared target scope before flagging general-case caveats.
- Prefer concise validation of roadmap clarity and prioritization over spec-level completeness audits.
- During implementation/code review, still double-check behavior, edge cases, and correctness against actual code and tests.

## Project Summary

Shared Ethereum/blockchain library for the portfolio. Provides read (`eth_call`) and write (transaction signing) capabilities using `signet` as the sole Ethereum dependency.

## Core Architecture

- `signet` is the only Ethereum dependency (RPC, ABI, signing, crypto).
- Consumers can configure RPC via `config :signet` or pass URL per call.
- Standard return format: `{:ok, result} | {:error, {:tag, reason}}`.
- Use plain structs with `defstruct` + `@enforce_keys`.
- Consumers use path dependency: `{:onchain, path: "../onchain"}`.

## Module Layout

```text
lib/onchain/
  hex.ex            # hex<->binary, hex<->integer, 0x prefix
  address.ex        # validate, checksum (EIP-55), normalize
  abi.ex            # encode_call/2, decode_response/2
  decimal.ex        # to_decimal/2, to_basis_points/1, div_pow10/2
  rpc.ex            # eth_call, eth_getLogs, eth_getBalance, receipts, nonces
  rpc/helpers.ex    # shared RPC helper functions
  signer.ex         # key management, transaction signing
  erc20.ex          # approve, transfer, balanceOf
  block.ex          # block queries
  contract.ex       # generic call/4 (encode -> eth_call -> decode)
  log.ex            # event log queries
  wallet.ex         # eth_getBalance, eth_getCode, get_transaction_by_hash
  multicall.ex      # batched calls via Multicall3
  ens.ex            # ENS name resolution
  transfer.ex       # ERC-20 Transfer event parsing
```

## Testing Expectations

- Unit tests for pure functions.
- Integration tests for RPC calls require `ETHEREUM_RPC_URL`.
- Never silently skip credential-dependent tests.
- Use `flunk/1` with actionable setup instructions when credentials are missing.

### Quick Commands

```bash
mix test.json --quiet                          # AI-friendly test output (failures only)
mix test.json --quiet --failed --first-failure # Iterate on failures
mix dialyzer.json --quiet                      # AI-friendly dialyzer output
mix credo --strict --format json               # Static analysis (JSON output)
mix test.json --quiet --include integration    # Include integration tests
```

## Included Global Guidance

`CLAUDE.md` includes shared guidance via `@include` entries (across instances, critical rules, skills awareness, prioritization, task writing, web command, code style, development philosophy, documentation guidelines, agent economy, API integration, development commands, Elixir patterns/setup, test/dialyzer JSON, and library design).

For full and current instructions, read `CLAUDE.md`.

## Codex Skills Mapping

This repository also has local Codex skills that correspond to the `CLAUDE.md` include topics (for example: `core-critical-rules`, `core-skills-awareness`, `core-task-prioritization`, `core-task-writing`, `core-web-command`, `core-code-style`, `core-development-philosophy`, `core-documentation-guidelines`, `core-agent-economy`, `core-api-integration`, `core-development-commands`, `core-elixir-patterns`, `core-elixir-setup`, `core-ex-unit-json`, `core-dialyzer-json`, `core-library-design`).

Use those skills for execution workflows, but treat `CLAUDE.md` as the canonical source of policy and intent.
