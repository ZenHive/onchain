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

**Up next:** Code Health backlog — no breaking change pending. v0.5.4 patch is accumulating (Tasks 49, 53, 71, 72) and ready to ship; future Code Health / Phase 10 tasks will follow. Task 48 (`onchain_ws` extraction) closed as won't-fix on 2026-05-02 — see Code Health rationale.

> **Philosophy:** Pure functions first. Consumers call from their own state. No forced state management.
>
> **Doc checklist (every task):** ROADMAP.md ✅ → CHANGELOG.md ✅ → README.md ✅ → CLAUDE.md ✅

### ✅ Recently Completed (6)
| Task | Description | Notes |
|------|-------------|-------|
| 49 | `Onchain.RPC.get_proof/3` (+ bang) wraps `eth_getProof` | Account + storage Merkle proofs for light clients and cross-chain proofs. Validates address (`ensure_hex_address/1`), 32-byte storage keys (new `Helpers.ensure_storage_key/1` re-tagging `ensure_tx_hash/1`), and block tag. Returns atom-keyed map with `balance`/`nonce` decoded to integers and proof byte arrays passed through as 0x hex (caller verifies the Merkle proof). Matches `parse_transaction/1` shape rather than `get_block_by_number`'s raw map; doesn't pre-commit Task 57's unification choice. |
| 72 | `Onchain.ABI.decode_call/3` + `decode_error/2` (+ bang variants) | Thin wrappers over hieroglyph 1.1.0/1.2.0 APIs: selector-prefixed calldata decoding (forwards opts including `decode_structs: true`) and Solidity 0.8.4+ custom-error revert decoding. Same `{:error, {:decode_error, _}}` envelope as `decode_response/2`. |
| 71 | Hieroglyph 1.0.0 → 1.4.0 bug-fix audit | Confirmed no silent-bug-fix windfall surfaces in onchain: `Onchain.Log.decode_event/2`'s indexed-param branch is independently spec-compliant for `string`/`bytes`/all arrays; no `int<N>` callers in `lib/`; integration suite green against hieroglyph 1.4.0. Lock-in tests added for indexed `bytes`, indexed fixed-size array, indexed dynamic array of static elements, and interleaved static/reference indexed params. |
| 53 | `Onchain.Fees.suggest_fees/2` (+ bang) + `Onchain.RPC.fee_history/2` (+ bang) | Pure EIP-1559 fee math over `Cartouche.FeeHistory.t()` (median priority + buffered base fee, defaults: `:percentile_index 0`, `:buffer 1.2` — matches cartouche `v2_gas_parameters`) bundled with the named `eth_feeHistory` wrapper that produces it. Closes the wrapper gap noted in Task 59. |
| 50 | `Onchain.RPC.syncing/1` (+ bang) | Raw passthrough wrapping `eth_syncing`. `{:ok, false}` synced, `{:ok, %{...}}` otherwise. Closes the trivial-RPC surface gap. |
| 58 | `Onchain.ABI.decode_types/2` alias + tuple-sig docs | Alias of `decode_response/2` for non-RPC callers. Tuple-wrap requirement (parens around the type list) documented inline on both names. |

---

## Release Plan

Last shipped: **v0.5.3** (2026-05-02) — Bundled subscription hardening (v0.5.2 task set: 38, 39, 42, 43, 55, 56, 59, 62, 67) + surface-area polish (v0.5.3 task set: 50, 58, 60, 61) under a single tag covering `v0.5.1..HEAD`. v0.5.2 work was committed but never tagged separately — folded into the v0.5.3 tag rather than retroactively labeling.

### Release Discipline

**When to ship:** when every task in a release-plan sub-section is ✅ AND `mix test.json --quiet` / `mix dialyzer.json --quiet` / `mix credo --strict --format json` are clean on touched files. Don't accumulate multiple unshipped release groups — that's how `v0.5.2` ended up rolled into `v0.5.3`.

