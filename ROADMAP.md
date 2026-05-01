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
| 38 | Pre-registration subscription buffer | Closes subscribe→Agent.update race silently-dropping notifications. Per-sub_id buffer cap 100, FIFO drain on registration, atomic Agent ops. Coverage 51% → 91% on `Onchain.Subscription`. |
| 39 | `:pending_transactions` integration test | Live mempool subscription against blockwatch-one; lifecycle test extended to exercise bang variants. Closes the v0.5.2 release plan. |
| — | **cartouche v0.1.0 published on hex.pm** (2026-04-30) | Fork of signet under `Cartouche.*` namespace, Elixir 1.20-compatible, published ABI dep (`hieroglyph` 1.0.0), cleaned dialyzer baseline. Unblocks Task 43 and triggers Task 67 (signet → cartouche dep migration). |
| — | **v0.4.0 Package Split** | Split into onchain (pure Elixir), onchain_aave, onchain_evm |
| 31 | Real-time subscriptions (eth_subscribe) | zen_websocket, newHeads/pendingTx/logs |
| 33 | ERC-721/ERC-1155 read operations | 7 ERC-721 + 4 ERC-1155 reads, checksummed address returns |
| 34 | ENS resolution (forward + reverse + text records) | Mainnet integration tested |
| 36 | Extract shared RPC helpers | DRY: 7 functions deduplicated |
| 44 | Fix CLAUDE.md Module Layout drift | `wallet.ex` + `erc20.ex` bullets now accurate |
| 45 | `ERC20.total_supply/2` + bang variant | Completes standard ERC-20 read surface |
| 46 | `Hex.from_integer/1` emits lowercase | Matches `Hex.encode/1` case convention |
| 37 | zen_websocket `send_message` `:disconnected` return | Resolved upstream in zen_websocket 0.4.1 (R042) |
| 47 | Hotfix: zen_websocket 0.4.x handler contract | Decoded maps replace raw binaries; dispatch path now unit-tested |
| 42 | Deliver subscription parse errors to handler | `{:parse_error, sub_id, reason}` events replace silent Logger.debug drop |
| 55 | Harden RPC address/data input validation | Tightened `ensure_hex_address/1` (rejects ASCII-"0x" 20-byte collision + odd-length bodies) and `ensure_hex_data/1` (rejects odd-length hex) |
| 56 | `eth_get_logs/2` filter-key whitelist | Unknown keys (including JSON-RPC-style `"fromBlock"`) now return `{:invalid_filter_key, key}` instead of silent `{:ok, []}` |
| 59 | `Onchain.RPC.call/3` + `call!/3` generic passthrough | Escape-hatch for any JSON-RPC method (`eth_getStorageAt`, `debug_traceTransaction`, `trace_call`, …); no decoding, same opts/error shape as named wrappers |
| 67 | `:signet` → `:cartouche` dep migration | hex.pm dep swap; every `Signet.*` reference renamed to `Cartouche.*`; `Onchain.*` public API byte-identical for consumers; bundled with Task 43 in v0.5.2 |
| 43 | Strip upstream-cascade dialyzer suppressions | All eleven `@dialyzer {:no_match, :no_return, :no_contracts}` blocks (`Onchain.ABI/Contract/ENS/Log/Multicall/Sleuth/Transfer/ERC20/ERC721/ERC1155/Hex`) now stale once cartouche 0.1.0 + hieroglyph 1.0.0 corrected the upstream specs; `mix dialyzer.json` clean post-strip. Bundled with Task 67 in v0.5.2. |

---

## Release Plan

Last shipped: **v0.5.2** (2026-05-01) — Subscription hardening. Closes Tasks 38 (pre-registration buffer for subscription notifications) and 39 (`:pending_transactions` integration test against blockwatch-one), bundled with the deferred Tasks 42 (subscription parse-error delivery), 43 (strip upstream-cascade dialyzer suppressions), 55 + 56 (RPC input hardening), 59 (generic JSON-RPC passthrough), 62 (Sleuth deploy-as-call), and 67 (`:signet` → `:cartouche` dep migration) from the v0.5.0–v0.5.1 backlog.

### 🎯 v0.5.2 — Subscription hardening (next, patch, non-breaking)

Finishes what v0.5.0/0.5.1 started on the subscription path and clears the upstream-cascade dialyzer suppressions that the cartouche 0.1.0 fork (Task 67) unblocked — Task 43 stripped them post-migration on 2026-04-30.

| Task | Eff | What | Why in this release |
|------|-----|------|---------------------|
| 43 ✅ | 3.00 | Remove `@dialyzer {:no_match, ...}` suppressions | Stripped 2026-04-30 in the commit immediately after Task 67. All eleven module suppressions (`Onchain.ABI/Contract/ENS/Log/Multicall/Sleuth/Transfer/ERC20/ERC721/ERC1155/Hex`) were stale once cartouche 0.1.0 + hieroglyph 1.0.0 landed; `mix dialyzer.json` clean post-strip. `Onchain.Subscription` (zen_websocket cause) and `Onchain.RPC.Helpers.do_rpc/3` (cartouche RPC error-shape — re-probed, still narrow) intentionally retained. |
| 42 ✅ | 1.75 | Deliver subscription parse errors to handler | Silent drops → `{:parse_error, sub_id, reason}` events |
| 39 ✅ | 1.50 | `:pending_transactions` integration test | Shipped 2026-05-01. Live mempool broadcast via blockwatch-one; assert hash shape, unsubscribe cleanly |
| 38 ✅ | 1.17 | Buffer unknown sub_ids during subscribe race | Shipped 2026-05-01. Per-sub_id pending buffer (cap 100, FIFO drain on register), atomic Agent ops, bang-variant coverage; `Onchain.Subscription` coverage 51% → 91% |

**Acceptance:** all four tasks closed or returned with written rationale; no breaking API changes; CHANGELOG `[Unreleased]` → `v0.5.2` on tag. **Status: ready to tag** — Tasks 38, 39, 42, 43, 55, 56, 59, 62, 67 all shipped under `v0.5.2` in CHANGELOG (2026-05-01).

### 🚀 v0.6.0 — Package split: `onchain_ws` (minor, breaking)

| Task | Eff | What |
|------|-----|------|
| 48 | 1.38 | Extract `Onchain.Subscription` (+ `.Parser`) into sibling `onchain_ws`, drop `zen_websocket` dep from `onchain` |

**Breaking:** consumers using subscriptions must add `{:onchain_ws, path: "../onchain_ws"}`. Justifies minor bump. Ship standalone — do not bundle with v0.5.2 patches.

**Acceptance:** per Task 48 criteria already in Code Health section.

### Future (v0.7.0+, unscheduled)

