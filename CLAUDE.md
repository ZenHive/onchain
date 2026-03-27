# Onchain

Shared Ethereum/blockchain library for the portfolio. Provides read (eth_call) and write (transaction signing) capabilities using `signet` as the sole Ethereum dependency.

@~/.claude/includes/across-instances.md
@~/.claude/includes/critical-rules.md
@~/.claude/includes/skills-awareness.md
@~/.claude/includes/task-prioritization.md
@~/.claude/includes/task-writing.md
@~/.claude/includes/web-command.md
@~/.claude/includes/code-style.md
@~/.claude/includes/development-philosophy.md
@~/.claude/includes/documentation-guidelines.md
@~/.claude/includes/agent-economy.md
@~/.claude/includes/elixir-patterns.md
@~/.claude/includes/elixir-setup.md
@~/.claude/includes/development-commands.md
@~/.claude/includes/ex-unit-json.md
@~/.claude/includes/dialyzer-json.md
@~/.claude/includes/library-design.md
@~/.claude/includes/elixir-volt.md
@~/.claude/includes/quickbeam.md

## Portfolio Context

This repo is part of a three-library portfolio. The boundary is **ephemeral vs durable**, not read vs write.

- **onchain** (this repo) — core Ethereum primitives, RPC, ABI, signing (pure Elixir, no native deps)
- **onchain_aave** — Aave V3 protocol wrappers (depends on onchain)
- **onchain_evm** — Rust NIFs: revm simulation, Solidity parsing, debug/trace, codegen (depends on onchain + Rustler)
- **rexex** — chain indexing, storing durable facts (ExEx ingestion, Postgres, reorg-safe history, dashboards)
- **hologram** — JS runtimes, npm access, headless/edge execution (Elixir interpreter in any JS runtime)

**Where does this feature go?**

1. Talks to Ethereum directly and returns an immediate result? → **onchain**
2. Persists or queries chain facts over time? → **rexex**
3. Runs Elixir in JS or reaches npm/edge runtimes? → **hologram**
4. Composes those capabilities into a user-facing workflow? → **separate consumer repo**

**Watch boundary:** onchain Phase 8 (eth_subscribe, Transfer parser) overlaps rexex territory. The distinction: onchain returns results to the caller (ephemeral); rexex writes facts to Postgres (durable). If a consumer needs historical queries over indexed data, that's rexex.

**Agent consumers:** AI agents are first-class consumers of this library. See [AGENT_WISHLIST.md](AGENT_WISHLIST.md) for use cases and scenarios.

## Architecture

- **Pure Elixir** — no native deps, no Rustler, no compilation of C/Rust
- **signet** is the sole Ethereum dep — RPC, ABI encoding, signing, crypto all in one
- Signet wraps **curvy** (pure Elixir secp256k1) internally for signing/key ops — never add curvy as a direct dep
- Consumers configure RPC URL via `config :signet` or pass URL per-call
- Standard error tuples: `{:ok, result} | {:error, {:tag, reason}}`
- Plain structs with `defstruct` + `@enforce_keys`, no private macro deps
- Path dependency in consumers: `{:onchain, path: "../onchain"}`

## Module Layout

```
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
  contract.ex       # generic call/4 (encode → eth_call → decode)
  log.ex            # event log queries
  wallet.ex         # eth_getBalance, eth_getCode, get_transaction_by_hash
  multicall.ex      # batched calls via Multicall3
  ens.ex            # ENS name resolution
  transfer.ex       # ERC-20 Transfer event parsing
```

**Moved to onchain_aave:** `aave/` (math, contracts, pool, oracle, faucet, ui_pool_data_provider, types/)
**Moved to onchain_evm:** `evm.ex`, `solidity.ex`, `trace.ex`, `contract/generator.ex`, `native/`

## After Every Task

Update **all affected `.md` files** after completing any roadmap task. This is part of every task, not a separate step.

- **ROADMAP.md** — Mark status (⬜ → ✅), update Current Focus section
- **CHANGELOG.md** — Add entry under latest section with what was done
- **README.md** — Update if new modules, changed APIs, or user-facing functionality
- **CLAUDE.md** — Update Module Layout if files were added/removed/renamed, update Architecture if conventions changed

**Code reviewers**: Verify all four files were checked. Reject reviews where task completion didn't include doc updates.

## Testing

- Unit tests for all pure functions (hex, address, decimal, math)
- Integration tests are **excluded by default** (`ExUnit.start(exclude: [:integration])` in test_helper.exs)
- `mix test.json --quiet` runs only unit tests — no flags needed to skip integration
- Integration tests for RPC reads require `ETHEREUM_API_URL` or `ETH_RPC_URL` env var
- Integration tests for Sepolia writes (`@tag :sepolia_send`) additionally require `SIGNER_PRIVATE_KEY`
- Use `Onchain.RPCCase.rpc_url!/0` from `test/support/rpc_case.ex` to resolve RPC URL
- Use `flunk/1` with setup instructions for missing credentials, never silent skip

### Quick Commands

```bash
mix test.json --quiet                          # Unit tests only (integration excluded by default)
mix test.json --quiet --failed --first-failure # Iterate on failures
mix test.json --quiet --include integration    # Unit + all integration tests
mix test.json --quiet --only integration       # Integration tests only
mix test.json --quiet --only sepolia_send      # Sepolia write tests only (sends transactions)
mix dialyzer.json --quiet                      # AI-friendly dialyzer output
mix credo --strict --format json               # Static analysis (JSON output)
```

## Related Packages

- **onchain_aave** — Aave V3 wrappers: `{:onchain_aave, path: "../onchain_aave"}` (or `"~> 0.1"` from Hex)
- **onchain_evm** — Rust NIFs + codegen: `{:onchain_evm, path: "../onchain_evm"}` (or `"~> 0.1"` from Hex)
