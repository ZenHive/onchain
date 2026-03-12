# Onchain Roadmap

**Vision:** Shared Ethereum library — analytics first, then act. Read + write from day one.

**Completed work:** See [CHANGELOG.md](CHANGELOG.md) for finished tasks.

---

## Current Focus

**Phase 2: Aave Core (Read)** — Consumer-driven tasks added (18-22). High-ROI primitives (generic contract call, eth_getLogs, ERC-20 reads) before remaining Aave-specific work (tasks 10-11).

> **Philosophy:** Pure functions first. Consumers call from their own state. No forced state management.

---

## Phase 1: Ethereum Primitives ✅

> 5 tasks complete. See [CHANGELOG.md](CHANGELOG.md#phase-1-ethereum-primitives) for details.
> Built: Hex utilities, ABI encoding, decimal conversion, JSON-RPC wrapper, address validation.

---

## Phase 2: Aave Core (Read)

| # | Task | Status | D | B | U | Eff | Module |
|---|------|--------|---|---|---|-----|--------|
| 6 | Contract address registry (mainnet + network param) | ✅ | 2 | 8 | 7 | 3.75 🎯 | `Onchain.Aave.Contracts` |
| 6b | Block fetching + timestamp binary search | ✅ | 3 | 7 | 8 | 2.50 🎯 | `Onchain.Block` |
| 7 | Aave math conversions (to_usd, to_ltv, to_ray) | ✅ | 3 | 9 | 8 | 2.83 🎯 | `Onchain.Aave.Math` |
| 8 | Pool read calls (getUserAccountData) + integration tests | ✅ | 5 | 9 | 8 | 1.70 🚀 | `Onchain.Aave.Pool` |
| 9 | UserAccountData response struct | ✅ | 5 | 8 | 7 | 1.50 📋 | `Onchain.Aave.Types.UserAccountData` |
| 10 | UiPoolDataProvider calls + remaining type structs + integration tests | ✅ | 5 | 8 | 7 | 1.50 📋 | `Onchain.Aave.UiPoolDataProvider` |
| 11 | Oracle + Chainlink price feeds + integration tests | ✅ | 5 | 7 | 6 | 1.30 📋 | `Onchain.Aave.Oracle` |
| 8b | Split unit and integration tests into separate files across all test modules | ✅ | 2 | 4 | 5 | 2.25 🚀 | `test/` |
| 21 | Multi-chain Aave addresses (Arbitrum, Optimism, Base, Polygon, Avalanche) | ✅ | 2 | 7 | 7 | 3.50 🎯 | `Onchain.Aave.Contracts` |

---

## Phase 2b: Read Essentials

Non-Aave read primitives that consumers need before write operations. Born from asking "what would I wish for if I were using this library?"

| # | Task | Status | D | B | U | Eff | Module |
|---|------|--------|---|---|---|-----|--------|
| 18 | Generic contract call (encode → eth_call → decode in one function) | ✅ | 3 | 9 | 9 | 3.00 🎯 | `Onchain.Contract` |
| 19 | eth_getLogs + event log parsing | ✅ | 4 | 9 | 8 | 2.13 🎯 | `Onchain.RPC` + `Onchain.Log` |
| 20 | ERC-20 read operations (balanceOf, allowance, decimals, symbol) | ✅ | 3 | 8 | 8 | 2.67 🎯 | `Onchain.ERC20` |
| 22 | Multicall3 batched contract reads | ✅ | 5 | 8 | 7 | 1.50 📋 | `Onchain.Multicall` |

**Task descriptions:**

**18 — Generic contract call.** The ABI encode → eth_call → ABI decode pipeline is the most common operation. Pool already does it internally. Expose a single function that takes contract address, function signature, params, return type, and opts — returns decoded values. Eliminates the 3-step `with` chain every consumer writes for non-Aave contracts.

**19 — eth_getLogs.** Add `eth_getLogs` to RPC with topic/address/block-range filtering. Add `Onchain.Log` for parsing raw logs against ABI event signatures. Without this, consumers can't do event-driven monitoring — no watching for liquidations, transfers, borrows, or repays.

**20 — ERC-20 reads.** Read-only token queries: `balanceOf/3`, `allowance/4`, `decimals/2`, `symbol/2`. These are just eth_call wrappers with known ABIs. "What's my USDC balance?" shouldn't wait for signing infrastructure. Write operations (approve, transfer) stay in Phase 3.

**22 — Multicall3.** Batch N arbitrary contract calls into a single RPC round-trip using Multicall3 (`0xcA11bde05977b3631167028862bE2a173976CA11`, deployed on every EVM chain). Takes a list of `{address, calldata}` tuples, returns list of results. The difference between "works" and "works fast enough to be useful" for position monitoring.

---

## Phase 3: Aave Actions (Write)

| # | Task | Status | D | B | U | Eff | Module |
|---|------|--------|---|---|---|-----|--------|
| 12 | Transaction signing setup + integration tests | ✅ | 4 | 9 | 9 | 2.25 🚀 | `Onchain.Signer` |
| 13 | ERC-20 write operations (approve, transfer) + integration tests | ✅ | 4 | 8 | 8 | 2.00 🚀 | `Onchain.ERC20` |
| 14 | Pool write calls (supply, borrow, repay, withdraw) + unit tests | ✅ | 6 | 9 | 8 | 1.42 📋 | `Onchain.Aave.Pool` |
| 14b | Pool write Sepolia integration tests | ✅ | 4 | 7 | 6 | 1.63 🚀 | `Onchain.Aave.Pool` |
| 23 | Transaction receipt + nonce RPC methods (eth_getTransactionReceipt, eth_getTransactionCount) | ✅ | 3 | 8 | 8 | 2.67 🎯 | `Onchain.RPC` |
| 35 | Aave testnet faucet module (mint test ERC-20 tokens programmatically) | ✅ | 2 | 4 | 3 | 1.75 🚀 | `Onchain.Aave.Faucet` |

---

## Phase 4: Consumer Migration — Out of Scope

Consumer integration work lives in the consumer repos (ccxt_ex, blockwatch, etc.), not here.

---

## Phase 5: Contract Codegen

Drop a `.sol` file, get a typed Elixir module. Rustler NIF using Alloy to parse Solidity at compile time, Elixir macros to generate typed wrappers. Aave is the beginning — Ethereum is full of contracts. DeFiSaver's open-source contracts (recipes, actions, triggers, flash loan wrappers) are a prime target: drop their `.sol` files, get typed modules for automated position management across protocols.

| # | Task | Status | D | B | U | Eff | Module |
|---|------|--------|---|---|---|-----|--------|
| 24 | Rustler NIF: Solidity ABI parser via Alloy | ⬜ | 5 | 9 | 9 | 1.80 🚀 | `Onchain.Solidity` (native) |
| 25 | Contract codegen macro (`use Onchain.Contract, sol: "...")`) | ⬜ | 6 | 10 | 9 | 1.58 🚀 | `Onchain.Contract.Generator` |

**Task descriptions:**

**24 — Rustler NIF: Solidity ABI parser.** Rustler NIF using Alloy to parse `.sol` files (or ABI JSON) into structured Elixir data at compile time. Returns function signatures, input/output types, state mutability, events — everything needed to generate typed wrappers. Thin bridge: "take string, return parsed ABI as map." Alloy is battle-tested (Foundry uses it for everything).

**25 — Contract codegen macro.** `use Onchain.Contract, sol: "priv/contracts/erc20.sol"` reads the `.sol` file via the Rustler NIF, generates raw call functions with proper typespecs, descripex `api()` declarations, and response struct skeletons at compile time. Delegates to `Onchain.Contract.call/4` (task 18) at runtime. Developers add semantic wrappers (like `UserAccountData.from_raw/1`) on top of generated raw functions. Depends on tasks 18 and 24. Once built, could subsume the manual wiring in tasks 10 (UiPoolDataProvider), 11 (Oracle), 14 (Pool writes), and 20 (ERC-20 reads) — those hand-written modules become validation references and semantic wrapper layers over generated raw functions.

---

## Phase 6: Local EVM Simulation

Simulate contract execution locally without hitting the chain. Reuses the Rustler NIF infrastructure from Phase 5. The user runs reth full nodes — optional enhanced features when connected to one, but core functionality works with any RPC.

| # | Task | Status | D | B | U | Eff | Module |
|---|------|--------|---|---|---|-----|--------|
| 26 | Rustler NIF: revm local EVM execution | ⬜ | 6 | 10 | 9 | 1.58 🚀 | `Onchain.EVM` (native) |
| 27 | Optional reth-enhanced module (trace/debug APIs) | ⬜ | 4 | 7 | 6 | 1.63 🚀 | `Onchain.Reth` |

**Task descriptions:**

**26 — revm NIF.** Rustler NIF wrapping revm for local EVM execution. Fork mainnet state (from any RPC or local reth node), simulate transactions locally — zero gas, zero latency. Core use cases: aave_sim runs hundreds of "what if" scenarios in milliseconds (supply X, borrow Y, price drops Z%); blockwatch tests liquidation thresholds without on-chain risk. Thin bridge: "give me state fork + transaction, return execution result." Reuses the Rustler infrastructure from task 24.

**27 — Optional reth module.** When connected to a local reth node, expose enhanced APIs beyond standard JSON-RPC: `debug_traceTransaction`, `trace_call`, direct state access. NOT a core dependency — the library works with any RPC endpoint. This module detects reth availability and unlocks richer simulation/debugging capabilities. Also enables faster state forking for revm (local node vs remote RPC). Depends on task 26.

---

## Phase 7: DEX Infrastructure

On-chain DEX trading support for ccxt_ex. Swap routing across liquidity pools and MEV protection for submitted transactions.

| # | Task | Status | D | B | U | Eff | Module |
|---|------|--------|---|---|---|-----|--------|
| 28 | DEX swap routing (optimal path across pools) | ⬜ | 7 | 8 | 7 | 1.07 📋 | `Onchain.DEX.Router` |
| 29 | MEV protection (private transaction submission) | ⬜ | 6 | 8 | 7 | 1.25 📋 | `Onchain.MEV` |

**Task descriptions:**

**28 — DEX routing.** Find optimal swap paths across DEX pools (Uniswap, Curve, Balancer). Could use Rust routing libs or implement in Elixir with revm for local simulation of candidate routes. Primary consumer: ccxt_ex when it adds DEX trading. Depends on tasks 18 (generic contract call) and 26 (revm for local route simulation).

**29 — MEV protection.** Private transaction submission via Flashbots-style APIs to prevent front-running on DEX trades. Could be Rust NIF (mev-rs) or Elixir HTTP client to Flashbots relay — evaluate when the time comes. Primary consumer: ccxt_ex DEX trades. Lower priority until DEX trading is active.

---

## Phase 8: Chain Intelligence Primitives

Read-layer primitives for wallet analytics and on-chain intelligence (Arkham-style). These are the building blocks a consumer needs to answer "who sent what to whom, when, and how much?" All downstream of existing read infrastructure (tasks 18-20) and enhanced by codegen (Phase 5).

| # | Task | Status | D | B | U | Eff | Module |
|---|------|--------|---|---|---|-----|--------|
| 30 | Wallet primitives (eth_getBalance, eth_getCode, eth_getTransactionByHash) | ⬜ | 3 | 8 | 9 | 2.83 🎯 | `Onchain.RPC` + `Onchain.Wallet` |
| 31 | Real-time subscriptions (eth_subscribe: newHeads, pendingTx, logs) | ⬜ | 5 | 9 | 8 | 1.70 🚀 | `Onchain.Subscription` |
| 32 | Transfer event parser (ERC-20/721/1155 → normalized structs) | ⬜ | 3 | 9 | 9 | 3.00 🎯 | `Onchain.Transfer` |
| 33 | ERC-721/ERC-1155 read operations (NFT tracking) | ⬜ | 3 | 6 | 5 | 1.83 🚀 | `Onchain.ERC721` + `Onchain.ERC1155` |
| 34 | ENS resolution (forward + reverse) | ⬜ | 3 | 7 | 7 | 2.33 🎯 | `Onchain.ENS` |

**Task descriptions:**

**30 — Wallet primitives.** Add `eth_getBalance` (native ETH balance), `eth_getCode` (contract vs EOA detection), and `eth_getTransactionByHash` (fetch full transaction details) to the RPC layer. These are the basic "what is this address?" primitives. Task 23 covers receipts but not the transaction itself — for tracing money flows you need both. `Onchain.Wallet` provides a thin convenience layer: `classify/2` returns `:eoa` or `:contract`, `balance/2` returns native ETH balance.

**31 — Real-time subscriptions.** `eth_subscribe` for `newHeads` (new blocks), `newPendingTransactions` (mempool monitoring), and `logs` (real-time event streaming). Without this, analytics are polling-based. zen_websocket already exists in the portfolio — this builds Ethereum-specific subscription management on top of it. Enables "notify me when this address receives tokens" without polling.

**32 — Transfer event parser.** The "follow the money" primitive. Parses ERC-20/721/1155 `Transfer` events into normalized `%Transfer{from, to, token, amount, token_standard, block, tx_hash}` structs. Builds on task 19 (eth_getLogs) with specialized decoders for the three token standards. This single module is the backbone of wallet tracking — every token movement on Ethereum emits a Transfer event.

**33 — ERC-721/ERC-1155 reads.** Read-only NFT queries: `ownerOf/3`, `tokenURI/3`, `balanceOf/3` for ERC-721; `balanceOf/4`, `uri/3` for ERC-1155. Same pattern as task 20 (ERC-20 reads) — eth_call wrappers with known ABIs. Needed for complete portfolio tracking beyond fungible tokens.

**34 — ENS resolution.** Forward resolution (`vitalik.eth` → `0xd8dA...`) and reverse resolution (`0xd8dA...` → `vitalik.eth`). Small contract surface, high impact for analytics UIs. Every address label in Arkham-style dashboards benefits from ENS names where available.

---

## Key Design Decisions

1. **Signet as sole Ethereum dep** — RPC, ABI, signing, crypto all in one
2. **Consumers configure RPC URL** — `config :signet, ...` or pass URL per-call
3. **Standard error tuples** — `{:ok, result} | {:error, {:tag, reason}}`
4. **Plain structs** — `defstruct` + `@enforce_keys`, no private macro deps
5. **Path dependency** — `{:onchain, path: "../onchain"}` in consumers
6. **Read-first, write-ready** — Phase 1-2 are read-only, Phase 3 adds write
7. **Descripex from day one** — All public modules use `api()` macro for self-describing functions. Not a separate task — built into each module as it's created. Enables `Onchain.describe/0-2` progressive discovery for agent consumers.
8. **Always update docs after completing a task** — Update ROADMAP.md (⬜→✅, strikethrough in priority list), CHANGELOG.md (add entry with what was done), and README.md (if the new module adds user-facing functionality). This is part of every task, not a separate step.
9. **Integration tests use mainnet RPCs** — `ETHEREUM_API_URL` (Alchemy) or `ETH_RPC_URL` (Infura) env vars. Use `Onchain.RPCCase.rpc_url!/0` from `test/support/rpc_case.ex` to resolve. Tests `flunk/1` with setup instructions if neither is set.

## Module Structure

```
lib/
  onchain.ex
  onchain/
    hex.ex                        # hex↔binary, hex↔integer, 0x prefix
    address.ex                    # validate, checksum (EIP-55), normalize
    abi.ex                        # encode_call/2, decode_response/2
    decimal.ex                    # to_decimal/2, to_basis_points/1, div_pow10/2
    block.ex                      # get_by_number, find_by_timestamp (binary search)
    contract.ex                   # generic call/4 (encode → eth_call → decode)
    contract/
      generator.ex                # macro: .sol → typed module at compile time
    solidity.ex                   # Rustler NIF: Alloy-powered .sol parser
    rpc.ex                        # eth_call, eth_getLogs, get_transaction_receipt, etc.
    log.ex                        # event log parsing against ABI signatures
    multicall.ex                  # Multicall3 batched reads
    signer.ex                     # key management, transaction signing
    erc20.ex                      # reads: balanceOf, allowance, decimals, symbol
                                  # writes: approve, transfer
    evm.ex                        # Rustler NIF: revm local EVM execution
    reth.ex                       # optional reth-enhanced APIs (trace, debug)
    dex/
      router.ex                   # DEX swap routing across pools
    mev.ex                        # MEV protection, private tx submission
    wallet.ex                     # classify (EOA/contract), native ETH balance
    subscription.ex               # eth_subscribe: newHeads, pendingTx, logs
    transfer.ex                   # Transfer event parser (ERC-20/721/1155 → structs)
    erc721.ex                     # reads: ownerOf, tokenURI, balanceOf
    erc1155.ex                    # reads: balanceOf, uri
    ens.ex                        # forward + reverse ENS resolution
    aave/
      math.ex                     # to_usd, to_ltv, to_health_factor, to_ray
      contracts.ex                # address registry (mainnet + network param)
      pool.ex                     # read: getUserAccountData | write: supply, borrow, repay
      ui_pool_data_provider.ex    # getReservesData, getUserReservesData
      oracle.ex                   # getAssetPrice + Chainlink fallback
      types/
        user_account_data.ex
        aggregated_reserve_data.ex
        base_currency_info.ex
        user_reserve_data.ex
native/
  onchain_solidity/              # Rustler NIF crate (Alloy + sol-types)
  onchain_evm/                   # Rustler NIF crate (revm)
priv/
  abis/
    aave_pool.json
    aave_addresses_provider.json
    aave_price_oracle.json
    chainlink_aggregator.json
  contracts/                     # .sol files → compiled to typed modules
```