**Single-tag rule:** if a planned `v0.x.y` was never pushed to origin, fold its work into the next tag rather than retroactively labeling. The CHANGELOG keeps both sections (narrative); only the published tag becomes a mechanical fact.

**Release commit:** bump `mix.exs` `@version`, promote CHANGELOG `[Unreleased]` → `## v0.x.y — <name> (YYYY-MM-DD)`, update ROADMAP "Last shipped" line — all in **one** commit titled `chore(release): v0.x.y`. Tag immediately after, then push branch and tag.

**After every task** — non-negotiable doc updates:

| File | What to update |
|------|----------------|
| `ROADMAP.md` | Mark task ⬜ → ✅ with shipped-date note; move from current-tasks to "Recently Completed" |
| `CHANGELOG.md` | Add entry under `## [Unreleased]` describing what shipped + key decisions |
| `README.md` | Update if module surface, public API, or user-facing behavior changed |
| `CLAUDE.md` | Update Module Layout / Architecture if files moved or conventions changed |

Pre-commit code-review **must verify all four** were checked. Reject reviews where doc updates are missing.

### ✅ v0.5.2 — Subscription hardening (patch, shipped 2026-05-01, bundled into v0.5.3 tag)

### ✅ v0.5.3 — Surface-area polish (patch, shipped 2026-05-02)


### Future (unscheduled)

