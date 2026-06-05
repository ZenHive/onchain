# Onchain

Shared Ethereum/blockchain library for the portfolio. Provides read (eth_call) and write (transaction signing) capabilities using `cartouche` as the sole Ethereum dependency.

<!-- Selective-load (Opus 4.8): eager floor = critical-rules only. Everything previously
     imported here (worktree, task-prioritization/writing, workflow-philosophy, web-command,
     code-style, development-philosophy/commands, elixir-setup, ex-unit-json, dialyzer-json,
     agent-economy, reach) is now skill-on-demand via the elixir / task-driver / dev-lifecycle
     plugins. Re-add an @-import per-surface only if Opus visibly degrades on it.
     See ~/.claude/setup-guide.md § "Skills vs Includes". -->
@~/.claude/includes/critical-rules.md
@~/.claude/includes/onchain-workspace.md
@~/.claude/includes/ethereum-rpc.md

<!-- Harness driver contract: onchain is registered with the harness OTP node
     (~/_DATA/code/harness, config/dev.local.exs). The harness MCP server
     (mcp__harness__dispatch__*, port 4018) is the primary surface for dispatching
     onchain roadmap tasks to headless agents gated by a cross-family reviewer AI;
     mcp__harness_eval__project_eval is the escape hatch. See .mcp.json.

     On-demand, NOT eager: the harness-driver SKILL.md is 55.8k chars (over the
     40k eager-import limit) — loading it every session is wasteful. Read it only
     when actually driving harness dispatch:
       Read ~/_DATA/code/harness/skills/harness-driver/SKILL.md -->


## Portfolio Context

This repo is part of a multi-library portfolio. The boundary is **ephemeral vs durable**, not read vs write. Each native runtime gets its own package.

- **onchain** (this repo) — core Ethereum primitives, RPC, ABI, signing (pure Elixir, no native deps)
- **onchain_aave** — Aave V3 protocol wrappers (depends on onchain, pure Elixir)
- **onchain_evm** — Rust NIFs: revm simulation, Solidity parsing, debug/trace, codegen (depends on onchain + Rustler)
- **onchain_js** — JS bridge: npm packages on the BEAM via QuickBEAM (depends on onchain + Zig NIFs)
- **onchain_tempo** — Tempo blockchain primitives: 0x76 transactions, TIP-20 encoding, RPC, TransferWithMemo parsing (depends on onchain, pure Elixir)
- **onchain_agents** *(planned)* — EIP-8004 Trustless Agents: Identity / Reputation / Validation registries, plus Descripex manifest bridge for trustless verification (depends on onchain, pure Elixir). Triggered when a consumer needs agent-economy registration; see `ROADMAP.md` "EIP Tracking"
- **rexex** — chain indexing, storing durable facts (ExEx ingestion, Postgres, reorg-safe history, dashboards)
- **hologram** — JS runtimes, npm access, headless/edge execution (Elixir interpreter in any JS runtime)

**Where does this feature go?**

1. Talks to Ethereum directly and returns an immediate result? → **onchain**
2. Talks to Tempo chain (0x76 txs, TIP-20 tokens)? → **onchain_tempo**
3. Runs npm packages on the BEAM (solc-js, Uniswap SDK, etc.)? → **onchain_js**
4. Persists or queries chain facts over time? → **rexex**
5. Runs Elixir in JS or reaches npm/edge runtimes? → **hologram**
6. Registers / queries / validates agents via EIP-8004 registries? → **onchain_agents** (when built)
7. Composes those capabilities into a user-facing workflow? → **separate consumer repo**

**Scope split with cartouche (substrate layer).** cartouche = Ethereum primitives (key management, signing, transaction encoding, raw RPC, hex/ABI/typed-data). onchain (and its siblings) = everything buildable on top of `Cartouche.*` from outside cartouche. **Rule:** if the feature requires cartouche internals (new tx type, signer extension, primitive encoding), it's a cartouche-PR candidate. Otherwise — including RPC method wrappers, ERC standards, protocol parsers, telemetry facades, retry/backoff, fee helpers, EIP-8004 registries — it lives in this portfolio. See `../signet/ROADMAP.md` "Scope principle" for the full classification and EIP triage rubric (the sibling design-discussion repo retains its historical name).