Phase 7 (Tasks 28–29: DEX routing, MEV protection) and Task 41 (ENS enhancements) remain unscored for release grouping — they need consumer-project pressure and their own design phases before inclusion.

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

## Phase 9: Account Abstraction (ERC-4337)

| # | Task | Status | D | B | U | Eff | Module |
|---|------|--------|---|---|---|-----|--------|
| 69 | ERC-4337 UserOperation construction, signing, and bundler RPC | ⬜ | 7 | 8 | 7 | 1.07 📋 | `Onchain.AA` (new) |

**Task 69 — ERC-4337 account abstraction.** [D:7/B:8/U:7 → Eff:1.07 📋]

Add ERC-4337 support: UserOperation construction, signing, and bundler RPC (`eth_sendUserOperation`, `eth_estimateUserOperationGas`, `eth_getUserOperationByHash`, `eth_getUserOperationReceipt`, `eth_supportedEntryPoints`). Cover both v0.6 and v0.7 EntryPoint shapes if they're both still relevant when this is picked up. Include tests.

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
| 37 | zen_websocket: `send_message/2` should return `{:error, :disconnected}` instead of `:noproc` exit when server is dead | ✅ | 2 | 7 | 6 | 3.25 🎯 | `ZenWebsocket.Client` (resolved upstream in 0.4.1, R042) |
| 38 ✅ | Subscription: buffer unknown sub_ids to close subscribe→Agent.update race window. Shipped 2026-05-01 — per-sub_id pending buffer (cap 100, FIFO drain on register), atomic Agent ops via `lookup_or_buffer/3` + `register_and_drain/3` + `remove_subscription/2` helpers. `Onchain.Subscription` test coverage 51% → 91%. | ✅ Complete | 3 | 4 | 3 | 1.17 📋 | `Onchain.Subscription` |
| 39 ✅ | Subscription: `:pending_transactions` integration test against blockwatch-one (live mempool broadcast). Shipped 2026-05-01. Asserts at least one 32-byte tx hash arrives within 30s, unsubscribes cleanly. Lifecycle test simultaneously upgraded to exercise bang variants (`connect!`/`subscribe!`/`unsubscribe!`). | ✅ Complete | 2 | 3 | 3 | 1.50 📋 | `test/onchain/subscription_integration_test.exs` |
| 40 | Switch Credo back to Hex release (moved from `release/1.7` git branch to `{:credo, "~> 1.7"}` — resolved at 1.7.18) | ✅ | 1 | 4 | 3 | 3.50 🎯 | `mix.exs` |
| 41 | ENS enhancements: CCIP-Read / EIP-3668 off-chain lookups, ENSIP-10 wildcard resolution, full UTS-46 / ENSIP-15 Unicode normalization, multi-coin address resolution (currently ETH-only via `addr(bytes32)`) | ⬜ | 6 | 6 | 5 | 0.92 ⚠️ | `Onchain.ENS` |
| 42 | Subscription: deliver parse errors to the handler as `{:parse_error, sub_id, reason}` events instead of silently dropping malformed notifications | ✅ | 2 | 4 | 3 | 1.75 🚀 | `Onchain.Subscription` |
| 43 ✅ | Upstream spec fix tracking: remove `@dialyzer {:no_match, ...}` suppressions across the eleven modules that flow through `ABI.decode_response/2` (`Onchain.ABI/Contract/ENS/Log/Multicall/Sleuth/Transfer/ERC20/ERC721/ERC1155/Hex`). Stripped 2026-04-30 immediately after Task 67; cartouche 0.1.0 + hieroglyph 1.0.0 carry the corrected upstream specs. `Onchain.Subscription` (zen_websocket) and `Onchain.RPC.Helpers.do_rpc/3` (cartouche RPC error-shape) intentionally retained. | ✅ Complete | 1 | 3 | 3 | 3.00 🎯 | Multiple |
| 44 | Fix CLAUDE.md Module Layout drift: `wallet.ex` and `erc20.ex` bullets now match actual exports | ✅ | 1 | 3 | 4 | 3.50 🎯 | `CLAUDE.md` |
| 45 | Add `Onchain.ERC20.total_supply/2` (+ bang variant) to complete the standard ERC-20 read surface | ✅ | 2 | 5 | 6 | 2.75 🎯 | `Onchain.ERC20` |
| 46 | Make `Onchain.Hex.from_integer/1` emit lowercase hex to match `Onchain.Hex.encode/1` | ✅ | 1 | 2 | 2 | 2.00 🚀 | `Onchain.Hex` |
| 47 | Hotfix: zen_websocket 0.4.x handler contract — decoded maps replace raw binaries in `{:message, _}`; subscription notifications were silently dropped under the old pattern match | ✅ | 2 | 7 | 8 | 3.75 🎯 | `Onchain.Subscription` |
| 48 | Extract `Onchain.Subscription` into `onchain_ws` package so HTTP-only consumers don't pull `zen_websocket` and its transitive WebSocket deps | ⬜ | 4 | 6 | 5 | 1.38 📋 | `onchain_ws` (new package) |
| 55 | Harden `Onchain.RPC.Helpers` address/data validation — four silent-corruption / contract-violation paths | ✅ | 2 | 9 | 8 | 4.25 🎯 | `Onchain.RPC.Helpers` |
| 56 | 🐛 `Onchain.RPC.eth_get_logs/2` silently ignores wrong filter-key names (`fromBlock`/`toBlock` vs `:from_block`/`:to_block`) — returns `{:ok, []}` instead of erroring | ✅ | 2 | 6 | 7 | 3.25 🎯 | `Onchain.RPC` |
| 60 | Log filter ergonomics: accept camelCase `"fromBlock"` / `"toBlock"` aliases (post-Task 56 follow-up — strict whitelist is easy to loosen via a normalization layer) | ⬜ | 2 | 4 | 4 | 2.00 🚀 | `Onchain.RPC` |
| 61 | `eth_get_logs/2` filter should support `:block_hash` (EIP-1474 — `blockHash` excludes `fromBlock`/`toBlock` when set) — currently rejected by Task 56 whitelist | ⬜ | 2 | 3 | 4 | 1.75 🚀 | `Onchain.RPC` |
| 57 | Unify RPC return shapes: `get_transaction_by_hash/2` returns decoded atom-keyed struct, `get_block_by_number/2` returns raw string-keyed hex map — pick one | ⬜ | 4 | 6 | 6 | 1.50 🚀 | `Onchain.RPC` |
| 58 | Alias `Onchain.ABI.decode_types/2` → `decode_response/2` + document tuple-signature requirement | ⬜ | 1 | 3 | 4 | 3.50 🎯 | `Onchain.ABI` |
| 63 | `defrpc` macro — codegen named JSON-RPC wrappers from declarative specs (refactor of existing 11 `Onchain.RPC.*` wrappers); follows Phoenix.Router shape, gated by Nimble.Options schema | ⬜ | 4 | 6 | 5 | 1.38 📋 | `Onchain.RPC` |
| 64 | Vendor `openrpc.json` from `ethereum/execution-apis` + emit `Onchain.RPC.Specs` lookup that feeds `defrpc` (93 methods across `eth_*`/`engine_*`/`debug_*`/`txpool_*`/`net_*`/`testing_*`) — gated on Task 63 | ⬜ | 4 | 6 | 5 | 1.38 📋 | `Onchain.RPC.Specs` (new) |
| 65 | Differential test harness: same RPC method via `Onchain.RPC` vs reference impl (signet first, then Web3.py / viem if needed) — catches protocol-level mistakes unit tests miss | ⬜ | 6 | 5 | 3 | 0.67 ⚠️ | `test/onchain/differential/` |
| 66 | Tree-sitter scrape of Erigon Go source for `trace_*` / `ots_*` method enumeration (~30 methods OpenRPC doesn't cover) — gated on Task 64 + actual consumer demand | ⬜ | 5 | 4 | 3 | 0.70 ⚠️ | dev-only `Mix.Task` |
| 67 ✅ | Migrate `:signet` → `:cartouche` dep (renames every `Signet.*` reference to `Cartouche.*`, swaps `{:signet, "~> 1.6"}` for `{:cartouche, "~> 0.1"}` in `mix.exs`). Breaking — bumps minor version. Required before Task 43 can close. | ✅ Complete | 4 | 7 | 8 | 1.88 🚀 | Multiple |
| 68 | Mine `defi-skills:intent-to-transaction` action surface for `onchain` coverage gaps | ⬜ | 3 | 8 | 7 | 2.50 🎯 | (cross-cutting research) |
| 70 | Harden `Onchain.Subscription.lookup_or_buffer/3` against unsolicited sub_id keys: `pending` map has per-key cap of 100 but unbounded distinct-keys count. Server emitting notifications for never-`subscribe`-d sub_ids grows key set until connection closes (per-connection Agent dies with the conn, so blast radius is bounded — but worth fixing). Buffer only sub_ids in an in-flight subscribe state, or add a global key cap with eviction. Carry forward to `onchain_ws` extraction (Task 48). | ⬜ | 3 | 4 | 3 | 1.17 📋 | `Onchain.Subscription` |

**Task 55 — Harden `Onchain.RPC.Helpers` address/data validation.**

Discovered 2026-04-22 during `onchain_aave` Task 41 (first real consumer integration through `onchain_evm`). Four bugs in one file — all silent-corruption or contract-violating. Two are critical:

- **`ensure_hex_address/1` silently corrupts 20-byte strings that look like short `0x` inputs.** `"0x" <> String.duplicate("a", 18)` is 20 chars / 20 bytes (ASCII); it matches the 20-byte-binary branch and returns `{:ok, "0x3078616161..."}` — the ASCII codes of `"0x"` and `"a"` hex-encoded into a completely different address. A user typo routes an RPC call to a wrong address with no way to detect. Fix: dispatch on `"0x" <> _` prefix before the 20-byte-binary branch.
- **`ensure_hex_address/1` silently zero-pads 39-char `0x` strings.** `"0x" <> "a" * 39` → `{:ok, "0x0aaa...aaa"}` (odd-length hex body silently zero-padded to 40 = 20 bytes). Fix: reject all non-42-char `0x`-prefixed inputs.
- **`ensure_hex_address/1` accepts 40-char hex without `0x` prefix.** Inherited from `Address.validate/1`'s permissive input handling (by design — "with or without 0x"), but the RPC-helper layer should require `0x`-prefix so ambiguity doesn't reach `Signet.RPC`. Also the stepping stone to the critical 20-byte collision above.
- **`ensure_hex_data/1` accepts odd-length `0x` strings.** `"0xabc"` passes Elixir; Rust in `onchain_evm` surfaces it as `{:evm_error, "invalid hex: Odd number of digits"}` — wrong error class for what's clearly invalid input data. Catch at Elixir as `{:invalid_data, _}`.

**Acceptance:** per-failure-mode unit tests; all four paths return `{:error, {:invalid_address, _}}` or `{:error, {:invalid_data, _}}`; zero silent coercion; `onchain_aave` and `onchain_evm` test suites stay green.

---

**Task 56 — `eth_get_logs/2` silent key-drop.**

Discovered 2026-04-22 during onchain_aave on-chain investigation: passing JSON-RPC-style keys (`fromBlock`, `toBlock`) to the filter map returns `{:ok, []}` instead of erroring — the caller sees "no logs in range" when the real cause is "filter had zero matching keys". Lost ~15 minutes to this; silent empties are the worst failure mode for discovery code.

Fix: validate filter keys at entry. Either reject unknown keys (`{:error, {:invalid_filter_key, key}}`), or accept both snake_case and camelCase. Either beats silent drop. Unit test the rejection / normalization path.

---

**Task 57 — Unify `get_block_*` / `get_transaction_*` return shapes.**

`get_transaction_by_hash/2` returns an atom-keyed struct with integers decoded (`%{value: 0, block_number: 24933341, …}`). `get_block_by_number/2` returns a raw string-keyed map with hex-string values (`%{"baseFeePerGas" => "0x7e479377", …}`). Callers have to remember which returns which, and the second shape forces manual `String.to_integer/2`.

Pick one: either both decode to atom-keyed structs (`Onchain.Block.t()`, `Onchain.Transaction.t()`), or both surface raw string-keyed maps (caller-decodes). Leaning toward decoded structs — matches the Phase 8 transfer-parser direction and the `Onchain.Transfer` pattern.

Breaking change for consumers of `get_block_by_number/2`; justify with a minor-version bump and a brief migration note in CHANGELOG.

---

**Task 58 — `ABI.decode_types` alias + tuple-sig docs.**

`decode_response(sig, hex)` is the right function for decoding calldata return data by type signature, but `decode_types` is a more natural name when the input isn't an RPC response (e.g. decoding arbitrary ABI-encoded bytes). Aliasing is 5 lines. Also document in the docstring that the sig string *must* be wrapped in parentheses (`"(address,uint256)"` not `"address,uint256"`) — bare comma-separated types error with an unhelpful message. Minor polish, but both footguns are real (I hit the first, expected the second by name).

---

**Task 63 — `defrpc` macro to codegen named JSON-RPC wrappers from declarative specs.** [D:4/B:6/U:5 → Eff:1.38 📋]

Discovered 2026-04-23 during Task 59 design discussion; framing revised 2026-04-23 after surfacing Phoenix.Router / Nimble.Options precedents. The 11 existing `Onchain.RPC.*` wrappers (`eth_call`, `block_number`, `chain_id`, `get_balance`, `get_block_by_number`, `get_transaction_receipt`, `get_transaction_count`, `eth_get_code`, `get_transaction_by_hash`, `eth_get_logs`, `eth_send_raw_transaction`) follow a near-identical shape: per-arg validation + param construction + `do_rpc(method, params, to_signet_opts(opts))` + an identical bang variant + a Descripex `api()` annotation. A `defrpc` macro expands a declaration like `defrpc :block_number, "eth_blockNumber", decode: :hex_unsigned, description: "..."` into the full function + bang + `api()` + `@spec`.

**Precedents that disprove the "macros are scary" objection.** This shape is well-trodden in Elixir: `Phoenix.Router` (declarative HTTP route DSL handling 6+ orthogonal concerns since 2014), `Ecto.Schema` (split `field/3` / `belongs_to/3` / `has_many/3` for genuinely-different shapes), `Absinthe.Schema` (GraphQL field DSL with arg validation + resolvers). `defrpc` faces strictly *less* variance than any of them. The "macro grows unchecked knobs" failure mode is solved by `Nimble.Options` — define a `NimbleOptions.validate!/2` schema for the option keyword list; the schema *is* the macro's contract; adding a knob requires changing the schema, which makes drift visible.

Variance the macro must handle: per-arg validators (`ensure_hex_address`, `normalize_block`, `ensure_hex_data`, `ensure_tx_hash`); nested-map param construction (`eth_call`'s `%{"to" => ..., "data" => ...}`); literal extra params (`get_block_by_number`'s `false`); filter-key whitelist + filter-dict construction (`eth_get_logs` per Task 56); `:decode` flag pass-through (mapping to `Onchain.Hex.to_integer/1`, raw hex passthrough, struct decoders); descripex `returns:` shape variation. If a case genuinely doesn't fit (e.g. `eth_get_logs`'s filter shape), follow Ecto's lesson and add a sibling macro (`defrpc_with_filter`) rather than overloading `defrpc`.