No breaking change pending after Task 48 was closed as won't-fix (2026-05-02). Open Code Health and Phase 10 tasks will batch into patch (v0.5.4) or minor (v0.6.0) releases as they land.

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
| 36 | Extract shared RPC helpers (DRY: 7 duplicated functions between RPC + Trace) — see [CHANGELOG](CHANGELOG.md#task-36-extract-shared-rpc-helpers) | ✅ | 3 | 6 | 5 | 1.83 🚀 | `Onchain.RPC.Helpers` |
| — | Code review fixes: batch state commit, defensive parsing, array handling, NatSpec | ✅ | — | — | — | — | Multiple |
| 37 | zen_websocket `send_message/2` returns `{:error, :disconnected}` on dead server — resolved upstream in 0.4.1 (R042); see [CHANGELOG](CHANGELOG.md#v051--zen_websocket-04x-compatibility-2026-04-19) | ✅ | 2 | 7 | 6 | 3.25 🎯 | `ZenWebsocket.Client` |
| 38 | Subscription: buffer unknown sub_ids to close subscribe→Agent.update race — see [CHANGELOG](CHANGELOG.md#added--pre-registration-buffer-for-subscription-notifications-task-38) | ✅ | 3 | 4 | 3 | 1.17 📋 | `Onchain.Subscription` |
| 39 | Subscription: `:pending_transactions` integration test — see [CHANGELOG](CHANGELOG.md#added--pending-transactions-integration-test-task-39) | ✅ | 2 | 3 | 3 | 1.50 📋 | `test/onchain/subscription_integration_test.exs` |
| 40 | Switch Credo from `release/1.7` git branch to Hex release `{:credo, "~> 1.7"}` (1.7.18) — see [CHANGELOG](CHANGELOG.md#v050--chain-intelligence-subscriptions-nft-reads) | ✅ | 1 | 4 | 3 | 3.50 🎯 | `mix.exs` |
| 41 | ENS enhancements: CCIP-Read / EIP-3668 off-chain lookups, ENSIP-10 wildcard resolution, full UTS-46 / ENSIP-15 Unicode normalization, multi-coin address resolution (currently ETH-only via `addr(bytes32)`) | ⬜ | 6 | 6 | 5 | 0.92 ⚠️ | `Onchain.ENS` |
| 42 | Subscription: deliver parse errors to handler as `{:parse_error, sub_id, reason}` events — see [CHANGELOG](CHANGELOG.md#v052--subscription-hardening-2026-05-01) | ✅ | 2 | 4 | 3 | 1.75 🚀 | `Onchain.Subscription` |
| 43 | Strip upstream-cascade `@dialyzer {:no_match, ...}` suppressions — see [CHANGELOG](CHANGELOG.md#maintenance--strip-upstream-cascade-dialyzer-suppressions-task-43) | ✅ | 1 | 3 | 3 | 3.00 🎯 | Multiple |
| 44 | Fix CLAUDE.md Module Layout drift (`wallet.ex` + `erc20.ex` bullets) — see [CHANGELOG](CHANGELOG.md#task-44-claudemd-module-layout-drift-fix) | ✅ | 1 | 3 | 4 | 3.50 🎯 | `CLAUDE.md` |
| 45 | Add `Onchain.ERC20.total_supply/2` (+ bang) — see [CHANGELOG](CHANGELOG.md#task-45-onchainerc20total_supply2--bang-variant) | ✅ | 2 | 5 | 6 | 2.75 🎯 | `Onchain.ERC20` |
| 46 | Make `Onchain.Hex.from_integer/1` emit lowercase hex — see [CHANGELOG](CHANGELOG.md#task-46-lowercase-onchainhexfrom_integer1) | ✅ | 1 | 2 | 2 | 2.00 🚀 | `Onchain.Hex` |
| 47 | Hotfix: zen_websocket 0.4.x handler contract (decoded maps replace raw binaries) — see [CHANGELOG](CHANGELOG.md#v051--zen_websocket-04x-compatibility-2026-04-19) | ✅ | 2 | 7 | 8 | 3.75 🎯 | `Onchain.Subscription` |
| 48 | Extract `Onchain.Subscription` into `onchain_ws` package — see won't-fix rationale below | 🔶 Won't fix (2026-05-02) | — | — | — | — | `onchain_ws` (new package) |
| 55 | Harden `Onchain.RPC.Helpers` address/data validation (four silent-corruption paths) — see [CHANGELOG](CHANGELOG.md#changed--rpc-input-hardening-tasks-55-56) | ✅ | 2 | 9 | 8 | 4.25 🎯 | `Onchain.RPC.Helpers` |
| 56 | 🐛 `eth_get_logs/2` silently dropped wrong filter keys — see [CHANGELOG](CHANGELOG.md#changed--rpc-input-hardening-tasks-55-56) | ✅ | 2 | 6 | 7 | 3.25 🎯 | `Onchain.RPC` |
| 57 | Unify RPC return shapes: `get_transaction_by_hash/2` returns decoded atom-keyed struct, `get_block_by_number/2` returns raw string-keyed hex map — pick one | ⬜ | 4 | 6 | 6 | 1.50 🚀 | `Onchain.RPC` |
| 58 | `Onchain.ABI.decode_types/2` + bang variant alias of `decode_response/2`; tuple-sig footgun documented — see [CHANGELOG](CHANGELOG.md#added--onchainabidecode_types2-alias-task-58) | ✅ | 1 | 3 | 4 | 3.50 🎯 | `Onchain.ABI` |
| 60 | `eth_get_logs/2` accepts canonical camelCase string-key aliases — see [CHANGELOG](CHANGELOG.md#changed--eth_get_logs2-filter-ergonomics-tasks-60-61) | ✅ | 2 | 4 | 4 | 2.00 🚀 | `Onchain.RPC` |
| 61 | `eth_get_logs/2` accepts `:block_hash` (EIP-1474) — see [CHANGELOG](CHANGELOG.md#changed--eth_get_logs2-filter-ergonomics-tasks-60-61) | ✅ | 2 | 3 | 4 | 1.75 🚀 | `Onchain.RPC` |
| 63 | `defrpc` macro — codegen named JSON-RPC wrappers from declarative specs (refactor of existing 11 `Onchain.RPC.*` wrappers); follows Phoenix.Router shape, gated by Nimble.Options schema | ⬜ | 4 | 6 | 5 | 1.38 📋 | `Onchain.RPC` |
| 64 | Vendor `openrpc.json` from `ethereum/execution-apis` + emit `Onchain.RPC.Specs` lookup that feeds `defrpc` (93 methods across `eth_*`/`engine_*`/`debug_*`/`txpool_*`/`net_*`/`testing_*`) — gated on Task 63 | ⬜ | 4 | 6 | 5 | 1.38 📋 | `Onchain.RPC.Specs` (new) |
| 65 | Differential test harness: same RPC method via `Onchain.RPC` vs reference impl (signet first, then Web3.py / viem if needed) — catches protocol-level mistakes unit tests miss | ⬜ | 6 | 5 | 3 | 0.67 ⚠️ | `test/onchain/differential/` |
| 66 | Tree-sitter scrape of Erigon Go source for `trace_*` / `ots_*` method enumeration (~30 methods OpenRPC doesn't cover) — gated on Task 64 + actual consumer demand | ⬜ | 5 | 4 | 3 | 0.70 ⚠️ | dev-only `Mix.Task` |
| 67 | Migrate `:signet` → `:cartouche` dep (renames every `Signet.*` reference, swaps in `{:cartouche, "~> 0.1"}`) — see [CHANGELOG](CHANGELOG.md#changed--signet--cartouche-dep-migration-task-67) | ✅ | 4 | 7 | 8 | 1.88 🚀 | Multiple |
| 68 | Mine `defi-skills:intent-to-transaction` action surface for `onchain` coverage gaps | ⬜ | 3 | 8 | 7 | 2.50 🎯 | (cross-cutting research) |
| 70 | Harden `Onchain.Subscription.lookup_or_buffer/3` against unsolicited sub_id keys: `pending` map has per-key cap of 100 but unbounded distinct-keys count. Server emitting notifications for never-`subscribe`-d sub_ids grows key set until connection closes (per-connection Agent dies with the conn, so blast radius is bounded — but worth fixing). Buffer only sub_ids in an in-flight subscribe state, or add a global key cap with eviction. | ⬜ | 3 | 4 | 3 | 1.17 📋 | `Onchain.Subscription` |
| 73 | Surface `data` field on `eth_call` revert errors so consumers can feed it to `Onchain.ABI.decode_error/2`. Currently `do_rpc/3` returns `{:error, {:rpc_error, %{code, message}}}` and drops the revert payload that nodes attach for execution-reverted calls (`code: 3`). Discovered 2026-05-02 during Task 72 — without this passthrough, the new `decode_error/2` wrapper has no straightforward consumer. | ⬜ | 3 | 5 | 5 | 1.67 🚀 | `Onchain.RPC` |

**Task 57 — Unify `get_block_*` / `get_transaction_*` return shapes.**

`get_transaction_by_hash/2` returns an atom-keyed struct with integers decoded (`%{value: 0, block_number: 24933341, …}`). `get_block_by_number/2` returns a raw string-keyed map with hex-string values (`%{"baseFeePerGas" => "0x7e479377", …}`). Callers have to remember which returns which, and the second shape forces manual `String.to_integer/2`.

Pick one: either both decode to atom-keyed structs (`Onchain.Block.t()`, `Onchain.Transaction.t()`), or both surface raw string-keyed maps (caller-decodes). Leaning toward decoded structs — matches the Phase 8 transfer-parser direction and the `Onchain.Transfer` pattern.

Breaking change for consumers of `get_block_by_number/2`; justify with a minor-version bump and a brief migration note in CHANGELOG.

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

**Task 48 — `onchain_ws` extraction. 🔶 Won't fix (2026-05-02).**

Closed without implementation. Rationale grounded in concrete data, not architectural-hygiene speculation:

- **Transitive-dep cost is small.** `zen_websocket ~> 0.4.2` adds `gun` + `cowlib` + `certifi` over what `onchain` already pulls. All pure Erlang, no NIFs, no native compile time, mature Erlang/OTP ecosystem libraries.
- **Zero consumer pressure.** All four sibling repos (`onchain_aave`, `onchain_evm`, `onchain_js`, `onchain_tempo`) are HTTP-only today — none reference `Onchain.Subscription` or `ZenWebsocket` in `lib/` or `test/`. The "HTTP-only consumers suffer" framing was hypothetical; the consumers exist and haven't complained.
- **Portfolio-split precedents don't transfer.** `onchain_aave` = protocol-specific. `onchain_evm` = Rust NIFs (different runtime). `onchain_js` = Zig NIFs (different runtime). `onchain_tempo` = different chain. Subscription is **same chain, same RPC method namespace, just WebSocket transport** — none of those splitting axes apply. Mainstream Elixir libs (Tesla, Finch, Phoenix) keep transports together.
- **Boundary isn't clean.** `Onchain.Subscription.Parser` imports `Onchain.RPC.Helpers` (`parse_log/1`, `parse_hex_integer/1`, `parse_address/1`) and calls `Onchain.Hex.valid?/1`. Extraction means either a path-dep on `onchain` (consumers pull both anyway, defeating the stated benefit) or extracting the helpers into a third tier (premature without a second consumer).
- **Acceptance criteria signaled the answer.** Original Task 48 leaned toward keeping the module name as `Onchain.Subscription` "since consumers don't need to care about the split." If consumers don't need to care, the split isn't earning its weight.

**Revisit triggers** — re-open this task only if **one** of:
1. `zen_websocket` adds a NIF or other native dependency (concrete cost, not theoretical),
2. A real consumer surfaces a packaging constraint that the current arrangement blocks, or
3. Elixir tooling makes optional-dep / conditional-compile patterns materially cheaper than they are today.

Until then, `Onchain.Subscription` + `.Parser` stay in `onchain`.

---

## Phase 10: RPC Composition Layer

**Motivation:** Per the scope split with cartouche (see `../signet/ROADMAP.md` "Scope principle" — sibling design-discussion repo retains its historical name), onchain is home for everything buildable on top of `Cartouche.*` public surface. This phase collects RPC method wrappers, observability facades, and helpers over cartouche structs that would otherwise have been upstream-PR candidates but correctly belong here. Each task is small; not urgent individually. Batch as needed — no consumer blocking.

| # | Task | Status | D | B | U | Eff | Module |
|---|------|--------|---|---|---|-----|--------|
| 49 | `Onchain.RPC.get_proof/3` (+ bang) wraps `eth_getProof` — see [CHANGELOG](CHANGELOG.md#added--onchainrpcget_proof3-task-49) | ✅ | 2 | 4 | 4 | 2.00 🚀 | `Onchain.RPC` |
| 50 | `Onchain.RPC.syncing/1` (+ bang) wraps `eth_syncing` — see [CHANGELOG](CHANGELOG.md#added--onchainrpcsyncing1-task-50) | ✅ | 1 | 2 | 3 | 2.50 🎯 | `Onchain.RPC` |
| 51 | `Onchain.RPC.batch/2` — JSON-RPC 2.0 array-batched requests (single round-trip over N method calls) | ⬜ | 4 | 6 | 5 | 1.38 📋 | `Onchain.RPC` |
| 52 | Telemetry events around `Onchain.RPC` request path (`[:onchain, :rpc, :request]`) | ⬜ | 3 | 5 | 5 | 1.67 🚀 | `Onchain.RPC` |
| 53 | `Onchain.Fees.suggest_fees/2` — take `Cartouche.FeeHistory.t()` + percentile, return `{base_fee, max_priority, max_fee}` recommendation. Bundled with paired `Onchain.RPC.fee_history/2` wrapper — see [CHANGELOG](CHANGELOG.md#added--onchainfees--onchainrpcfee_history-task-53) | ✅ | 2 | 5 | 6 | 2.75 🎯 | `Onchain.Fees` (new) |
| 54 | Opt-in retry/backoff wrapper over `Signet.RPC.send_rpc/3` with configurable policy (default: no retry — preserves current behavior) | ⬜ | 4 | 5 | 4 | 1.13 📋 | `Onchain.RPC` |
| 59 | `Onchain.RPC.call/3` — generic JSON-RPC passthrough — see [CHANGELOG](CHANGELOG.md#added--generic-json-rpc-passthrough-task-59) | ✅ | 2 | 7 | 8 | 3.75 🎯 | `Onchain.RPC` |
| 62 | `Onchain.Sleuth` — Compound-style "ship bytecode in `eth_call`" primitive — see [CHANGELOG](CHANGELOG.md#added--sleuth-deploy-as-call-primitive-task-62) | ✅ | 3 | 6 | 5 | 1.83 🚀 | `Onchain.Sleuth` |

**Task descriptions:**

**49 — eth_getProof.** ✅ Shipped 2026-05-02. Merkle proof retrieval for account + storage slots; light clients, cross-chain proofs. Atom-keyed decoded response (balance/nonce as integers; proof bytes as 0x hex).

**51 — Batch RPC.** JSON-RPC 2.0 allows array-batched requests. Currently each `Signet.RPC.send_rpc/3` is a separate HTTP round-trip. For indexers doing N `eth_call`s this is a real latency win. Implemented here because batching is composition over signet's primitive transport.

**52 — Telemetry.** Zero runtime cost when no handler is attached. Standard Elixir lib pattern. Consumers measure RPC latency / error rates without patching signet.

**53 — Fee suggestion.** ✅ Shipped 2026-05-02. `Cartouche.FeeHistory` is a deserializer-only module. Every app reimplements base-fee + priority-fee percentile math. Pure function over the struct, bundled with paired `Onchain.RPC.fee_history/2` named wrapper (closes the gap noted in Task 59).

**54 — Retry/backoff.** Opt-in via keyword policy. Changing `send_rpc` default behavior upstream would be risky (silently changes every consumer); a downstream wrapper is the correct posture per the scope principle.

---

## Phase 11: hieroglyph 1.0.0 → 1.4.0 adoption advisory ✅

**Status:** ✅ complete (2026-05-02) — both tasks landed under v0.5.4 (unreleased). Audit found no silent-bug-fix windfall surfaces in onchain. Discovered Task 73 (RPC revert-data passthrough) added to Code Health as the natural follow-on for `decode_error/2` consumers.

**Context.** `hieroglyph` shipped four minor releases between 2026-04-24 and 2026-05-01: 1.0.0, 1.1.0, 1.2.0, 1.3.0, 1.4.0. onchain consumes hieroglyph **transitively through cartouche** (cartouche pins `{:hieroglyph, "~> 1.0"}`, which already accepts 1.4.0). Full release notes in `../hieroglyph/CHANGELOG.md`; sibling roadmap at `../hieroglyph/ROADMAP.md` (now in maintenance posture). Cartouche has its own adoption advisory in `../cartouche/ROADMAP.md` (Phase 11) covering the codegen path and the `decode_structs: true` audit — onchain doesn't use `decode_structs: true` directly, so the 1.4.0 BREAKING change is not load-bearing here. Two onchain-specific concerns instead.

### Tasks

| # | Task | Status | D | B | U | Eff | Module |
|---|------|--------|---|---|---|-----|--------|
| 71 | Bug-fix audit: re-test onchain flows against silently-fixed hieroglyph behaviors — see [CHANGELOG](CHANGELOG.md) | ✅ (2026-05-02) | 3 | 5 | 4 | 1.50 📋 | `Onchain.Log` + `Onchain.ABI` |
| 72 | Extend `Onchain.ABI` wrapper with `decode_call/3` and `decode_error/2` — see [CHANGELOG](CHANGELOG.md) | ✅ (2026-05-02) | 2 | 4 | 5 | 2.25 🚀 | `Onchain.ABI` |

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
    abi.ex                          # encode_call/2, decode_response/2, decode_types/2, decode_call/3, decode_error/2
    decimal.ex                      # to_decimal/2, to_basis_points/1, div_pow10/2
    fees.ex                         # suggest_fees/2 — EIP-1559 fee recommendation over Cartouche.FeeHistory.t()
    block.ex                        # get_by_number, find_by_timestamp (binary search)
    contract.ex                     # generic call/4 (encode → eth_call → decode)
    rpc.ex                          # eth_call, eth_getLogs, get_transaction_receipt, fee_history, etc.
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