**Watch boundary:** onchain Phase 8 (eth_subscribe, Transfer parser) overlaps rexex territory. The distinction: onchain returns results to the caller (ephemeral); rexex writes facts to Postgres (durable). If a consumer needs historical queries over indexed data, that's rexex.

**Agent consumers:** AI agents are first-class consumers of this library. See [AGENT_WISHLIST.md](AGENT_WISHLIST.md) for use cases and scenarios. EIP-8004 registration / reputation / validation lives in `onchain_agents` — see `ROADMAP.md` "EIP Tracking".

## Architecture

- **Pure Elixir** — no native deps, no Rustler, no compilation of C/Rust
- **cartouche** is the primary Ethereum dep — RPC, ABI encoding, signing, crypto all in one (transitively pulls in `hieroglyph` for ABI)
- **zen_websocket** for WebSocket transport (eth_subscribe real-time subscriptions)
- Cartouche wraps **curvy** (pure Elixir secp256k1) internally for signing/key ops — never add curvy as a direct dep
- Consumers configure RPC URL via `config :cartouche` or pass URL per-call
- Standard error tuples: `{:ok, result} | {:error, {:tag, reason}}`
- Plain structs with `defstruct` + `@enforce_keys`, no private macro deps
- Path dependency in consumers: `{:onchain, path: "../onchain"}`

## Module Layout

```
lib/onchain/
  hex.ex            # hex<->binary, hex<->integer, 0x prefix
  address.ex        # validate, checksum (EIP-55), normalize
  abi.ex            # encode_call/2, decode_response/2, decode_types/2, decode_call/3, decode_error/2
  decimal.ex        # to_decimal/2, to_basis_points/1, div_pow10/2
  fees.ex           # suggest_fees/2 — EIP-1559 fee recommendation over Cartouche.FeeHistory.t()
  rpc.ex            # eth_call, eth_getLogs, eth_getBalance, receipts, nonces, syncing, fee_history, get_proof, generic call/3 passthrough
  rpc/helpers.ex    # shared RPC helpers; parse_block_response/1, parse_transaction_map/1; do_rpc enriches revert maps with :data hex for decode_error/2
  signer.ex         # key management, transaction signing
  erc20.ex          # reads + writes: balanceOf, allowance, decimals, symbol, totalSupply, approve, transfer
  erc721.ex         # ERC-721 NFT reads: ownerOf, tokenURI, balanceOf
  erc1155.ex        # ERC-1155 multi-token reads: balanceOf, balanceOfBatch, uri
  block.ex          # block queries
  contract.ex       # generic call/4 (encode → eth_call → decode)
  log.ex            # event log queries
  wallet.ex         # classify (EOA/contract), native ETH balance
  multicall.ex      # batched calls via Multicall3
  sleuth.ex         # Compound-style deploy-as-call: ship bytecode in eth_call, decode returned bytes
  ens.ex            # ENS name resolution
  transfer.ex       # ERC-20 Transfer event parsing
  mev.ex            # private tx submission via Flashbots-style relays (eth_sendPrivateTransaction / eth_sendBundle)
  subscription.ex   # real-time eth_subscribe (newHeads, pendingTx, logs)
  subscription/
    parser.ex       # pure parsing for subscription notification payloads
```

**Moved to onchain_aave:** `aave/` (math, contracts, pool, oracle, faucet, ui_pool_data_provider, types/)
**Moved to onchain_evm:** `evm.ex`, `solidity.ex`, `trace.ex`, `contract/generator.ex`, `native/`

## Git Workflow (current)

- **No PRs (currently).** As of 2026-06 this repo no longer uses pull requests for routine work. Completed work commits and merges **directly to `development`** (the default branch). Don't open `gh pr create` — just commit/merge to `development`. (Overrides the global PR-based / GH-native-auto-merge flow for this repo.)
- **Always ask before using a worktree.** The global worktree-workflow auto-allows creating a worktree when a tracking ID exists; in this repo, **ask first** — don't auto-create one.

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

- **onchain_aave** — Aave V3 wrappers: `{:onchain_aave, path: "../onchain_aave"}`
- **onchain_evm** — Rust NIFs + codegen: `{:onchain_evm, path: "../onchain_evm"}`
- **onchain_js** — JS bridge (QuickBEAM): `{:onchain_js, path: "../onchain_js"}`
- **onchain_tempo** — Tempo chain primitives: `{:onchain_tempo, path: "../onchain_tempo"}`