**Gate:** prototype against the existing 11 functions in a branch. Ship if (a) the call-site diff actually shrinks, (b) the `NimbleOptions` schema stays smaller than the variance it absorbs, and (c) the public surface is byte-identical (returns, error shapes, descripex hints, dialyzer story all unchanged). Kill the prototype if the macro's option schema balloons past ~10 keys or if 3+ wrappers need bespoke escape hatches — that's the real "more knobs than duplication removed" signal, observable on the prototype, not speculated about in advance. Unblocks Task 64 (vendor `openrpc.json` + emit `Onchain.RPC.Specs` lookup → ~93 methods become declarative one-liners).

Acceptance: macro lives in `Onchain.RPC` (or a private helper module); `NimbleOptions` schema documents the public contract; existing 11 functions reimplemented through it with byte-identical public behavior; test suite green without changes; CHANGELOG entry explains the refactor and notes there's no API change.

---

**Task 64 — Vendor `openrpc.json` + emit `Onchain.RPC.Specs` lookup feeding `defrpc`.** [D:4/B:6/U:5 → Eff:1.38 📋] *(gated on Task 63)*

Discovered 2026-04-23 during Task 59 design discussion, refined after surveying 22 candidate sources for an Ethereum-RPC method spec. Winner by a wide margin: the `openrpc.json` document built from [`ethereum/execution-apis`](https://github.com/ethereum/execution-apis) (`make build` resolves all `$ref`s into a single self-contained JSON). Covers **93 methods across 6 namespaces** as of `v1.0.0-beta.4` (2026-04): `eth_*` (57), `engine_*` (26), `debug_*` (5), `txpool_*` (3), `net_*` (1), `testing_*` (1).

Vendor a pinned `openrpc.json` under `priv/specs/openrpc-v1.0.0-betaN.json`. Write a `Mix.Task` (or `Onchain.RPC.SpecLoader`) that parses it with `Jason` at compile time (no YAML dep needed; the JSON form has refs already resolved) and emits a compile-time map: `%{"eth_blockNumber" => %{params: [], returns: ..., description: ...}, ...}`. Optionally wire that map into Task 63's `defrpc` so a single declaration like `defrpc :block_number, "eth_blockNumber"` pulls params/returns/description from the spec.

Refresh procedure: `wget` the latest tagged release's `openrpc.json`, diff against the vendored copy, bump the pin, re-run tests. Reasonable cadence: once per Ethereum hardfork cycle (~every 6 months).

Acceptance: vendored JSON + version pin documented in CHANGELOG; `Onchain.RPC.Specs.lookup("eth_blockNumber")` returns the parsed spec; if Task 63 has landed, at least 3 existing wrappers are reimplemented through `defrpc :name, "method_name"` with byte-identical behavior.

**Where to find additional endpoints not in OpenRPC** (for consumers / future tasks):

| Method family | Source | Notes |
|---|---|---|
| `web3_*` (`web3_clientVersion`, `web3_sha3`) | [ethereum.org JSON-RPC docs](https://ethereum.org/developers/docs/apis/json-rpc/) | 2 methods, hand-document — too small to codegen |
| `net_listening`, `net_peerCount` | ethereum.org JSON-RPC docs | OpenRPC has only `net_version`; the other 2 are widely supported but missing from spec |
| `trace_*` (Parity/Erigon trace API) | [Erigon `turbo/jsonrpc/trace_*.go`](https://github.com/erigontech/erigon/tree/main/turbo/jsonrpc) | Non-standard; geth doesn't implement. Hand-list or tree-sitter scrape |
| `ots_*` (Otterscan extensions) | [Erigon `turbo/jsonrpc/otterscan_*.go`](https://github.com/erigontech/erigon/tree/main/turbo/jsonrpc) | Erigon-only |
| `admin_*` | Geth wiki / [`internal/ethapi`](https://github.com/ethereum/go-ethereum/tree/master/internal/ethapi) | Non-standard, node-management |
| `optimism_*`, `arb_*`, `base_*` (L2 extensions) | Per-L2 docs ([Optimism RPC](https://docs.optimism.io/builders/node-operators/json-rpc), [Arbitrum](https://docs.arbitrum.io/build-decentralized-apps/reference/node-providers#extra-arb-methods), Base) | Per-chain divergence — likely belongs in chain-specific packages, not core `onchain` |
| Runtime discovery | [`rpc.discover` (OpenRPC)](https://spec.open-rpc.org/#service-discovery-method) | `RPC.call("rpc.discover", [], opts)` returns the node's self-description if the client supports it. Erigon does; geth doesn't |

Rule of thumb: if a method isn't in OpenRPC, it's either node-vendor-specific (Erigon, geth-only) or chain-specific (L2). Hand-add via `defrpc` when a real consumer needs it; don't preemptively codegen the long tail.

---

**Task 65 — Differential test harness comparing `Onchain.RPC` results against an alternative implementation.** [D:6/B:5/U:3 → Eff:0.67 ⚠️]

Discovered 2026-04-23 during the same survey. The named wrappers are unit-tested, but unit tests don't catch *protocol-level* mistakes: wrong param ordering against the spec, wrong nesting on map params, wrong block-tag handling for edge cases (`"safe"`, `"finalized"`, `"earliest"`), wrong response decoding for sparsely-populated fields. A differential harness runs the same RPC method against the same node via `Onchain.RPC` *and* a reference implementation, then asserts equality.

Reference candidates (in order of cost):
1. **signet** itself — already in deps, pure Elixir, zero new infra. Weakest oracle (errors might correlate with us) but cheapest. Worth doing first.
2. **Web3.py** via external Python invocation — moderate cost (Python toolchain), strong oracle (independent codebase, mature).
3. **viem** via [elixir-volt](https://github.com/efries/elixir-volt) (OXC + QuickBEAM + npm_ex) — highest cost (native NIFs), strongest oracle (canonical TS implementation, encodes Ethereum-the-spec via opinionated wrappers). Only worth it if Tasks 65a/65b find nothing.

Scope: harness lives in `test/onchain/differential/`, marked `@tag :differential`, gated behind an env var, runs against `ETHEREUM_API_URL`. Tests pick ~10 methods covering map-param construction (`eth_call`, `eth_getLogs`), block-tag variance (`eth_getBlockByNumber` with all 5 tags), and decoding edge cases (`eth_getTransactionReceipt` for failed/contract-creation/EIP-1559 txs). Compares JSON-stringified Onchain output against reference output for the same inputs.

Acceptance: harness runs ≥10 methods against signet as oracle; documents any divergences as either Onchain bugs (fix) or signet differences (annotate). Tasks 65b/65c (Web3.py, viem) deferred until 65a finds at least one bug — if signet-as-oracle is silent for 6 months, the higher-cost oracles aren't earning their complexity.

---

**Task 66 — Source-scrape `trace_*` / `ots_*` method enumeration via tree-sitter on Erigon Go source.** [D:5/B:4/U:3 → Eff:0.70 ⚠️]

Discovered 2026-04-23. The OpenRPC spec doesn't cover Erigon-specific namespaces (`trace_*` ≈ 18 methods, `ots_*` ≈ 12 methods). Hand-listing them is error-prone and goes stale silently. Tree-sitter (`{:tree_sitter, "~> 0.x"}`) can parse Erigon's Go source at compile time and emit a method list.

Approach: vendor a pinned commit of [`erigon/turbo/jsonrpc/`](https://github.com/erigontech/erigon/tree/main/turbo/jsonrpc) under `priv/specs/erigon-COMMIT/`. Tree-sitter grammar matches function definitions on `*TraceAPIImpl` / `*OtterscanAPIImpl` receivers; method name = lowercased method name (Erigon convention). Emit a JSON list to `priv/specs/erigon-methods.json`. Refresh quarterly.

Risks:
- Tree-sitter is a NIF — violates Onchain's pure-Elixir invariant. Mitigate by running the scrape as a `Mix.Task` (dev-only dep, not runtime) that produces a vendored JSON output. Runtime stays pure-Elixir reading the JSON.
- Erigon refactors aggressively (scored 5/10 on drift in the source survey). Pin the commit; expect quarterly refresh churn.
- Population is small (~30 methods total). Hand-listing in `defrpc` declarations might be cheaper than the tooling.

Only worth pursuing if (a) Task 64 ships and the OpenRPC pipeline is proven, (b) consumers actually call `trace_*` / `ots_*` methods enough to motivate named wrappers, and (c) hand-maintenance of the list has produced ≥1 staleness bug. Otherwise: leave as `call/3` users with a docstring example.

Acceptance: `Mix.Task` `mix onchain.scrape_erigon_methods` produces `priv/specs/erigon-methods.json`; CHANGELOG documents the pinned Erigon commit; the resulting JSON is consumable by Task 63's `defrpc` (or hand-mapped if 63 hasn't shipped).

---

**Task 67 — Migrate `:signet` → `:cartouche` dep.** [D:4/B:7/U:8 → Eff:1.88 🚀]

Cartouche 0.1.0 published on hex.pm 2026-04-30. The fork ports the upstream signet codebase under the `Cartouche.*` module tree (every `Signet.X` callsite becomes `Cartouche.X`), pins Elixir 1.20 compatibility, and depends on the published ABI fork `hieroglyph` 1.0.0 instead of the unpublished upstream `:abi` path dep. Cartouche's CHANGELOG documents the spec corrections that make onchain's Task 43 (`@dialyzer {:no_match, ...}` strip) safe to land — those corrections are not in upstream signet and won't be backported.

**Why now.** Three pressures align: (a) Task 43 has been blocked on this since 2026-04-19; (b) cartouche carries Elixir 1.20 compatibility that upstream signet doesn't; (c) `hieroglyph` is published, so onchain stops depending on a path/git-only `:abi` if/when it would have needed one.

**Scope.** `mix.exs` dep swap; `mix deps.get`; rename every `Signet.*` reference under `lib/onchain/**/*.ex` and `test/**/*.exs` to `Cartouche.*`; `config :signet, ...` keys (RPC URL config — see `Key Design Decisions #3`) change to `config :cartouche, ...` (verify the actual key name in the cartouche README/CHANGELOG before flipping). Run `mix test.json --quiet` and `mix dialyzer.json --quiet`. Update CLAUDE.md "Signet as sole Ethereum dep" wording.

**Bundled with the migration:** Task 43 (strip the now-load-bearing `@dialyzer {:no_match, ...}` suppressions) — the migration is the precondition; the suppression strip is the immediate payoff. Counted separately so each can land in its own commit, but they ship in the same release.

**Breaking change for onchain consumers.** `Onchain.*` public API doesn't change shape, but consumers' transitive dep tree changes (`:signet` drops, `:cartouche` + `:hieroglyph` add). Justifies a minor bump (v0.6.0 if Task 48 hasn't shipped, v0.7.0 otherwise). Document the dep-tree change in CHANGELOG.

**Acceptance:**
- `mix.exs` lists `{:cartouche, "~> 0.1"}` instead of `{:signet, ...}`; no `:signet` reference remains in the project (confirmed via `mix deps.tree`)
- All `Signet.*` references in `lib/`, `test/`, and `config/` renamed to `Cartouche.*`
- `mix test.json --quiet` green
- `mix dialyzer.json --quiet` clean — Task 43's suppressions stripped in a follow-up commit, both shipping in the same release (v0.5.2)
- CLAUDE.md "Signet as sole Ethereum dep" updated to "Cartouche as sole Ethereum dep" (the parenthetical "RPC, ABI, signing, crypto all in one" stays accurate — `hieroglyph` is the ABI dep but is pulled in transitively by cartouche, not directly by onchain)
- README example snippets updated if they show `Signet.*` calls (verify; onchain may not have any)
- CHANGELOG entry under `[Unreleased]` documenting the dep swap and the resulting dep-tree change for downstream consumers

---

**Task 48 — Extract subscription into `onchain_ws`.**

Create a sibling package (`../onchain_ws`) that depends on `onchain` (path dep) and `zen_websocket`, and move `Onchain.Subscription` + `Onchain.Subscription.Parser` into it. Base `onchain` should no longer depend on `zen_websocket` after the move.

Motivation: HTTP-only consumers (RPC reads, signing, ERC-20 transfers) currently pull `zen_websocket` and its WebSocket transitive deps transitively even when they never subscribe. Making subscriptions an opt-in capability package matches the portfolio pattern (onchain_aave, onchain_evm, onchain_js, onchain_tempo).

Acceptance criteria:
- `onchain` `mix.exs` no longer lists `zen_websocket` as a dep
- `Onchain.Subscription.*` tests run in the new package and pass
- New repo mirrors sibling packages (CHANGELOG, README, ROADMAP, CLAUDE.md, standard dev tooling per `elixir-setup`)
- CLAUDE.md Module Layout in `onchain` updated to remove `subscription.ex` + `subscription/parser.ex`
- CLAUDE.md Portfolio Context section adds `onchain_ws` with "Where does this feature go?" entry
- Decide on namespace: keep `Onchain.Subscription` (transparent to consumers) or move to `OnchainWS.Subscription` (explicit package boundary). Leaning toward keeping `Onchain.Subscription` since consumers don't need to care about the split.

---

**Task 68 — Mine `defi-skills:intent-to-transaction` action surface for `onchain` coverage gaps.** [D:3/B:8/U:7 → Eff:2.50 🎯]

Planted 2026-04-30 from a cartouche session that surveyed cross-repo applicability of the `defi-skills` skill. Self-contained discovery exercise — execute it from a fresh `onchain` Claude Code session so this repo's CLAUDE.md, hooks, and test fixtures are loaded.

**Prompt for the executing session:**

> Invoke `/defi-skills:intent-to-transaction` to load the skill, then run `defi-skills actions --json` to enumerate the supported action surface (~50 actions across Aave, Uniswap, Lido, Compound, Balancer, Pendle, EigenLayer, Curve, MakerDAO, Rocket Pool, Fibrous, WETH).
>
> Map relevant actions to **`onchain`'s scope: higher-level wrapper patterns** — token-symbol resolution (e.g. `USDC` → address), base-unit conversion (decimals lookup), approval-then-action sequencing, multi-tx orchestration. Don't propose protocol-specific wrappers (those go to `onchain_aave` etc.); focus on cross-protocol primitives that every protocol package would otherwise reimplement.
>
> For each gap or coverage opportunity, propose a ROADMAP entry with D/B/U scoring per `~/.claude/includes/task-prioritization.md`. Output: a "Proposed additions from defi-skills mining" section the user reviews and merges into the main task tables before any implementation begins.
>
> Read-only exercise — discovery + scoring only, no `Onchain.*` code edits in this task itself. The skill is already installed (`pip install defi-skills`); no new deps. Companion tasks were planted in `hieroglyph`, `onchain_aave`, and `onchain_evm` ROADMAPs the same day, with a downstream cartouche audit task gated on all four landing.

**Acceptance:** a "Proposed additions from defi-skills mining" section lands in this ROADMAP listing each candidate task with D/B/U scores, scope notes, and which `defi-skills` actions motivated it. The user merges accepted entries into the Code Health table.

---

## Phase 10: RPC Composition Layer

**Motivation:** Per the scope split with cartouche (see `../signet/ROADMAP.md` "Scope principle" — sibling design-discussion repo retains its historical name), onchain is home for everything buildable on top of `Cartouche.*` public surface. This phase collects RPC method wrappers, observability facades, and helpers over cartouche structs that would otherwise have been upstream-PR candidates but correctly belong here. Each task is small; not urgent individually. Batch as needed — no consumer blocking.

| # | Task | Status | D | B | U | Eff | Module |
|---|------|--------|---|---|---|-----|--------|
| 49 | `Onchain.RPC.get_proof/3` — wrap `eth_getProof` (account + storage-slot Merkle proofs) | ⬜ | 2 | 4 | 4 | 2.00 🚀 | `Onchain.RPC` |
| 50 | `Onchain.RPC.syncing/1` — wrap `eth_syncing` | ⬜ | 1 | 2 | 3 | 2.50 🎯 | `Onchain.RPC` |
| 51 | `Onchain.RPC.batch/2` — JSON-RPC 2.0 array-batched requests (single round-trip over N method calls) | ⬜ | 4 | 6 | 5 | 1.38 📋 | `Onchain.RPC` |
| 52 | Telemetry events around `Onchain.RPC` request path (`[:onchain, :rpc, :request]`) | ⬜ | 3 | 5 | 5 | 1.67 🚀 | `Onchain.RPC` |
| 53 | `Onchain.Fees.suggest_fees/2` — take `Signet.FeeHistory.t()` + percentile, return `{base_fee, max_priority, max_fee}` recommendation | ⬜ | 2 | 5 | 6 | 2.75 🎯 | `Onchain.Fees` (new) |
| 54 | Opt-in retry/backoff wrapper over `Signet.RPC.send_rpc/3` with configurable policy (default: no retry — preserves current behavior) | ⬜ | 4 | 5 | 4 | 1.13 📋 | `Onchain.RPC` |
| 59 | `Onchain.RPC.call/3` — generic JSON-RPC passthrough for methods not covered by named wrappers (`eth_getStorageAt`, `debug_traceTransaction`, `trace_call`, `eth_feeHistory`, …) | ✅ | 2 | 7 | 8 | 3.75 🎯 | `Onchain.RPC` |
| 62 | `Onchain.Sleuth` — Compound-style "ship bytecode in `eth_call`" primitive for arbitrary read-only logic against live chain state | ✅ | 3 | 6 | 5 | 1.83 🚀 | `Onchain.Sleuth` |

**Task descriptions:**

**49 — eth_getProof.** Merkle proof retrieval for account + storage slots. Light clients, cross-chain proofs. `Signet.RPC.send_rpc/3` call with parsed hex response.

**51 — Batch RPC.** JSON-RPC 2.0 allows array-batched requests. Currently each `Signet.RPC.send_rpc/3` is a separate HTTP round-trip. For indexers doing N `eth_call`s this is a real latency win. Implemented here because batching is composition over signet's primitive transport.

**52 — Telemetry.** Zero runtime cost when no handler is attached. Standard Elixir lib pattern. Consumers measure RPC latency / error rates without patching signet.

**53 — Fee suggestion.** `Signet.FeeHistory` is a deserializer-only module. Every app reimplements base-fee + priority-fee percentile math. Pure function over the struct.

**54 — Retry/backoff.** Opt-in via keyword policy. Changing `send_rpc` default behavior upstream would be risky (silently changes every consumer); a downstream wrapper is the correct posture per the scope principle.

**59 — Generic RPC passthrough.** Named wrappers cover the common Ethereum JSON-RPC surface, but debug / trace / storage-inspection work regularly needs methods not in the curated list (`eth_getStorageAt` for EIP-1967 slot inspection, `debug_traceTransaction` / `trace_call` for execution tracing, `eth_feeHistory` if Task 53's wrapper hasn't landed, `eth_getProof` if Task 49 hasn't). Discovered 2026-04-22 while verifying an upgradeable-proxy implementation address — had to drop to raw `Req.post!` for `eth_getStorageAt`. Shape: `Onchain.RPC.call(method, params, opts \\ [])` returning `{:ok, result} | {:error, term}`; thin wrapper over `Cartouche.RPC.send_rpc/3`, no decoding (the caller knows what they asked for). Complements but doesn't replace named wrappers — each named wrapper adds value (typespec, docstring, return-type decoding, descripex hints) over the bare passthrough.

---

**Task 62 — `Onchain.Sleuth` (deploy-as-call primitive). ✅ Completed** — see [CHANGELOG.md](CHANGELOG.md#added--sleuth-deploy-as-call-primitive-task-62).

Compound Finance pattern: `eth_call` with `to: nil` and `data: creation_bytecode ++ abi_encoded_constructor_args` — the node executes the constructor in-memory against live chain state and the `eth_call` response is the bytes the constructor would have deployed. The caller ABI-decodes those bytes as the "return value." Lets a single RPC round-trip run arbitrary read-only logic (conditionals, loops, storage reads, derived computation) that Multicall3 can't express because Multicall3 only batches existing view functions.

Complements — does not replace — `Onchain.Multicall` and `onchain_evm` / revm:
- Multicall3: batch N existing view-function calls against live state. Use when the logic already exists on deployed contracts.
- Sleuth (this task): one custom read-only program against live state. Use when you need derived/conditional logic that isn't exposed.
- revm (onchain_evm): simulate many calls locally, trace execution, modify state, run against a fork. Use when network cost matters or you need execution traces.

**Scope.** Ship bytecode in, get decoded values out. Solidity source → bytecode compilation is explicitly out of scope — handled by [onchain_js](../onchain_js/ROADMAP.md) Task 2 (`OnchainJs.Solc.compile/2`) or an external build step (foundry, hardhat). Consumers supply creation bytecode directly.

**Shape (draft, adapt during implementation):**
- `Onchain.Sleuth.query(bytecode, constructor_args, return_type, opts \\ [])` returning `{:ok, decoded_values} | {:error, term}`
- `constructor_args` as `[{type_sig, value}]` (or similar) — encoded via `Onchain.ABI` and appended to bytecode
- `return_type` as an ABI type signature string — decoded via `Onchain.ABI.decode_response/2`
- `opts` supports `:rpc_url`, `:block`, `:timeout` matching the `Onchain.Contract.call/5` conventions
- Bang variant (`query!/4`) following the established pattern (ERC20, Multicall)

**Acceptance:**
- Unit tests for bytecode + constructor-arg concatenation and return decoding (pure functions)
- Integration test against mainnet via `ETHEREUM_API_URL`: a small Sleuth contract that reads something a regular `eth_call` can't easily produce (e.g., aggregate a list of balances with in-contract filtering, or return data conditional on current block state)
- Descripex `api()` annotations on public functions
- CLAUDE.md Module Layout + Portfolio Context updated (the `onchain` row in "Where does this feature go?" should note custom read-only bytecode as an `onchain` concern)
- Reference Compound's Sleuth repo in `@moduledoc` for the design inspiration

---

## Phase 11: hieroglyph 1.0.0 → 1.4.0 adoption advisory

**Status:** ⬜ pending — planted 2026-05-01 by a hieroglyph session surveying downstream impact.

**Context.** `hieroglyph` shipped four minor releases between 2026-04-24 and 2026-05-01: 1.0.0, 1.1.0, 1.2.0, 1.3.0, 1.4.0. onchain consumes hieroglyph **transitively through cartouche** (cartouche pins `{:hieroglyph, "~> 1.0"}`, which already accepts 1.4.0). Full release notes in `../hieroglyph/CHANGELOG.md`; sibling roadmap at `../hieroglyph/ROADMAP.md` (now in maintenance posture). Cartouche has its own adoption advisory in `../cartouche/ROADMAP.md` (Phase 11) covering the codegen path and the `decode_structs: true` audit — onchain doesn't use `decode_structs: true` directly, so the 1.4.0 BREAKING change is not load-bearing here. Two onchain-specific concerns instead.

### Tasks

| # | Task | Status | D | B | U | Eff | Module |
|---|------|--------|---|---|---|-----|--------|
| TBD | Bug-fix audit: re-test onchain flows against silently-fixed hieroglyph behaviors | ⬜ | 3 | 5 | 4 | 1.50 📋 | `Onchain.Log` + `Onchain.ABI` |
| TBD | Optional: extend `Onchain.ABI` wrapper with `decode_call/3` and `decode_error/2` | ⬜ | 2 | 4 | 5 | 2.25 🚀 | `Onchain.ABI` |

### Audit — silent bug-fix windfall (1.0.0–1.2.0)

Hieroglyph fixes that flow into onchain transparently through `Onchain.ABI.encode_call/2` / `Onchain.ABI.decode_response/2`, plus one that does NOT:

- **`:string` decode NUL truncation** (1.2.0) — pre-existing upstream bug since 2018. Any contract returning strings with embedded NUL codepoints silently truncated. Re-run integration tests for ENS resolver text records, ERC-20 `name`/`symbol`, and any custom-error revert paths in `lib/onchain/erc20.ex` (`Cool(uint256,string)` style) on mainnet. If anything decodes differently now, that's the bug fix taking effect.
- **`encode_int/2` overflow guard** (1.1.0) — `int8`/`int16`/etc. were rejecting all valid values. onchain doesn't use small int types in any current public surface (mostly `uint256`), but worth grepping `lib/` for `int<N>` types in case a caller was accidentally avoiding them.
- **Indexed reference-type event params** (1.0.0) — **does NOT auto-apply.** `lib/onchain/log.ex` reimplements event decoding (lines 99–107: `decode_event/2` parses the signature itself, then routes indexed params through manual `ABI.decode("(#{type})", binary)` on line 262 rather than delegating to `ABI.Event.decode_event/4`). The hieroglyph fix lives inside `ABI.Event.decode_event/4` and never runs in the onchain path. Two ways to address: (a) audit `Onchain.Log.decode_event/2`'s indexed-param branch against the spec rule (indexed dynamic types — `string`, `bytes`, `T[]`, tuples — should resolve to a 32-byte topic hash, not a decoded value), or (b) refactor `Onchain.Log.decode_event/2` to delegate to `ABI.Event.decode_event/4` and let hieroglyph handle the spec compliance. Today onchain's `lib/onchain/transfer.ex` only decodes ERC-20/721/1155 transfer events, which use `address` and `uint256` (static value types), so the bug doesn't surface there — but any future event with indexed reference-type params would hit it.
- **`dynamic?/1` crash on `T[0]`** (1.1.0) — niche. Not likely surfaced by current onchain callers.

### Optional adoption — new hieroglyph public APIs

Two new hieroglyph APIs map cleanly onto the `Onchain.ABI` wrapper layer; adopting in onchain gives sibling repos (`onchain_aave`, `onchain_evm`, `onchain_js`, `onchain_tempo`) the new functionality for free without each rewriting integration code:

- `ABI.decode_call/3` (1.1.0) — selector-prefixed calldata decoding (`{:ok, %{function, types, args}}` or `{:error, :calldata_too_short | :selector_mismatch | ...}`). `Onchain.ABI.decode_response/2` is response-payload-only; if any caller hands selector-prefixed calldata (debug paths, mempool-decoded transactions), expose `Onchain.ABI.decode_call/2` as a thin wrapper.
- `ABI.decode_error/2` (1.2.0) — Solidity 0.8.4+ custom-error revert decoding. Useful in `lib/onchain/rpc.ex` revert handling and anywhere a contract returns custom-error revert data. Could land as `Onchain.ABI.decode_error/2`.

`ABI.encode_packed/2` (1.2.0) and `ABI.method_id/1` (1.1.0) are also new but have no obvious onchain consumer today — defer.

### Sibling repos

`onchain_aave` / `onchain_evm` / `onchain_js` / `onchain_tempo` all consume hieroglyph through `Onchain.ABI.*` wrappers (or, for `onchain_js`/`onchain_tempo`, not at all). Bug fixes flow through transparently; new-API adoption depends on this task. **No per-sibling task needed** unless their integration tests surface a regression — which would be a sign that the silent bug-fix windfall above had been miscompiling production data, in which case the relevant sibling can plant its own follow-up.

**Acceptance:** integration tests re-run with hieroglyph 1.4.0 to surface any string/int decoding deltas; `lib/onchain/log.ex` indexed-param branch audited against the spec rule fixed in hieroglyph 1.0.0 (or refactored to delegate); `Onchain.ABI` wrapper extensions added or formally declined.

**Docs:** ROADMAP (this section); CHANGELOG `[Unreleased]` if `Onchain.ABI` wrapper grows or `Onchain.Log.decode_event/2` is refactored.

---

## EIP Tracking

Triage rubric: see `../signet/ROADMAP.md` "EIP triage rubric". Summary — Core tx-type EIPs go to signet; Interface (JSON-RPC) EIPs and ERC standards go to onchain or siblings.

**Policy:** EIP enters the roadmap only when a consumer project needs it. Don't build speculatively.

### Active

| EIP | Name | Home | Status | Notes |
|---|---|---|---|---|
| 8004 | Trustless Agents — Identity / Reputation / Validation registries | **`onchain_agents`** (new sibling, planned) | ⬜ Planned | Pushed by Tito for agent-economy work. Descripex manifest bridge per `~/.claude/includes/agent-economy.md` Tier 3. See `onchain_agents` scope below — kick off when the repo is created |
| 4844 | Blob transactions | signet Phase 10 Task 30 | ⬜ Gated on Phase 0 | L2 rollup consumer support |
| 7702 | Set EOA code (auth-list txs) | signet Phase 10 Task 31 | ⬜ Gated on Phase 0 | Account-abstraction flows |

### Watch (no consumer pressure yet)

Add rows as EIPs surface in consumer conversations. Mark with ⬜ watching; promote to the Active table with a trigger condition when a consumer needs it.

### `onchain_agents` — sibling package scope (planned)

New sibling repo following the portfolio pattern (onchain_aave, onchain_evm, onchain_js, onchain_tempo). Matches the `agent-economy.md` guidance that EIP-8004 registration belongs in an agent-wrapper project, not the base Ethereum library. Initial scope:

- `OnchainAgents.Identity` — read: lookup agent by address; write: register / update agent identity
- `OnchainAgents.Reputation` — read: scores + attestations; write: submit reputation
- `OnchainAgents.Validation` — read: validation records; write: submit validation result
- `OnchainAgents.Manifest` — bridge between `Descripex.Manifest.build/1` output and EIP-8004 registration (matches `agent-economy.md` Tier 3 — "the manifest bridges code to all three registries")

**Create the repo when:** first consumer app needs to register an agent, submit reputation, or validate. Stub `ROADMAP.md` + `CLAUDE.md` at creation using `onchain_aave` as template. Keep base `onchain` dep-minimal for non-agent consumers.

**Acceptance for first milestone:** register an agent, retrieve its identity record, emit a Descripex-based manifest URL, verify a single reputation attestation — smallest end-to-end slice proving the four modules compose correctly.

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
2. **Cartouche as sole Ethereum dep** — RPC, ABI, signing, crypto all in one (transitively pulls in `hieroglyph` for ABI)
3. **Consumers configure RPC URL** — `config :cartouche, ...` or pass URL per-call
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
    erc20.ex                        # reads + writes: balanceOf, allowance, decimals, symbol, totalSupply, approve, transfer
    erc721.ex                       # ERC-721 NFT reads: ownerOf, tokenURI, balanceOf
    erc1155.ex                      # ERC-1155 multi-token reads: balanceOf, balanceOfBatch, uri
    wallet.ex                       # classify (EOA/contract), native ETH balance
    transfer.ex                     # Transfer event parser (ERC-20/721/1155 → structs)
    ens.ex                          # forward + reverse ENS resolution
    subscription.ex                 # real-time eth_subscribe (newHeads, pendingTx, logs)
    subscription/
      parser.ex                     # pure parsing for subscription notification payloads
```
