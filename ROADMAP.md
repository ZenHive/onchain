# Onchain Core Roadmap

**Vision:** Pure Elixir Ethereum library — read + write primitives, no native deps.

**Completed work:** See [CHANGELOG.md](CHANGELOG.md) for finished tasks.

**Sibling roadmaps:**
- [onchain_aave/ROADMAP.md](../onchain_aave/ROADMAP.md) — Aave V3 protocol wrappers
- [onchain_evm/ROADMAP.md](../onchain_evm/ROADMAP.md) — Rust NIFs: revm, Solidity parsing, trace, codegen
- [onchain_js/ROADMAP.md](../onchain_js/ROADMAP.md) — JS bridge: npm packages on the BEAM via QuickBEAM

---

## Current Focus

**Phase 8: Chain Intelligence Primitives ✅** — All tasks complete. Wallet analytics, transfer parsing, ENS resolution, NFT reads, and real-time subscriptions. Phase 9 (JS bridge) extracted to [onchain_js](../onchain_js/ROADMAP.md).

> **Philosophy:** Pure functions first. Consumers call from their own state. No forced state management.
>
> **Doc checklist (every task):** ROADMAP.md ✅ → CHANGELOG.md ✅ → README.md ✅ → CLAUDE.md ✅

### ✅ Recently Completed
| Task | Description | Notes |
|------|-------------|-------|
| — | **v0.4.0 Package Split** | Split into onchain (pure Elixir), onchain_aave, onchain_evm |
| 30 | Wallet primitives (eth_getBalance, eth_getCode, get_transaction_by_hash) | + Wallet convenience module |
| 32 | Transfer event parser (ERC-20/721/1155 → normalized structs) | Auto-topic injection |
| 34 | ENS resolution (forward + reverse + text records) | Mainnet integration tested |
| 33 | ERC-721/ERC-1155 read operations | 7 ERC-721 + 4 ERC-1155 reads, checksummed address returns |
| 36 | Extract shared RPC helpers | DRY: 7 functions deduplicated |
| 31 | Real-time subscriptions (eth_subscribe) | zen_websocket, newHeads/pendingTx/logs |

---

## Phase 1: Ethereum Primitives ✅

> 5 tasks complete. See [CHANGELOG.md](CHANGELOG.md#phase-1-ethereum-primitives) for details.
> Built: Hex utilities, ABI encoding, decimal conversion, JSON-RPC wrapper, address validation.

---

## Phase 2b: Read Essentials ✅

Non-Aave read primitives that consumers need before write operations.

| # | Task | Status | D | B | U | Eff | Module |
|---|------|--------|---|---|---|-----|--------|
| 18 | Generic contract call (encode → eth_call → decode in one function) | ✅ | 3 | 9 | 9 | 3.00 🎯 | `Onchain.Contract` |
| 19 | eth_getLogs + event log parsing | ✅ | 4 | 9 | 8 | 2.13 🎯 | `Onchain.RPC` + `Onchain.Log` |
| 20 | ERC-20 read operations (balanceOf, allowance, decimals, symbol) | ✅ | 3 | 8 | 8 | 2.67 🎯 | `Onchain.ERC20` |
| 22 | Multicall3 batched contract reads | ✅ | 5 | 8 | 7 | 1.50 📋 | `Onchain.Multicall` |

---

## Phase 3: Signing & Write Infrastructure ✅

Core signing and transaction infrastructure. Aave-specific write tasks (pool supply/borrow/repay, faucet) moved to [onchain_aave/ROADMAP.md](../onchain_aave/ROADMAP.md).

| # | Task | Status | D | B | U | Eff | Module |
|---|------|--------|---|---|---|-----|--------|
| 12 | Transaction signing setup + integration tests | ✅ | 4 | 9 | 9 | 2.25 🚀 | `Onchain.Signer` |
| 13 | ERC-20 write operations (approve, transfer) + integration tests | ✅ | 4 | 8 | 8 | 2.00 🚀 | `Onchain.ERC20` |
| 23 | Transaction receipt + nonce RPC methods | ✅ | 3 | 8 | 8 | 2.67 🎯 | `Onchain.RPC` |

---

## Phase 7: DEX Infrastructure

On-chain DEX trading support. Swap routing across liquidity pools and MEV protection.

| # | Task | Status | D | B | U | Eff | Module |
|---|------|--------|---|---|---|-----|--------|
| 28 | DEX swap routing (optimal path across pools) | ⬜ | 7 | 8 | 7 | 1.07 📋 | `Onchain.DEX.Router` |
| 29 | MEV protection (private transaction submission) | ⬜ | 6 | 8 | 7 | 1.25 📋 | `Onchain.MEV` |

**Task descriptions:**

**28 — DEX routing.** Find optimal swap paths across DEX pools (Uniswap, Curve, Balancer). Three approaches to evaluate: (a) Rust routing libs via onchain_evm, (b) Elixir with revm for local simulation of candidate routes, (c) **QuickBEAM + Uniswap v3 SDK** (see [onchain_js](../onchain_js/ROADMAP.md) Task 3). Primary consumer: ccxt_ex when it adds DEX trading.

**29 — MEV protection.** Private transaction submission via Flashbots-style APIs to prevent front-running on DEX trades. Lower priority until DEX trading is active.

---

## Phase 8: Chain Intelligence Primitives ✅

> 6 tasks complete. Read-layer primitives for wallet analytics and on-chain intelligence.

| # | Task | Status | D | B | U | Eff | Module |
|---|------|--------|---|---|---|-----|--------|
| 30 | Wallet primitives (eth_getBalance, eth_getCode, eth_getTransactionByHash) | ✅ | 3 | 8 | 9 | 2.83 🎯 | `Onchain.RPC` + `Onchain.Wallet` |
| 31 | Real-time subscriptions (eth_subscribe: newHeads, pendingTx, logs) | ✅ | 5 | 9 | 8 | 1.70 🚀 | `Onchain.Subscription` |
| 32 | Transfer event parser (ERC-20/721/1155 → normalized structs) | ✅ | 3 | 9 | 9 | 3.00 🎯 | `Onchain.Transfer` |
| 33 | ERC-721/ERC-1155 read operations (NFT tracking) | ✅ | 3 | 6 | 5 | 1.83 🚀 | `Onchain.ERC721` + `Onchain.ERC1155` |
| 34 | ENS resolution (forward + reverse) | ✅ | 3 | 7 | 7 | 2.33 🎯 | `Onchain.ENS` |

**Task descriptions:**

**31 — Real-time subscriptions.** `eth_subscribe` for `newHeads` (new blocks), `newPendingTransactions` (mempool monitoring), and `logs` (real-time event streaming). zen_websocket already exists in the portfolio — this builds Ethereum-specific subscription management on top of it.

**33 — ERC-721/ERC-1155 reads.** Read-only NFT queries: `ownerOf/3`, `tokenURI/3`, `balanceOf/3` for ERC-721; `balanceOf/4`, `uri/3` for ERC-1155. Same pattern as ERC-20 reads — eth_call wrappers with known ABIs.

---

## Code Health

| # | Task | Status | D | B | U | Eff | Module |
|---|------|--------|---|---|---|-----|--------|
| 36 | Extract shared RPC helpers (DRY: 7 duplicated functions between RPC + Trace) | ✅ | 3 | 6 | 5 | 1.83 🚀 | `Onchain.RPC.Helpers` |
| — | Code review fixes: batch state commit, defensive parsing, array handling, NatSpec | ✅ | — | — | — | — | Multiple |
| 37 | zen_websocket: `send_message/2` should return `{:error, :disconnected}` instead of `:noproc` exit when server is dead | ⬜ | 2 | 7 | 6 | 3.25 🎯 | `ZenWebsocket.Client` |
| 38 | Subscription: buffer unknown sub_ids to close subscribe→Agent.update race window (drops notifications silently if WS endpoint doesn't order subscribe response before notifications) | ⬜ | 3 | 4 | 3 | 1.17 📋 | `Onchain.Subscription` |
| 39 | Subscription: add `:pending_transactions` integration test (needs provider that broadcasts mempool — Alchemy custom method or local full node) | ⬜ | 2 | 3 | 3 | 1.50 📋 | `test/onchain/subscription_integration_test.exs` |
| 40 | Switch Credo back to Hex release (moved from `release/1.7` git branch to `{:credo, "~> 1.7"}` — resolved at 1.7.18) | ✅ | 1 | 4 | 3 | 3.50 🎯 | `mix.exs` |
| 41 | ENS enhancements: CCIP-Read / EIP-3668 off-chain lookups, ENSIP-10 wildcard resolution, full UTS-46 / ENSIP-15 Unicode normalization, multi-coin address resolution (currently ETH-only via `addr(bytes32)`) | ⬜ | 6 | 6 | 5 | 0.92 ⚠️ | `Onchain.ENS` |
| 42 | Subscription: deliver parse errors to the handler as `{:parse_error, sub_id, reason}` events instead of silently dropping malformed notifications | ⬜ | 2 | 4 | 3 | 1.75 🚀 | `Onchain.Subscription` |
| 43 | Upstream spec fix tracking: remove `@dialyzer {:no_match, ...}` suppressions in ENS/Log/Multicall once upstream `abi` (`ABI.decode/2` no_return) and `signet` (`Hex` specs) publish fixes | ⬜ | 1 | 3 | 3 | 3.00 🎯 | Multiple |
| 44 | Fix CLAUDE.md Module Layout drift: claims `wallet.ex` holds `eth_getBalance, eth_getCode, get_transaction_by_hash` but actual surface is `balance/classify`; those RPC methods live on `Onchain.RPC`. Audit every bullet in Module Layout against real exports to prevent future instances from calling non-existent functions. | ⬜ | 1 | 3 | 4 | 3.50 🎯 | `CLAUDE.md` |
| 45 | Add `Onchain.ERC20.total_supply/2` (+ bang variant) to complete the standard ERC-20 read surface. Every other standard read exists (balanceOf, allowance, decimals, symbol). Include unit test + mainnet integration test against WETH. | ⬜ | 2 | 5 | 6 | 2.75 🎯 | `Onchain.ERC20` |
| 46 | Make `Onchain.Hex.from_integer/1` emit lowercase hex to match `Onchain.Hex.encode/1`. Currently returns `"0xFF"` (uppercase) while `encode/1` returns lowercase. Cosmetic inconsistency — no contract broken. Update tests and docstring example if needed. | ⬜ | 1 | 2 | 2 | 2.00 🚀 | `Onchain.Hex` |

---

## Future Consumer Use Cases

These are example consumer directions built on top of the current and planned primitives. They are not separate core-library tasks, but they help clarify what the roadmap is enabling.

### DeFiSaver-Style Consumer Stack

**QuickBEAM shortcut:** [onchain_js](../onchain_js/ROADMAP.md) Task 4 (`@defisaver/sdk` via QuickBEAM) can accelerate layers 2-3 below.

1. **Smart wallet / proxy layer.** Support DSProxy/Safe-style execution, wallet discovery, ownership checks, and proxy-aware transaction helpers.
2. **Action layer.** Move from raw contract calls to semantic actions like supply, borrow, swap collateral, repay with collateral, close position, and refinance.
3. **Simulation layer.** Preview actions and multi-step recipes locally before broadcast (via onchain_evm's revm).
4. **Trigger + automation engine.** Persistent triggers for health factor, LTV, oracle prices, and time windows.
5. **Product layer.** User-facing API/UI, strategy storage, notifications, audit trail.

### Where Each Package Helps

| Need | Package |
|------|---------|
| RPC calls, ABI, signing, token reads/writes | **onchain** (this repo) |
| Aave protocol operations | **onchain_aave** |
| Local EVM simulation, Solidity parsing, codegen | **onchain_evm** |
| JS SDKs on the BEAM (solc, Uniswap, DeFiSaver) | **[onchain_js](../onchain_js/ROADMAP.md)** (QuickBEAM) |

### Example Future Consumer Apps

- Aave auto-repay bot
- Liquidation protection service
- One-click deleverage / close-position flow
- Collateral swap assistant
- Treasury risk console for multiple wallets
- Strategy preview sandbox before live execution

---

## Key Design Decisions

1. **Pure Elixir** — no native deps, no Rustler (NIF work lives in onchain_evm)
2. **Signet as sole Ethereum dep** — RPC, ABI, signing, crypto all in one
3. **Consumers configure RPC URL** — `config :signet, ...` or pass URL per-call
4. **Standard error tuples** — `{:ok, result} | {:error, {:tag, reason}}`
5. **Plain structs** — `defstruct` + `@enforce_keys`, no private macro deps
6. **Descripex from day one** — All public modules use `api()` macro for self-describing functions
7. **Five-package family** — onchain (core), onchain_aave (Aave), onchain_evm (Rust NIFs), onchain_js (QuickBEAM), onchain_tempo (Tempo chain)
8. **Always update docs after completing a task** — ROADMAP.md, CHANGELOG.md, README.md, CLAUDE.md
9. **Integration tests use mainnet RPCs** — `ETHEREUM_API_URL` or `ETH_RPC_URL` env vars

## Module Structure

```
lib/
  onchain.ex                        # Discoverable root (16 core modules)
  onchain/
    hex.ex                          # hex↔binary, hex↔integer, 0x prefix
    address.ex                      # validate, checksum (EIP-55), normalize
    abi.ex                          # encode_call/2, decode_response/2
    decimal.ex                      # to_decimal/2, to_basis_points/1, div_pow10/2
    block.ex                        # get_by_number, find_by_timestamp (binary search)
    contract.ex                     # generic call/4 (encode → eth_call → decode)
    rpc.ex                          # eth_call, eth_getLogs, get_transaction_receipt, etc.
    rpc/
      helpers.ex                    # shared RPC helper functions
    log.ex                          # event log parsing against ABI signatures
    multicall.ex                    # Multicall3 batched reads
    signer.ex                       # key management, transaction signing
    erc20.ex                        # reads + writes: balanceOf, approve, transfer
    erc721.ex                       # ERC-721 NFT reads: ownerOf, tokenURI, balanceOf
    erc1155.ex                      # ERC-1155 multi-token reads: balanceOf, balanceOfBatch, uri
    wallet.ex                       # classify (EOA/contract), native ETH balance
    transfer.ex                     # Transfer event parser (ERC-20/721/1155 → structs)
    ens.ex                          # forward + reverse ENS resolution
    subscription.ex                 # real-time eth_subscribe (newHeads, pendingTx, logs)
    subscription/
      parser.ex                     # pure parsing for subscription notification payloads
```
