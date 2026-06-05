# Changelog

Completed roadmap tasks.

---

## [Unreleased]

### Added — `Onchain.RPC.batch/2` (Task 51)

- **`Onchain.RPC.batch/2`** — JSON-RPC 2.0 array batching: send many `{method, params}` calls in one HTTP POST and return raw decoded results in request order (reorders out-of-order node responses by `id`). Empty list returns `{:ok, []}`; first per-item JSON-RPC error halts with `{:rpc_error, map}` (revert `:data` hex enrichment matches single-call path). Uses `Cartouche.RPC.get_body/3` for request bodies and the same `:rpc_url`/`:timeout` opts as other RPC helpers.
- **Tests:** `test/onchain/rpc_batch_test.exs` stubs `Application.get_env(:cartouche, :client)` to assert batch payload shape, response reordering, and error normalization.

### Fixed — dialyzer ~30 GB → ~0.9 GB peak RSS via cartouche 0.2.2 (Task 75)

- **`cartouche` 0.2.1 → 0.2.2** (pin `~> 0.2.1` → `~> 0.2.2`). 0.2.2 fixes a dialyzer memory bomb that originated in cartouche, not onchain: `Cartouche.Assembly.compile/1` had seven fixed-arity tuple heads (`{op,a}` … `{op,a,b,c,d,e,f,g}`), each guarded by a large opcode atom-union — a 7-shape `tuple_set` product type whose success-typing fixpoint under `compile/1`'s self-recursion exploded to ~30 GB peak RSS on OTP 29 (cartouche Task 103). 0.2.2 collapses them into one `def compile(op) when is_tuple(op) and tuple_size(op) >= 2` clause. **A cold `mix dialyzer.json` build drops from ~30 GB to 0.94 GB peak RSS** (measured on development, `total: 0`, `warnings: []`). This was the real cause of the 2026-06-04 double host-OOM — four concurrent reviewer dialyzers under `concurrency_cap=4`. No onchain-side PLT-path change, seeding, or serialization lock was needed; the earlier serialization-lock PR (#4) was closed unmerged once measurement falsified the "irreducible 30 GB" premise.

### Bumped — dependency refresh + decimal 2→3

- **`decimal` 2.4.1 → 3.1.1** (major; pin `~> 2.0` → `~> 3.1.1`). 3.0 is a CVE-2026-32686 security-hardening release: it caps `Decimal.parse/1` & `Decimal.cast/1` at 34 significant digits / exponent magnitude 6_144 and shifts `Decimal.Context` defaults to decimal128 (precision 28 → 34). No function signatures changed. Verified safe for Ethereum amounts: `Decimal.new/1` on a 78-digit uint256-max constructs exactly (integer path bypasses the parse digit-limit); `Onchain.Decimal.{to_decimal,div_pow10,to_basis_points}` all return correct values; full offline suite green (508/508). The 2.x pin was a hard blocker until this bump — see cartouche note below.
- **`cartouche` 0.2.0 → 0.2.1** (pin `~> 0.2.0` → `~> 0.2.1`). 0.2.1 moved its own `decimal` requirement to `~> 3.1`, which is what unblocked the decimal major bump (and transitively `doctor`).
- **`doctor` 0.22.0 → 0.23.0** (dev/test; pin `~> 0.22.0` → `~> 0.23.0`). Requires `decimal ~> 3.1`; landed in lockstep with the decimal bump.
- **`reach` 2.3.3 → 2.7.1** (dev/test; pin `~> 2.2` → `~> 2.7.1`) — pulled **`ex_ast` 0.11.2 → 0.12.0** (`~> 0.11.0` → `~> 0.12.0`) since reach ≥ 2.3.4 requires `ex_ast ~> 0.12`.
- **`descripex` 0.6.0 → 0.7.0** (pin `~> 0.6.0` → `~> 0.7.0`) and **`ex_unit_json` 0.4.3 → 0.5.0** (dev/test; pin `~> 0.4.3` → `~> 0.5.0`).
- All `mix.exs` constraints pinned to the resolved versions; `mix hex.outdated` reports zero updatable deps.

### Changed — RPC execution-revert `data` for `decode_error/2` (Task 73)

- **`Onchain.RPC.Helpers.do_rpc/3`** — when cartouche returns an RPC error map that includes execution-revert bytes as `:revert`, the map is enriched with `:data` as a lowercase `0x` hex string (via `Onchain.Hex.encode/1`) unless `:data` is already present. Callers can pass `data` into `Onchain.ABI.decode_error/2` without manual encoding. Documented on `Onchain.RPC`, `Onchain.Contract`, and README.
- **`Onchain.RPC.Helpers.maybe_put_revert_data_hex/1`** — `@doc false` helper applying the enrichment; covered by unit tests.

### Documentation — Task 68 (defi-skills mining)

- Enumerated the `defi-skills` CLI action surface (`defi-skills actions --json`) and mapped it to **onchain** scope versus sibling repos. Mainnet lists 53 actions across twelve protocol groups; Arbitrum samples smaller coverage (25 actions, six groups). Added **Proposed additions from defi-skills mining** to `ROADMAP.md` with three scored proposals (ERC-721 writes, WETH helpers, allowance-gap pure helpers) plus cross-references to existing Tasks 51, 57, and 73. No library code changes.

## v0.6.0 — RPC block decode unification (2026-05-09)

### Changed — `Onchain.RPC.get_block_by_number/2` decoded shape (Task 57, **breaking**)

- **`get_block_by_number/2` + `!`** — responses from `eth_getBlockByNumber` are decoded like `get_transaction_by_hash/2`: **atom keys** (`:number`, `:timestamp`, `:transactions`, …), quantity fields as integers, `miner` checksummed, hashes/bloom/roots/`extra_data`/PoW header `nonce` left as 0x hex. **`transactions`** remains a list of tx hashes when `full_transactions` is `false` (current default); if the node returns full tx objects, each entry is passed through `parse_transaction_map/1`.
- **`Onchain.RPC.Helpers`** — `parse_block_response/1` and `parse_transaction_map/1` (`@doc false`) centralize decoding; `Onchain.RPC` delegates via existing `import`.
- **`Onchain.Block.get_by_number/2`** — builds its summary from the decoded RPC map; `{:ok, nil}` from RPC becomes `{:error, :block_not_found}` (previously would have crashed in the old raw-map parser). Pending blocks (`number: nil`) still surface as `{:error, :pending_block}`.
- **Migration:** replace string keys and hex quantities — e.g. `block["number"]` → `block.number`, `String.to_integer(..., 16)` no longer needed for standard quantities.

## v0.5.4 — Cartouche 0.2 + ABI revert decoding + fee history (2026-05-07)

### Bumped — cartouche 0.2.0 + ex_ast 0.10.1

- **`cartouche` 0.1.2 → 0.2.0** (loosened `mix.exs` pin `~> 0.1.2` → `~> 0.2.0`). 0.x minor under hex semver = breaking, but onchain's consumed surface is unaffected: `Cartouche.Transaction.V2` struct shape is byte-identical (12 fields, same types — verified at `cartouche/lib/cartouche/transaction.ex:233-266`); `Cartouche.{FeeHistory, Hash, Hex, RPC.send_rpc, Signer.{Curvy, sign_direct}}` callsites compile + test clean. The 0.2.0 changes are mostly additive and internal to cartouche: new `Cartouche.Transaction.V3` (EIP-4844 blob) and `V4` (EIP-7702 set-code authorization) typed transactions, new `Cartouche.Transaction.Call` struct that replaces V2-masquerading-as-Call for `eth_call` shapes (onchain doesn't use cartouche-generated bindings, so no callsite collapse), and `Cartouche.RPC.send_rpc/3` now returns `{:error, {:invalid_params, reason}}` instead of raising on non-encodable params (forward-compatible widening of the error union). Full test suite green (686/686 including integration), credo --strict clean, doctor 100%, dialyzer 0 warnings.
- **`ex_ast` 0.8.1 → 0.10.1** (loosened `mix.exs` pin `~> 0.8.1` → `~> 0.10.1`, dev/test only). Brings in 0.4+ ellipsis (`...`) patterns, syntax-aware `mix ex_ast.diff`, and the programmatic `ExAST.Patcher` / `ExAST.diff` APIs. No `lib/` callsites; affects only the `mix ex_ast.search`/`replace` workflows.
- **`ex_dna` 1.4.3 → 1.5.1** and **`jason` 1.4.4 → 1.4.5** (lock-only, both within existing `mix.exs` constraints). Patch-level refreshes; no behavioral change.
- **Out of scope:** wrapping `Cartouche.Transaction.V3`/`V4` in `Onchain.Signer` (would be a future ROADMAP task once a consumer needs blob or 7702 set-code auth).

### Added — `Onchain.RPC.get_proof/3` (Task 49)

- **`Onchain.RPC.get_proof/3` + `get_proof!/3`** — named wrapper around `eth_getProof`. Retrieves the Merkle proof for an account (account state + accountProof) plus per-storage-slot proofs (storageProof) for any caller-supplied list of 32-byte storage keys. Used by light clients verifying Ethereum state without trusting an RPC node, and by cross-chain bridges proving on-chain facts to other chains. Closes the last "trivial-RPC surface gap" in the same shape as Tasks 50/53/59.
- **Validators:** `ensure_hex_address/1` for the address; new `validate_storage_keys/1` (private in `rpc.ex`) walks the list calling `Helpers.ensure_storage_key/1` per element with `Enum.reduce_while`, returning `{:ok, [normalized]}` or the first `{:error, {:invalid_storage_key, input}}`; `normalize_block/1` for the block tag. Empty `storage_keys` list is valid (account-only proof). Non-list `storage_keys` returns `{:error, {:invalid_storage_keys, input}}`. `:block` lives in opts (default `"latest"`).
- **Return shape:** atom-keyed map produced by a private `parse_proof/1` mirroring `parse_transaction/1`. `balance` and `nonce` decode to integers via `parse_hex_integer/1`; `address` returns checksummed via `parse_address/1`; `code_hash`, `storage_hash`, and the proof byte arrays pass through as raw 0x-hex strings (callers verifying the proof want them byte-shaped, not decoded). Each `storage_proof` entry is also atom-keyed: `%{key, value, proof}`. Storage `value` is **not** decoded — slots can hold anything (addresses, hashes, packed integers); the caller knows the schema.
- **New helper in `Onchain.RPC.Helpers`:** `ensure_storage_key/1` — delegates to `ensure_tx_hash/1` (same 32-byte shape) but re-tags the error as `{:invalid_storage_key, input}`. Reusing `ensure_tx_hash` directly would lie at the boundary, tagging storage-slot errors as "tx hash" errors; the thin re-tag wrapper keeps the boundary honest without duplicating validation code.
- **Aligned with Task 57** — `get_block_by_number/2` now returns the same decoded-atom-keyed convention as this proof map and `get_transaction_by_hash/2` (v0.6.0).
- **Coverage:** `Onchain.RPC` 91.84% → 92.18%; `Onchain.RPC.Helpers` → 94.12%. Both above the 80% standard tier.

### Added — `Onchain.ABI.decode_call/3` + `decode_error/2` (Task 72)

- **`Onchain.ABI.decode_call/3` + `decode_call!/3`** — thin wrappers over hieroglyph 1.1.0's `ABI.decode_call/3`. Decodes selector-prefixed calldata to function args after verifying the leading 4-byte selector matches `signature_or_selector`. Forwards `opts` to hieroglyph (e.g. `decode_structs: true` for a named-field map instead of a positional list). Same `{:error, {:decode_error, reason}}` envelope as `decode_response/2`; reason is one of `:calldata_too_short`, `:selector_mismatch`, `:no_function_name`, `{:invalid_hex, _}`, or upstream exception message string. Bang variant raises `Cartouche.Hex.InvalidHex` on bad hex and `MatchError` on selector mismatch / malformed payload after match.
- **`Onchain.ABI.decode_error/2` + `decode_error!/2`** — thin wrappers over hieroglyph 1.2.0's `ABI.decode_error/2`. Decodes Solidity 0.8.4+ custom-error revert data against a list of candidate error signatures; the first definition whose 4-byte selector matches the prefix decodes the args. Returns `{:ok, %{error: name | nil, args: list}}` or the standard `{:decode_error, _}` envelope (`:calldata_too_short`, `:no_match`, `{:invalid_hex, _}`, exception string). Sibling repos consuming hieroglyph through `Onchain.ABI.*` (`onchain_aave`, `onchain_evm`, `onchain_js`, `onchain_tempo`) get the new functionality for free without rewriting their integration code.
- **No public API change to existing functions** — `encode_call/2`, `decode_response/2`, `decode_types/2` (and bangs) keep byte-identical behavior. Purely additive.
- **Follow-on Task 73** (RPC revert `data` passthrough) shipped under `[Unreleased]` — see Changed section above.

### Audit — Hieroglyph 1.0.0 → 1.4.0 silent bug-fix exposure (Task 71)

- **Re-tested onchain flows against hieroglyph 1.4.0** (transitively via cartouche, already pinned in `mix.lock`). All non-WebSocket integration tests green; the 5 failing subscription-integration tests are pre-existing and depend on `ETHEREUM_WS_URL`, unrelated to hieroglyph.
- **No silent bug-fix windfall surfaces in onchain.** The four upstream fixes between 1.0.0 and 1.4.0 either don't apply or were already correct in onchain code:
  - **Indexed reference-type event params (1.0.0).** `Onchain.Log.decode_event/2` reimplements event decoding rather than delegating to `ABI.Event.decode_event/4`, so the upstream fix never had to flow through. Audited the `decode_indexed_param/2` + `dynamic_indexed_type?/1` branch (`lib/onchain/log.ex:241–274`) against the spec rule (indexed `string`, `bytes`, all arrays should resolve to a 32-byte topic hash, not a decoded value) — independently spec-compliant. Tuple-typed params remain unsupported by the parser (already documented in the moduledoc § Limitations). All ERC-20/721/1155 Transfer flows use only `address` + `uint256` (static value types), so the upstream bug never surfaced regardless. Lock-in tests added: indexed `bytes`, indexed fixed-size `uint256[3]`, indexed dynamic `bytes32[]`, and an interleaved static + reference-indexed case.
  - **`encode_int/2` small-bit-width overflow guard (1.1.0).** Grep confirms zero callers use signed `int8`..`int248` types in `lib/`. Not load-bearing.
  - **`:string` decode NUL truncation (1.2.0).** Pre-existing upstream bug since 2018. ENS text records, ERC-20 `name`/`symbol` reads, and any custom-error revert paths re-tested against mainnet via `ETHEREUM_API_URL` — every relevant integration test passes; no decoded-output deltas observed.
  - **`dynamic?/1` crash on `T[0]` (1.1.0).** Niche zero-length fixed-array case. No surfacing in onchain code.
- **Conclusion: no behavioral change shipped.** This entry exists so future readers can verify the audit was performed without re-running it. Companion advisory in `../cartouche/ROADMAP.md` Phase 11 covers the cartouche-side audit (codegen path, `decode_structs: true`).

### Added — `Onchain.Fees` + `Onchain.RPC.fee_history` (Task 53)

- **`Onchain.Fees.suggest_fees/2` + `suggest_fees!/2`** — pure EIP-1559 fee recommendation over `Cartouche.FeeHistory.t()`. Returns `{base_fee, max_priority, max_fee}` in wei. `base_fee` is `List.last(history.base_fee_per_gas)` — the `eth_feeHistory` array runs oldest-to-newest with the projected next-block fee at the LAST index per spec; `max_priority` is the median of per-block priority fees at the requested column; `max_fee = ceil(base_fee × buffer) + max_priority`. Opts: `:percentile_index` (default `0`, must match the column index of the percentile the caller passed to `eth_feeHistory`'s `reward_percentiles`); `:buffer` (default `1.2` for parity with cartouche's `v2_gas_parameters` — pass `2.0` for the EIP-1559 reference recommendation that buys ~12-block headroom). No RPC, no I/O — caller fetches the struct and calls in.
- **`Onchain.RPC.fee_history/2` + `fee_history!/2`** — named `eth_feeHistory` wrapper returning the deserialized `Cartouche.FeeHistory` struct. Closes the wrapper gap noted in Task 59 ("`eth_feeHistory` if Task 53's wrapper hasn't landed"). Validates `block_count` is in `1..1024` (EIP-1474 cap), `:reward_percentiles` is a non-empty monotonically-non-decreasing list of integers in `0..100`, and routes `:newest_block` through the existing block-tag normalizer. Errors short-circuit before RPC dispatch with `{:invalid_block_count, _}` / `{:invalid_reward_percentiles, _}` / `{:invalid_block, _}`.
- **Two new private validators in `Onchain.RPC.Helpers`** — `ensure_block_count/1` (1..1024, encoded as lowercase 0x hex via `Onchain.Hex.from_integer/1`) and `ensure_reward_percentiles/1` (range + monotonic check). Mirror the existing `ensure_*` family — single-shape, single-error tag.
- **Why bundle:** Task 53 specifies the math, Task 59 reserved the named-wrapper namespace; shipping them together gives consumers an end-to-end fee story (`fee_history(20) → suggest_fees(history) → {base, prio, max}`) without a downstream code change once the wrapper lands. Purely additive — no breaking changes; v0.5.4 patch tag candidate.

---

## v0.5.3 — Surface-area polish (2026-05-02)

### Added — `Onchain.ABI.decode_types/2` alias (Task 58)

- **`Onchain.ABI.decode_types/2` + `decode_types!/2`** — thin aliases of `decode_response/2` and `decode_response!/2`. Same return shape, same error tags, same upstream behavior; the alias exists so callers decoding non-RPC inputs (mempool calldata, custom ABI payloads) have a name that doesn't suggest "RPC response" semantics. Both names are supported indefinitely.
- **Tuple-sig footgun documented inline.** `decode_response/2` and `decode_types/2` `@doc` strings now explicitly state that the type signature MUST be wrapped in parentheses (`"(uint256)"`, not `"uint256"`); bare comma-separated types raise an unhelpful upstream error. The moduledoc § "Type Signatures" was tightened with the same warning and a one-liner on when to pick `decode_response` vs `decode_types`.

### Added — `Onchain.RPC.syncing/1` (Task 50)

- **`Onchain.RPC.syncing/1` + `syncing!/1`** — wraps `eth_syncing`. Returns `{:ok, false}` when the node is fully synced, otherwise `{:ok, %{...}}` with raw hex-encoded sync-status fields (`startingBlock`, `currentBlock`, `highestBlock`, plus optional snap-sync fields whose shape varies per client). No decoding — the caller owns interpretation. Connection-failure path returns `{:error, {:rpc_error, _}}` like every other named wrapper. Closes the trivial-RPC surface gap.

### Changed — `eth_get_logs/2` filter ergonomics (Tasks 60, 61)

- **`Onchain.RPC.eth_get_logs/2` accepts canonical JSON-RPC camelCase string keys as aliases** for the atom keys: `"fromBlock"` → `:from_block`, `"toBlock"` → `:to_block`, `"address"` → `:address`, `"topics"` → `:topics`, `"blockHash"` → `:block_hash`. Non-canonical string keys (e.g. `"from_block"`, `"foo"`) still fail the strict whitelist with `{:error, {:invalid_filter_key, key}}` per Task 56. When both an atom and its camelCase alias are present, the atom wins silently — exotic case, not worth a separate error tag. Closes the post-Task-56 ergonomics follow-up: callers passing a JSON-RPC-style filter map (because they're forwarding a request from elsewhere) no longer have to translate keys at the boundary.
- **`Onchain.RPC.eth_get_logs/2` supports `:block_hash` filtering per EIP-1474.** New `:block_hash` atom key (and `"blockHash"` string alias) accepts a 32-byte 0x-prefixed hex hash; validated via the same `ensure_tx_hash/1` shape check (errors as `{:invalid_filter, {:blockHash, value}}`). Per EIP-1474, `:block_hash` is mutually exclusive with `:from_block` / `:to_block` — passing both returns `{:error, {:invalid_filter, {:block_hash_mutually_exclusive, [present_keys]}}}` before any RPC dispatch. The Task 56 strict whitelist gated this previously-rejected key; it now joins `:address`, `:topics`, `:from_block`, `:to_block` as the fifth canonical filter key.

---

## v0.5.2 — Subscription hardening (2026-05-01)

### Added — Pre-registration buffer for subscription notifications (Task 38)

- **Closed the `subscribe → Agent.update` race window in `Onchain.Subscription`.** A notification arriving for a `subscription_id` not yet registered in the per-connection Agent was previously delivered to `dispatch_event(nil, ...)` and silently dropped — `:ok` return, no Logger line. Standard Ethereum nodes order subscribe-response before notifications on the same connection, so the bug was theoretical for compliant servers; for non-conforming endpoints it was a permanently-lost event with no observability. Now: notifications for unregistered sub_ids are buffered per-id and flushed FIFO on registration via `register_and_drain/3`, before `subscribe/3` returns to the caller. Buffer is bounded at 100 entries per sub_id with `Logger.warning` on overflow (oldest dropped). Cross-buffer / post-registration ordering is best-effort — documented in `@moduledoc`.
- **Agent state shape changed** from a flat `%{sub_id => type}` map to `%{registry: %{sub_id => type}, pending: %{sub_id => [result, ...]}}`. Three private-but-`@doc false`-public helpers expose the atomic operations for unit testing: `lookup_or_buffer/3` (buffer-or-dispatch), `register_and_drain/3` (atomic register + FIFO pop), `remove_subscription/2` (cleanup of both registry and pending). All Agent operations on the new state are single-call atomic, removing read-then-write races.
- **`do_subscribe/4` → `do_subscribe/3`** — the helper now takes the `%Subscription{}` struct rather than separate client/agent args so the synchronous flush after registration has access to the connection's handler.
- **Test coverage for `Onchain.Subscription` raised from 51% to 91%.** New unit tests cover buffer behavior (unregistered notifications buffer instead of drop, registry inspection), drain semantics (FIFO order, empty drain, manual flush dispatching through handler), buffer overflow (101 entries → cap to 100 + Logger.warning), `remove_subscription/2` cleanup, and bang-variant error paths. The pre-existing `"silently drops notification for unknown subscription_id"` test was replaced — the silent-drop behavior is no longer correct.

### Added — Pending-transactions integration test (Task 39)

- **`test/onchain/subscription_integration_test.exs` gains a `:pending_transactions` test.** Subscribes to `newPendingTransactions` against `ETHEREUM_WS_URL`, asserts arrival of at least one tx hash within the 30-second timeout, validates the hash is a 32-byte (66-char) `0x`-prefixed string, and unsubscribes cleanly. The blocker — needing a node that broadcasts mempool — was resolved by the in-house full archive node at `blockwatch-one`; mainstream public providers (Alchemy, Infura) don't broadcast pending tx hashes by default. A code comment notes that providers returning full tx objects (e.g., Alchemy's custom variant) would surface as `{:parse_error, sub_id, {:invalid_tx_hash, _}}` rather than crash the suite.
- **Lifecycle test switched to bang variants** (`connect!/1`, `subscribe!/2`, `unsubscribe!/2`) to add coverage for the bang happy paths alongside the existing non-bang assertions.

### Changed — `:signet` → `:cartouche` dep migration (Task 67)

- **`mix.exs` swap** — `{:signet, "~> 1.6"}` replaced with `{:cartouche, "~> 0.1"}`. Transitively, `:hieroglyph 1.0.0` (published-to-hex ABI library) replaces the unpublished `:abi` upstream signet pulled from path/git. After this commit, `mix deps.tree` resolves entirely from hex.pm and contains no `:signet` reference.
- **Internal-only renames.** Every `Signet.*` reference in `lib/`, `test/`, and config moves to its `Cartouche.*` counterpart: `Signet.Hex.*` → `Cartouche.Hex.*`, `Signet.Hash.keccak/1` → `Cartouche.Hash.keccak/1`, `Signet.RPC.send_rpc/3` → `Cartouche.RPC.send_rpc/3`, `Signet.Util.checksum_address/1` → `Cartouche.Hex.checksum_address/1`, `Signet.Transaction.V2` → `Cartouche.Transaction.V2`, `Signet.Signer.*` → `Cartouche.Signer.*`. Internal helper renamed: `Onchain.RPC.Helpers.to_signet_opts/1` → `to_rpc_opts/1` (drops the package name from the doc-private function so it stays accurate across future dep swaps).
- **`Onchain.*` public API is shape-identical** for consumers — same function arities, same return tuples, same error tags. Two narrow surface changes worth noting: (a) `Onchain.Signer.build_transaction/3` and `sign_transaction/3` now return `%Cartouche.Transaction.V2{}` where they previously returned `%Signet.Transaction.V2{}` — pattern matches that name the struct module need updating; (b) bang variants that previously raised `Signet.Hex.HexError` now raise `Cartouche.Hex.InvalidHex` (see migration note below).
- **Migration note for downstream consumers.** Application config keys must move from `config :signet, ...` to `config :cartouche, :ethereum_node, ...`. The per-call `:rpc_url` / `:timeout` opts surface on `Onchain.RPC.*` is unchanged. The exception class change above is documented on `Onchain.Hex` and `Onchain.Address` moduledocs and surfaces from `Onchain.Address.checksum!/1`, `Onchain.Hex.decode!/1`, `Onchain.Hex.to_integer!/1`, and `Onchain.ABI.decode_response!/2` — `assert_raise` callers must update the alias.
- **Bundles with Task 43 (next commit).** Cartouche corrected the `Cartouche.Hex` specs and ships hieroglyph 1.0.0 with the `ABI.decode/2` `no_return` fix. The `@dialyzer {:no_match, :no_return, :no_contracts}` suppressions across every `Onchain.*` module that flows through `ABI.decode_response/2` are stripped in the immediately-following Task 43 commit; both ship in `v0.5.2`.

### Added — Sleuth deploy-as-call primitive (Task 62)

- **`Onchain.Sleuth.query/5` + `query!/5`** — Compound-style "ship bytecode in `eth_call`" primitive for arbitrary read-only logic against live chain state. Caller supplies creation bytecode + constructor tuple-type signature + tuple of constructor values + return tuple-type signature; Sleuth concatenates ABI-encoded constructor args onto the bytecode, sends an `eth_call` with no `to` field via `Onchain.RPC.call/3` (Task 59 passthrough), decodes the constructor's returned bytes via `Onchain.ABI.decode_response/2`. API shape matches `Contract.call/5` (type signature string + values, not paired list) for codebase consistency. Complements `Onchain.Multicall` (batches existing view functions) and `onchain_evm`/revm (local simulation). Integration test validates live USDC balance read against mainnet via `ETHEREUM_API_URL`, comparing Sleuth output against a direct `Contract.call`. Solidity-source → bytecode compilation is out of scope — see [onchain_js](../onchain_js/ROADMAP.md) Task 2 (`OnchainJs.Solc.compile/2`) or external build steps (foundry, hardhat).

### Added — Generic JSON-RPC passthrough (Task 59)

- **`Onchain.RPC.call/3` + `call!/3`** — escape-hatch for any JSON-RPC method not covered by a named wrapper (`eth_getStorageAt`, `debug_traceTransaction`, `trace_call`, `eth_feeHistory`, `eth_getProof`, …). Same opts surface as the named wrappers (`:rpc_url`, `:timeout`), same error shape (`{:error, {:rpc_error, _}}`), no result decoding — caller owns interpretation. Discovered 2026-04-22 while inspecting an EIP-1967 proxy implementation slot, where no wrapper existed and the only escape was raw `Req.post!`. Named wrappers still earn their keep (typespec, decoded return, descripex hints); `call/3` is the bare alternative when none exists. Guards on `is_binary(method)` / `is_list(params)` catch type mistakes with `FunctionClauseError`. Follow-up Task 63 captured for a possible `defrpc` macro that would codegen the named wrappers from declarative specs.

### Changed — RPC input hardening (Tasks 55, 56)

- **`Onchain.RPC.Helpers.ensure_hex_address/1` now rejects four previously silent-coercion / contract-violation paths.** The validator accepts canonical hex (`"0x"` + exactly 40 hex chars, returned lowercased) and the normal 20-byte raw-binary path internal callers pass after `Onchain.Address.validate/1`. All other malformed shapes — 20-byte ASCII strings that start with `"0x"` (the Task 55 collision: previously routed RPC calls to a completely different address), `"0x"` + odd-length bodies (previously silently zero-padded), bare hex without `"0x"`, and wrong-length inputs — now return `{:error, {:invalid_address, input}}`. As a deliberate Task 55 tradeoff, the prefix-first dispatch also loudly rejects the rare 20-byte raw binary whose first two bytes are the ASCII `"0x"` literal; that edge case is valid raw binary data, but rejecting it is safer than silently corrupting typo-strings into different on-chain addresses.
- **`Onchain.RPC.Helpers.ensure_hex_data/1` rejects odd-length hex bodies.** `"0x1"` / `"0xabc"` were previously accepted and surfaced downstream as `{:evm_error, "Odd number of digits"}` in `onchain_evm` — the wrong error class for invalid input shape. Now caught at the Elixir boundary as `{:invalid_data, _}`. Empty calldata `"0x"` remains valid.
- **`Onchain.RPC.eth_get_logs/2` validates filter-map keys against a whitelist** (`:address`, `:topics`, `:from_block`, `:to_block`). Unknown keys — including JSON-RPC-style string keys like `"fromBlock"` / `"toBlock"` — now return `{:error, {:invalid_filter_key, key}}` instead of being silently dropped and returning `{:ok, []}`. Descripex `api()` hints for `eth_get_logs/2` updated to document the canonical filter shape and the new error tag.

Non-breaking for canonical hex callers and the malformed shapes above; the one compatibility tradeoff is the rare 20-byte raw binary whose leading bytes are ASCII `"0x"`, which now fails loudly instead of being silently re-encoded. Two follow-ups captured as Tasks 60 (accept camelCase `"fromBlock"` / `"toBlock"` aliases) and 61 (`:block_hash` filter key per EIP-1474).

### Changed
- **Task 42 — Subscription parse errors delivered to handler.** `Onchain.Subscription` previously logged parse failures at `Logger.debug` and dropped the notification. Dispatch now emits `{:parse_error, sub_id, reason}` to the handler, where `reason` is the tagged tuple from `Onchain.Subscription.Parser.parse_event/2` (`{:invalid_head, _}` | `{:invalid_tx_hash, _}` | `{:invalid_log, _}`). Consumers can now see, count, or react to malformed notifications without destabilizing the WebSocket transport (dispatch still runs inside zen_websocket's callback, so handler errors remain the consumer's concern). The Logger.debug lines are removed — double-emission would just be noise.

### Maintenance — Strip upstream-cascade dialyzer suppressions (Task 43)

- **Removed the `@dialyzer {:no_match, :no_return, :no_contracts}` blocks** from `Onchain.ABI`, `Onchain.Contract`, `Onchain.ENS`, `Onchain.Log`, `Onchain.Multicall`, `Onchain.Sleuth`, `Onchain.Transfer`, `Onchain.ERC20`, `Onchain.ERC721`, `Onchain.ERC1155`, and `Onchain.Hex`. All eleven were stale: cartouche 0.1.0 carries the corrected `Cartouche.Hex` specs and pulls in hieroglyph 1.0.0 which fixes the `ABI.decode/2` `no_return` cascade. `mix dialyzer.json --quiet` is clean (zero warnings) post-strip, confirming the upstream specs are now correct.
- **Suppressions left in place after re-probe.** `Onchain.Subscription`'s block stays — root cause is `zen_websocket JsonRpc.build_request/2` (separate upstream, tracked under that file's `TODO(upstream)`). `Onchain.RPC.Helpers.do_rpc/3`'s single `:no_match` stays — re-probed against cartouche 0.1.0 and `Cartouche.RPC.send_rpc/3` still narrowly types errors as `%{code: int, message: str}`, while runtime errors include non-map values (Finch timeouts, connection refused). Comment refreshed with the 2026-04-30 probe date; re-probe on the next cartouche bump.

---

## v0.5.1 — zen_websocket 0.4.x compatibility (2026-04-19)

### Changed
- **zen_websocket bumped 0.3.1 → 0.4.2** (`mix.exs` constraint widened `~> 0.3` → `~> 0.4`). Picks up upstream fixes for blocked-caller draining (R042), duplicate JSON-RPC ID handling (R043), subscription forwarding to user handler (R038), and `:protocol_error` user-handler delivery (R039). 0.4.0 changes the handler contract: JSON text frames now arrive as decoded maps `{:message, %{}}` instead of raw binaries.

### Fixed
- **`Onchain.Subscription` handler regression under zen_websocket 0.4.x** — `build_internal_handler/2` was matching the pre-0.4.0 zen_websocket tuples (`{:message, {:text, _}}` / `{:message, binary}`), so subscription notifications under 0.4.x silently fell through and never reached the consumer's handler. Rewritten for the new contract; the dispatch path now also handles `{:binary, _}`, `{:unmatched_response, _}`, and `{:protocol_error, _}`. Visibility changed from `defp` to `def` (with `@doc false`) so the dispatch path is unit-testable without a live WebSocket.
- **Task 37 (zen_websocket `:disconnected` return) closed as resolved upstream** — zen_websocket 0.4.1 R042 added `RequestCorrelator.fail_all/2` so blocked `send_message` callers now receive `{:error, :disconnected}` automatically on disconnect; the local mitigation Task 37 was scoped for is no longer needed. Stale `TODO(upstream)` comment removed from `Onchain.Subscription`.

### Added
- **Unit coverage for the subscription dispatch path** — `test/onchain/subscription_test.exs` gains nine cases that inject synthetic decoded-map tuples through `build_internal_handler/2` and assert the full dispatch → parse → handler chain for `:new_heads`, `:logs`, `:pending_transactions`, plus the ignore-paths for non-JSON text, binary frames, unmatched responses, protocol errors, unknown subscription IDs, and unknown handler tuples. End-to-end verified against the local Ethereum archive node (`ws://localhost:8546`) via Tidewave: live `:new_heads` notification parsed and delivered correctly under 0.4.2.

---

## [Pre-0.5.1]

### Task 44: CLAUDE.md Module Layout drift fix

**Completed** | [D:1/B:3/U:4 → Eff:3.50]

**What was done:**
- Corrected `wallet.ex` bullet in CLAUDE.md: it does not expose `eth_getBalance / eth_getCode / get_transaction_by_hash` (those live on `Onchain.RPC`); actual surface is `classify` + `balance`
- Refreshed `erc20.ex` bullet to list the real read + write surface (`balanceOf, allowance, decimals, symbol, totalSupply, approve, transfer`) instead of the stale three-function summary

### Task 45: `Onchain.ERC20.total_supply/2` + bang variant

**Completed** | [D:2/B:5/U:6 → Eff:2.75]

**What was done:**
- Added `Onchain.ERC20.total_supply/2` and `total_supply!/2`, mirroring the `decimals/2` shape (eth_call wrapper with `totalSupply()` ABI → `uint256`)
- Full Descripex `api()` annotations and `@spec`
- Dialyzer suppressions for the existing Contract.call/Signet.Hex spec cascade
- Unit test for invalid-token-address path + WETH mainnet integration test (positive supply)
- Updates README's Core Primitives table and CLAUDE.md bullet so the ERC-20 read surface is discoverable

### Task 46: Lowercase `Onchain.Hex.from_integer/1`

**Completed** | [D:1/B:2/U:2 → Eff:2.00]

**What was done:**
- Wrapped `Signet.Hex.encode_short_hex/1` with `String.downcase/1` so `from_integer/1` now emits lowercase hex (`"0xff"`) matching `Hex.encode/1`'s lowercase contract
- Updated docstring example and the corresponding hex_test.exs assertion
- Verified no production caller compares the output against an uppercase literal (RPC call sites just pass the string through)

---

## v0.5.0 — Chain Intelligence (Subscriptions, NFT reads)

**Highlights:**
- New `Onchain.Subscription` module for real-time `eth_subscribe` streams (newHeads, pendingTx, logs) via zen_websocket
- `Onchain.ERC721` + `Onchain.ERC1155` read operations for NFT tracking
- Bang variants + edge-case coverage across ENS, RPC, Log, Transfer, Multicall
- New runtime dep: `zen_websocket ~> 0.3` (WebSocket transport)
- Pin tightenings: `descripex ~> 0.6`, `ex_dna ~> 1.3`
- Explicit `files:` list on hex package — tarball now contains only `lib`, `.formatter.exs`, `mix.exs`, `README.md`, `LICENSE`, `CHANGELOG.md`
- Credo switched back from `release/1.7` git branch to Hex release `{:credo, "~> 1.7"}` (upstream Elixir 1.20+ sigil fix now published in 1.7.18) — Task 40

---

### Task 31: Real-time Subscriptions (eth_subscribe)

**Completed** | [D:5/B:9/U:8 → Eff:1.70]

**What was done:**
- Added `Onchain.Subscription` module wrapping zen_websocket for Ethereum-specific WebSocket subscriptions
- Added `Onchain.Subscription.Parser` for pure parsing of subscription notification payloads
- Supports three subscription types: `:new_heads` (block headers), `:pending_transactions` (mempool tx hashes), `{:logs, filter}` (filtered event logs)
- Handler function pattern for event delivery — consumer passes `:handler` to `connect/2`, or uses default process messages `{:subscription, event}`
- Agent-based subscription tracking maps subscription IDs to types for async notification dispatch
- Extracted `parse_log/1`, `parse_hex_integer/1`, `parse_address/1` from `Onchain.RPC` to `Onchain.RPC.Helpers` for reuse
- Added zen_websocket (~> 0.3) and jason (~> 1.4) as dependencies
- Full Descripex `api()` annotations and bang variants for all public functions
- Registered in `Onchain` Discoverable modules list

**Key decisions:**
- Pure parsing separated from connection management — `Parser` has zero WebSocket dependencies, fully testable in isolation
- Agent (not GenServer) for subscription state — minimal process, private to each connection, no supervision tree forced on consumers
- No automatic HTTP→WS URL conversion — consumer provides WebSocket URL directly (library design principle)
- Dialyzer suppressions for upstream zen_websocket `build_request/2` spec mismatch (expects `map()`, Ethereum uses `list()` params)

---

### Task 33: ERC-721/ERC-1155 Read Operations

**Completed** | [D:3/B:6/U:5 → Eff:1.83]

**What was done:**
- Added `Onchain.ERC721` module with 7 read operations: `balance_of`, `owner_of`, `token_uri`, `name`, `symbol`, `get_approved`, `approved_for_all?` (+ bang variants)
- Added `Onchain.ERC1155` module with 4 read operations: `balance_of`, `balance_of_batch`, `uri`, `approved_for_all?` (+ bang variants)
- ERC-1155 `balance_of_batch` validates owners/token_ids list length match before RPC call
- Address-returning functions (`owner_of`, `get_approved`) return EIP-55 checksummed hex via `Address.checksum/1`
- Predicate functions use Elixir `?` convention (`approved_for_all?`) despite Solidity's `isApprovedForAll` naming
- Full Descripex `api()` annotations for self-describing APIs
- Unit tests for input validation and bang variants
- Integration tests against BAYC (ERC-721) and OpenSea Shared Storefront (ERC-1155) on mainnet
- Registered both modules in `Onchain` Discoverable list

**Key decisions:**
- Read-only operations only — no write/transfer/approve functions (consumers use `Signer.send_transaction` directly for writes)
- Return checksummed hex for address results rather than raw binary — more useful to consumers
- Named `approved_for_all?` / `approved_for_all!` (not `is_approved_for_all`) to follow Elixir naming conventions

---

## v0.4.1 — Documentation & Test Fixes

- Extract Phase 9 (JS bridge) to [onchain_js](https://github.com/ZenHive/onchain_js) — separate package for QuickBEAM/Zig NIFs
- Add onchain_tempo to portfolio context (five-package family)
- Fix EOA tests for EIP-7702 (pin historical blocks where EOAs have no delegated code)
- Adjust integration test block ranges for Alchemy free tier (10-block limit)
- Expand Dialyzer suppressions for ENS, Log, Multicall private functions
- Add `Onchain.SignerCase` reusable test helpers for transaction signing

---

## Extract JS Bridge to onchain_js

Phase 9 (JS bridge tasks: QuickBEAM foundation, solc-js, Uniswap SDK, DeFiSaver, merkletreejs, Aave math cross-validation, 1inch) extracted to [onchain_js](https://github.com/ZenHive/onchain_js).

**Why:** QuickBEAM (Zig NIF) violates onchain's "pure Elixir, no native deps" principle. Following the portfolio pattern where each native runtime gets its own package.

**What changed in onchain:**
- ROADMAP.md: Phase 9 removed, pointer added to onchain_js/ROADMAP.md
- CLAUDE.md: Portfolio context updated from 3 to 4 libraries
- README.md: Package family table updated with onchain_js

---

## v0.4.0 — Package Split

Split onchain monolith into 3 focused Hex packages:

- **onchain** (this repo) — Pure Elixir core: Ethereum primitives, RPC, ABI, signing, ERC-20, ENS, Transfer. No Rustler dependency.
- **onchain_aave** — Aave V3 protocol wrappers (pool reads/writes, oracle, math, types). Depends on onchain.
- **onchain_evm** — Rust NIFs: revm local EVM simulation, Solidity ABI parsing (Alloy), debug/trace APIs, contract codegen. Depends on onchain + Rustler.

**Why:** Consumers who only need `eth_call` no longer compile Rustler + two NIF crates. Zero code changes for consumers — only `mix.exs` deps change.

**Consumer migration:**
| Consumer | v0.3.0 | v0.4.0 |
|----------|--------|--------|
| Aave read/write | `{:onchain, "~> 0.3"}` | `{:onchain, "~> 0.4"}, {:onchain_aave, "~> 0.1"}` |
| Signing only | `{:onchain, "~> 0.3"}` | `{:onchain, "~> 0.4"}` |
| EVM simulation | `{:onchain, "~> 0.3"}` | `{:onchain, "~> 0.4"}, {:onchain_evm, "~> 0.1"}` |

---

## Code Review #2 (ENS + Transfer)

### Fix: Edge cases, type safety, TODO tracking
**Completed** | Code review findings (5 issues fixed)

**What was done:**
- **ENS:** `namehash(".")` now returns `{:error, {:invalid_name, "."}}` instead of silently producing the zero node hash — input that normalizes to empty from non-empty is rejected
- **ENS:** Added 4 TODO markers for future enhancements (CCIP-Read, wildcard resolution, UTS-46 normalization, multi-coin) — now Credo-visible
- **Transfer:** Tightened `ensure_checksum/1` catch-all clause — raw hex now only matches exactly 40-byte binaries, 0x-prefixed matches exactly `0x` + 40 chars
- **Transfer:** Added comment explaining eth_getLogs OR semantics for nested topic array in `fetch/2`
- **CHANGELOG:** Removed dangling ROADMAP.md link (file is now gitignored as session artifact)

**Files:**
- `lib/onchain/ens.ex` (modified — dot rejection, TODO markers)
- `lib/onchain/transfer.ex` (modified — tighter ensure_checksum, comment)
- `test/onchain/ens_test.exs` (modified — new "rejects bare dot" test)
- `CHANGELOG.md` (modified — removed dangling link)

---

## Code Review Fixes (ENS + Transfer)

### Fix: Error semantics, address safety, validation, auto-topics
**Completed** | Code review findings (8 issues fixed, rating 8/10 → improved)

**What was done:**
- **ENS:** Changed `reverse/2` error tag from `{:no_address, addr}` to `{:no_reverse, addr}` — distinguishes "no reverse record" from forward resolution's "no address set"
- **ENS:** Replaced loose name validation regex with per-label `valid_label?/1` — rejects hyphens at label start/end (`-foo.eth`, `foo-.eth`) per DNS/ENS conventions
- **ENS:** Removed unused `@abi_json/zlib/cbor/uri` module attributes and their suppression hack
- **Transfer:** Refactored `build_transfer/3` to return `{:ok, t()} | {:error, term()}` using `Address.checksum/1` (non-bang) — malformed addresses now return error tuples instead of crashing
- **Transfer:** `fetch/2` auto-injects all 3 transfer topic hashes when caller omits topics — covers ERC-20, ERC-721, and ERC-1155 in one call
- **Transfer:** Consolidated two identical catch-all `parse_log/1` clauses into one
- **Transfer integration test:** Changed `async: true` to `async: false` to avoid RPC rate-limiting
- **Tests:** Added unit tests for hyphen validation and reverse name construction

**Files:**
- `lib/onchain/ens.ex` (modified — error tag, validation, removed unused constants)
- `lib/onchain/transfer.ex` (modified — safe checksumming, auto-topics, consolidated clause)
- `test/onchain/ens_test.exs` (modified — 5 new tests)
- `test/onchain/transfer_integration_test.exs` (modified — async flag)

---

## Phase 8: Wallet & Token Tracking

### Task 34: ENS Resolution
**Completed** | [D:3/B:7/U:7 → Eff:2.33]

**What was done:**
- Full ENS resolver module with forward resolution (name → address), reverse resolution (address → name), text records, contenthash, ABI, and pubkey retrieval
- Pure namehash computation (EIP-137) with ASCII normalization and trailing dot handling
- Two-step resolution pattern: Registry lookup → Resolver query via `Contract.call/5`
- Configurable registry address via `:registry` opt for L2 deployments
- Descripex self-describing API declarations for all functions
- Unit tests with EIP-137 reference vectors, integration tests against mainnet (vitalik.eth)

**Files:**
- `lib/onchain/ens.ex` (created — full resolver module with 16 public functions)
- `test/onchain/ens_test.exs` (created — unit tests for namehash + input validation)
- `test/onchain/ens_integration_test.exs` (created — mainnet integration tests)
- `lib/onchain.ex` (modified — added `Onchain.ENS` to Discoverable)

---

### Task 32: Transfer Event Parser
**Completed** | [D:3/B:9/U:9 → Eff:3.00]

**What was done:**
- Added `Onchain.Transfer` module that parses ERC-20, ERC-721, and ERC-1155 Transfer events from raw logs into normalized `%Transfer{}` structs
- ERC-20/721 disambiguation via topic count (3 topics = ERC-20, 4 topics = ERC-721)
- ERC-1155 TransferSingle and TransferBatch support, with batch expansion into individual structs
- `fetch/2` convenience combining `eth_get_logs` + `parse_logs` in one call
- `transfer_topics/0` exposes precomputed topic hashes for filter building
- Added to `Onchain` Discoverable modules list

**Files:**
- `lib/onchain/transfer.ex` (created — struct, parser, fetch, Descripex API)
- `test/onchain/transfer_test.exs` (created — unit tests with fixtures)
- `test/onchain/transfer_integration_test.exs` (created — mainnet USDC integration tests)
- `lib/onchain.ex` (modified — added `Onchain.Transfer` to Discoverable)

---

## Code Review Fixes (Rust NIFs + Elixir)

### Fix: Batch simulation, defensive parsing, array handling, NatSpec
**Completed** | Code review findings

**What was done:**
- **Rust EVM NIF:** Switched `do_simulate_batch` from `transact()` to `transact_commit()` — state changes now persist between sequential calls in a batch (previously each call saw the original fork state, breaking dependent sequences like approve→transfer)
- **Rust Solidity NIF:** Fixed two-layer bug in fixed-size array handling — `expr_to_type_string` now preserves array size from AST (`uint256[3]` no longer becomes `uint256[]`), and `split_array_suffix` now strips both dynamic `[]` and fixed-size `[N]` suffixes for type registry lookups
- **Rust Solidity NIF:** Added `@returns` (plural) NatSpec tag parsing alongside `@return` — many real-world contracts use the plural form
- **Rust Solidity NIF:** Extracted `MAX_NATSPEC_DISTANCE_BYTES` constant (was magic number `100`)
- **Elixir RPC:** `parse_address` and `parse_hex_integer` now use non-raising variants (`checksum/1`, `to_integer/1`) to handle malformed RPC responses gracefully instead of crashing
- **Elixir RPC:** Deduplicated `@block_tags` — single source of truth in `Onchain.RPC.Helpers`, referenced at compile time in `Onchain.RPC`
- **Elixir Wallet:** `balance!/2` now raises "balance failed" instead of "get_balance failed"

**Files:**
- `native/onchain_evm/src/lib.rs` (modified — `transact_commit()` in batch loop)
- `native/onchain_solidity/src/lib.rs` (modified — array handling, `@returns`, constant extraction)
- `lib/onchain/rpc.ex` (modified — defensive parsing, deduplicated `@block_tags`)
- `lib/onchain/rpc/helpers.ex` (modified — exposed `block_tags/0`)
- `lib/onchain/wallet.ex` (modified — inline `balance!`)
- `test/onchain/wallet_test.exs` (modified — updated error message assertion)

---

## Phase 8: Chain Intelligence Primitives

### Task 30: Wallet Primitives
**Completed** | [D:3/B:8/U:9 → Eff:2.83]

**What was done:**
- Added `eth_get_code/2` to `Onchain.RPC` — fetches contract bytecode, returns `"0x"` for EOAs
- Added `get_transaction_by_hash/2` to `Onchain.RPC` — fetches full transaction details with parsed fields (addresses checksummed, hex integers decoded)
- Created `Onchain.Wallet` convenience module with `classify/2` (`:eoa` or `:contract`) and `balance/2` (native ETH in wei)
- Bang variants for all new functions
- Descripex self-describing API metadata on all functions

**Files:**
- `lib/onchain/rpc.ex` (modified — added `eth_get_code`, `get_transaction_by_hash`, `parse_transaction/1`)
- `lib/onchain/wallet.ex` (new — thin convenience layer over RPC)
- `test/onchain/rpc_test.exs` (modified — unit tests for new methods)
- `test/onchain/wallet_test.exs` (new — unit tests)
- `test/onchain/rpc/code_integration_test.exs` (new — WETH contract vs EOA)
- `test/onchain/rpc/transaction_integration_test.exs` (new — parsed fields verification)
- `test/onchain/wallet_integration_test.exs` (new — classify + balance integration)

---

## Code Health

### Task 36: Extract Shared RPC Helpers
**Completed** | [D:3/B:6/U:5 → Eff:1.83]

**What was done:**
- Extracted 7 duplicated private functions from `Onchain.RPC` and `Onchain.Trace` into new `Onchain.RPC.Helpers` module
- Functions: `do_rpc/3`, `ensure_hex_address/1`, `ensure_hex_data/1`, `normalize_block/1`, `ensure_tx_hash/1`, `to_signet_opts/1`, `rename_key/3`
- Both modules now `import Onchain.RPC.Helpers` — call sites unchanged
- Fixed `String.length` → `byte_size` bug in `ensure_tx_hash/1` (O(n) → O(1), semantically correct for ASCII hex)

**Files:**
- `lib/onchain/rpc/helpers.ex` (new)
- `lib/onchain/rpc.ex` (modified — removed extracted functions, added import)
- `lib/onchain/trace.ex` (modified — removed extracted functions, added import)
- `test/onchain/rpc/helpers_test.exs` (new — direct unit tests for helpers)

---

## Phase 6: Local EVM Simulation

### Task 27: Debug/Trace API Module
**Completed** | [D:4/B:7/U:6 → Eff:1.63]

**What was done:**
- Created `Onchain.Trace` module (pure Elixir, no NIF) wrapping debug/trace JSON-RPC methods
- `trace_transaction/2` — full execution trace of a mined tx via `debug_traceTransaction`
- `trace_call/3` — trace a call without mining via `debug_traceCall`
- `storage_at/3` — read arbitrary contract storage slots via `eth_getStorageAt`
- `available?/1` — probe whether connected node supports debug/trace APIs
- Supports `callTracer` (default) and `prestateTracer` tracer types
- Bang variants for all three main functions
- Input validation matching `Onchain.RPC` patterns (address, tx hash, block, slot)
- Descripex self-describing API metadata
- Named `Onchain.Trace` (not `Onchain.Reth`) because debug/trace APIs are standard JSON-RPC extensions supported by reth, geth, Erigon, and Nethermind

**Design decisions:**
- No custom structs for trace output — trace shape varies by tracer type, raw maps are the honest API
- `storage_at` included here as the "direct state access" primitive rather than in `Onchain.RPC`
- No Rust NIF needed — all methods are standard JSON-RPC calls via `Signet.RPC.send_rpc/3`

**Files:**
- `lib/onchain/trace.ex` (new)
- `lib/onchain.ex` (modified — added `Onchain.Trace` to Discoverable modules)
- `test/onchain/trace_test.exs` (new — unit tests)
- `test/onchain/trace_integration_test.exs` (new — integration tests, tagged `:trace`)

---

### Task 26: Rustler NIF — revm Local EVM Execution
**Completed** | [D:6/B:10/U:9 → Eff:1.58]

**What was done:**
- Created `native/onchain_evm/` Rustler NIF crate wrapping revm 19 with alloy 0.7 for RPC-forked EVM simulation
- Three NIF functions (`nif_simulate_call`, `nif_simulate_transaction`, `nif_simulate_batch`) running on DirtyIo scheduler
- `simulate_call/3` — read-only call simulation returning hex output compatible with `ABI.decode_response/2`
- `simulate_transaction/3` — full tx simulation returning `%{success, gas_used, output, logs}` map
- `simulate_batch/2` — multiple calls on a single forked state (shared CacheDB)
- State overrides support: balance, nonce, code, and storage slot overrides per address
- Fork at specific block number or latest
- Input validation using `Address.validate/1` and `Hex.valid?/1` with descriptive error tuples
- Bang variants for all three functions
- Descripex self-describing API metadata

**Files:**
- `native/onchain_evm/Cargo.toml` (new)
- `native/onchain_evm/src/lib.rs` (new)
- `lib/onchain/evm.ex` (new)
- `lib/onchain.ex` (modified — added `Onchain.EVM` to Discoverable modules)
- `test/onchain/evm_test.exs` (new — unit tests)
- `test/onchain/evm_integration_test.exs` (new — integration tests)

---

## Phase 5: Contract Codegen

### Task 25b: Solidity Import/Remapping Resolution for Multi-File Codegen
**Completed** | [D:5/B:9/U:8 → Eff:1.80]

**What was done:**
- Added multi-file Solidity resolution in `Onchain.Solidity` with `resolve_sol_file/2`, `resolve_sol_file!/2`, and extended `parse_sol_file/2` support for relative imports, nearest-ancestor `remappings.txt`, and explicit remapping overrides
- Added native helpers to extract Solidity imports and parse a selected root contract from a merged source graph while keeping imported structs, enums, and constants available for codegen
- Extended `Onchain.Contract.Generator` with `sol_file:` plus passthrough `:remappings` and `:root_contract` options, and registered resolved files as `@external_resource`
- Vendored pinned upstream DefiSaver and Aave Solidity fixtures to exercise relative imports and remapped imports with real contracts
- Added parser and generator coverage for multi-file `.sol` inputs, imported namespaced structs, nested imported `from_raw/1` conversion, root-contract filtering, and external resource tracking

**Files:**
- `lib/onchain/solidity.ex` (modified)
- `native/onchain_solidity/src/lib.rs` (modified)
- `lib/onchain/contract/generator.ex` (modified)
- `priv/contracts/real/defisaver-v3-contracts/contracts/interfaces/protocols/aaveV3/DataTypes.sol` (new)
- `priv/contracts/real/defisaver-v3-contracts/contracts/interfaces/protocols/aaveV3/IPoolAddressesProvider.sol` (new)
- `priv/contracts/real/defisaver-v3-contracts/contracts/interfaces/protocols/aaveV3/IPoolV3.sol` (new)
- `priv/contracts/real/aave-v3-periphery/contracts/misc/interfaces/IUiPoolDataProviderV3.sol` (new)
- `priv/contracts/real/aave-v3-periphery/lib/aave-v3-core/contracts/interfaces/IPoolAddressesProvider.sol` (new)
- `priv/contracts/real/aave-v3-periphery/remappings.txt` (new)
- `test/onchain/solidity_test.exs` (modified)
- `test/onchain/contract/generator_test.exs` (modified)

---

### Fix: Nested Struct Conversion in Generated `from_raw/1`
**Completed** | Follow-up to Task 25

**What was done:**
- Generated `.sol` struct modules now recursively convert nested child structs in `from_raw/1` instead of leaving nested tuples raw
- Nested address fields continue to flow through `Onchain.Address.checksum!/1` via the child struct conversion path
- Added a focused regression test for `Nested -> UserData` conversion using the existing Solidity fixture
- Added roadmap follow-up Task 25b for multi-file Solidity import/remapping support in codegen

**Files:**
- `lib/onchain/contract/generator.ex` (modified)
- `test/onchain/contract/generator_test.exs` (modified)
- `ROADMAP.md` (modified)

---

### Task 25: Contract Codegen Macro (`Onchain.Contract.Generator`)
**Completed** | [D:6/B:10/U:9 → Eff:1.58]

**What was done:**
- Created `Onchain.Contract.Generator` — a `@before_compile` macro that reads a Solidity ABI at compile time and generates typed Elixir functions for every contract function
- Three input modes: `:sol` (Solidity source via `parse_sol!`), `:abi_json` (JSON string via `parse_abi_json!`), `:abi_file` (file path via `parse_abi_file!`)
- **Read functions** (`view`/`pure`): delegates to `Onchain.Contract.call/5` with `opts \\ []`
- **Write functions** (`nonpayable`/`payable`): ABI-encodes calldata via `Onchain.ABI.encode_call/2`, delegates to `Onchain.Signer.send_transaction/3` with required `opts`
- **Bang variants** for all functions — raises on error
- **Address validation**: `address` params validated via `Onchain.Address.validate/1` in `with` chain before ABI encoding
- **camelCase → snake_case** naming with overload disambiguation (same-arity overloads get type suffixes)
- **`.sol` extras**: nested `defmodule` structs with `@enforce_keys`, `defstruct`, `from_raw/1`; enum constants as module attributes; `@doc` from NatSpec `/// @notice`
- **`__contract_abi__/0`**: returns full parsed ABI map
- **`@dialyzer` annotations**: same cascade pattern as `erc20.ex` for Signet spec mismatch
- **`@moduledoc`**: auto-generated function listing by read/write type

**Files:**
- `lib/onchain/contract/generator.ex` (created)
- `test/onchain/contract/generator_test.exs` (created)
- `test/onchain/contract/generator_integration_test.exs` (created)

---

### Task 24: Rustler NIF — Solidity ABI Parser via Alloy (`Onchain.Solidity`)
**Completed** | [D:5/B:9/U:9 → Eff:1.80]

**What was done:**
- Added Rustler NIF using Alloy (`alloy-json-abi`) to parse Solidity ABI JSON into structured Elixir maps
- Returns functions (with signature, selector, return_type, state_mutability, inputs/outputs), events (with topic hash, indexed params), errors, and constructor
- The `return_type` field produces tuple-type strings compatible with `Onchain.ABI.decode_response/2`, bridging parsing to existing encoding infrastructure
- Handles nested tuple/struct types, overloaded functions, and all Solidity ABI item types
- File convenience functions (`parse_abi_file/1`) keep file I/O in Elixir, NIF does pure JSON parsing

**Files:**
- `mix.exs` (modified — added `{:rustler, "~> 0.37"}`)
- `native/onchain_solidity/Cargo.toml` (new — Rust crate with alloy-json-abi, serde_json, hex)
- `native/onchain_solidity/src/lib.rs` (new — NIF implementation, single `parse_abi_json` function)
- `lib/onchain/solidity.ex` (new — Elixir wrapper with parse_abi_json/!, parse_abi_file/!)
- `test/onchain/solidity_test.exs` (new — unit tests using existing priv/abis/ fixtures)

---

## Code Review Fixes (Phase 3)

### Fix: Block param validation, tx hash validation, flaky receipt tests
**Completed** | Code review findings from Codex

**What was done:**
- Added `normalize_block/1` to validate and convert `:block` option in `eth_call/3`, `get_balance/2`, `get_transaction_count/2` — integers auto-converted to hex, tags and hex strings validated, invalid values return `{:error, {:invalid_block, value}}`
- Added `ensure_tx_hash/1` to validate 32-byte transaction hashes in `get_transaction_receipt/2` — rejects too-short/too-long hex with `{:error, {:invalid_tx_hash, value}}`
- Fixed flaky receipt integration tests: replaced `"latest"` block (may have empty transactions) with `@test_block 20_000_000` (known mainnet block with transactions), removed broken `|| ["0x0"]` fallbacks
- Updated transaction count integration test to pass integer block directly (validates `normalize_block` works end-to-end)
- Added unit tests: block validation for eth_call, get_balance, get_transaction_count (invalid/integer/tag); tx hash validation (too-short, valid 32-byte, no prefix, invalid hex)

**Files:**
- `lib/onchain/rpc.ex` (modified — added normalize_block/1, ensure_tx_hash/1, updated 4 functions)
- `test/onchain/rpc_test.exs` (modified — added block and tx hash validation tests)
- `test/onchain/rpc/receipt_integration_test.exs` (modified — deterministic block, removed fallbacks)
- `test/onchain/rpc/transaction_count_integration_test.exs` (modified — integer block param)

---

## Phase 3: Aave Actions (Write)

### Task 35: Aave Testnet Faucet Module (`Onchain.Aave.Faucet`)
**Completed** | [D:2/B:4/U:3 → Eff:1.75]

**What was done:**
- Created `Onchain.Aave.Faucet` with `mint/4` and `mint!/4` — validates addresses, looks up faucet contract via `Contracts.address(:faucet, ...)`, ABI-encodes `mint(address,address,uint256)`, delegates to `Signer.send_transaction/3`
- Added `:faucet` address to Sepolia entry in `Onchain.Aave.Contracts` — faucet is testnet-only, so mainnet networks naturally return `{:error, {:unknown_contract, :faucet}}`
- Default gas limit of 200k applied when not specified in opts
- Refactored `pool_write_integration_test.exs` to use `Faucet.mint/4` instead of inline ABI encoding

**Files:**
- `lib/onchain/aave/faucet.ex` (created — mint/4, mint!/4 with Descripex metadata)
- `lib/onchain/aave/contracts.ex` (modified — added `:faucet` to sepolia map)
- `test/onchain/aave/faucet_test.exs` (created — unit tests for validation and network guards)
- `test/onchain/aave/faucet_integration_test.exs` (created — Sepolia mint + balance verification)
- `test/onchain/aave/pool_write_integration_test.exs` (modified — uses Faucet.mint instead of inline logic)

---

### Task 14b: Pool Write Sepolia Integration Tests (`Onchain.Aave.Pool`)
**Completed** | [D:4/B:7/U:6 → Eff:1.63]

**What was done:**
- Added `:sepolia` network to `Onchain.Aave.Contracts` address registry (pool_addresses_provider, pool, oracle, ui_pool_data_provider) — verified on-chain via PoolAddressesProvider.getPool/getPriceOracle and BGD Labs aave-address-book src/AaveV3Sepolia.sol
- Added Sepolia on-chain verification tests to contracts integration tests (getPool, getPriceOracle match stored addresses)
- Created pool write integration tests with two round-trip scenarios on Sepolia testnet:
  - **Supply/withdraw round trip**: Mint WETH from Aave faucet → approve Pool → supply WETH → assert collateral increased → withdraw → assert collateral decreased
  - **Borrow/repay round trip**: Supply WETH as collateral → borrow USDC (variable rate) → assert debt increased → approve USDC → repay full debt (max uint256) → assert debt decreased
- Faucet minting is idempotent (only mints if balance below threshold)
- Uses directional assertions (increased/decreased) to handle testnet state persistence and interest accrual
- Corrected faucet ABI from plan's `mint(address,uint256)` to actual `mint(address,address,uint256)` (token, to, amount)

**Files:**
- `lib/onchain/aave/contracts.ex` (modified — added `:sepolia` network entry, updated moduledoc)
- `test/onchain/aave/contracts_test.exs` (modified — added `:sepolia` to `@all_networks`, updated network count to 7)
- `test/onchain/aave/contracts_integration_test.exs` (modified — added Sepolia on-chain verification tests)
- `test/onchain/aave/pool_write_integration_test.exs` (created — supply/withdraw + borrow/repay round trips)

---

### Task 14: Aave V3 Pool Write Operations (`Onchain.Aave.Pool`)
**Completed** | [D:6/B:9/U:8 → Eff:1.42]

**What was done:**
- Added `supply/4`, `withdraw/4`, `borrow/4`, `repay/4` + bang variants to `Onchain.Aave.Pool`
- Each validates addresses, resolves Pool address from `:network` option, ABI-encodes calldata, and delegates to `Signer.send_transaction/3`
- `referralCode` hardcoded to 0 (vestigial in V3, no active program)
- `interest_rate_mode` option for borrow/repay: `:variable` (default, maps to 2), `:stable` (maps to 1); invalid values return `{:error, {:invalid_interest_rate_mode, value}}`
- Private `split_write_opts/1` separates `:network` and `:interest_rate_mode` from Signer opts
- Private `resolve_interest_rate_mode/1` maps atoms to Solidity uint256 values
- Added `@dialyzer` annotations for the same Signet spec cascade as other write functions
- Added descripex `api()` declarations for all 8 new functions
- Updated `@moduledoc` to document write operations alongside reads
- Unit tests: address validation errors (asset, on_behalf_of/to), unsupported network, invalid interest_rate_mode (borrow/repay), bang variant raises
- Full calldata verification via `:dbg` trace: ABI selector correctness, argument position verification (all 32-byte slots), referralCode == 0, variable/stable rate encoding, distinct selectors across all 4 operations

**Files:**
- `lib/onchain/aave/pool.ex` (modified — added 8 functions, 2 helpers, aliases, constants, dialyzer, api() macros, moduledoc)
- `test/onchain/aave/pool_test.exs` (modified — switched to async: false, added write unit tests + calldata verification)

---

### Task 13: ERC-20 Write Operations (`Onchain.ERC20`)
**Completed** | [D:4/B:8/U:8 → Eff:2.00]

**What was done:**
- Added `approve/4` and `transfer/4` + bang variants to `Onchain.ERC20`
- Each validates the target address (spender/recipient), ABI-encodes the calldata, and delegates to `Signer.send_transaction/3`
- ABI selectors: `0x095ea7b3` (approve), `0xa9059cbb` (transfer)
- Added descripex `api()` declarations for all 4 new functions
- Added `@dialyzer` annotations for the same Signet spec cascade as read functions
- Updated `@moduledoc` to document write operations alongside reads
- Unit tests: address validation errors, ABI selector verification, bang variant raises
- Integration tests (Sepolia): self-approve with allowance verification, zero transfer to self with receipt verification

**Files:**
- `lib/onchain/erc20.ex` (modified — added 4 functions + aliases + dialyzer + api() macros + moduledoc)
- `test/onchain/erc20_test.exs` (modified — added 8 unit tests for approve/transfer)
- `test/onchain/erc20_write_integration_test.exs` (created — Sepolia integration tests)

---

### Task 12: Transaction Signing Setup (`Onchain.Signer`)
**Completed** | [D:4/B:9/U:9 → Eff:2.25]

**What was done:**
- Created `Onchain.Signer` with 10-function API (5 functions + bang variants): `address_from_key`, `build_transaction`, `sign_transaction`, `encode_transaction`, `send_transaction`
- Stateless EIP-1559 pipeline — no GenServer, no application config, private key always explicit
- Uses `Signet.Signer.sign_direct/4` for signing without a running GenServer, `Signet.Transaction.V2` for transaction construction
- `build_transaction/3` accepts `{n, :gwei}` tuples or integer wei for gas params, with sensible defaults (100k gas, 30 gwei max fee, 2 gwei priority)
- `send_transaction/3` composes the full pipeline: build → sign → encode → broadcast via `RPC.eth_send_raw_transaction`
- Private `decode_private_key/1` helper accepts 32-byte binary or hex string (with/without 0x)
- Created `Onchain.SignerCase` test helpers (reusable by tasks 13, 14): `signer_key!`, `signer_address!`, `sepolia_rpc_url!`, `wait_for_receipt`
- Added descripex `api()` declarations with namespace `/signer`
- Added `Onchain.Signer` to Discoverable modules list
- Unit tests: address derivation (binary/hex/bare, checksummed, errors), build_transaction (fields, gas params, defaults, missing opts, invalid address), sign_transaction (signature fields, signer recovery), encode_transaction (hex output, unsigned error, decode roundtrip), full roundtrip, bang variants
- Integration tests: real Sepolia key address derivation, nonce fetch, self-transfer with receipt verification (opt-in `:sepolia_send` tag)

**Files:**
- `lib/onchain/signer.ex` (created)
- `test/onchain/signer_test.exs` (created)
- `test/onchain/signer_integration_test.exs` (created)
- `test/support/signer_case.ex` (created)
- `lib/onchain.ex` (added Signer to Discoverable)

---

### Task 23: Transaction Receipt + Nonce RPC Methods (`Onchain.RPC`)
**Completed** | [D:3/B:8/U:8 → Eff:2.67]

**What was done:**
- Added `get_transaction_receipt/2` + bang variant — calls `eth_getTransactionReceipt`, returns parsed atom-keyed map or nil for pending/unknown transactions
- Receipt parsing via `parse_receipt/1`: hex fields decoded to integers (block_number, gas_used, status, etc.), addresses checksummed, logs reuse existing `parse_log/1`
- Added `get_transaction_count/2` + bang variant — calls `eth_getTransactionCount`, returns nonce as integer. Follows `get_balance` pattern (address + opts with `:block` default "latest", `:decode, :hex_unsigned`)
- Updated `@moduledoc` function table with 6 missing rows (eth_get_logs pair was also undocumented)
- Added descripex `api()` declarations for all 4 new public functions
- Unit tests: input validation for tx_hash (no prefix, invalid hex, non-binary) and address (wrong byte size, invalid hex, non-binary, binary acceptance), bang variant raises
- Integration tests: receipt from known block tx (all fields verified), log structure consistency, nil for fake hash, bang variants; transaction count for Vitalik (positive), zero address (0), historical block comparison, binary address acceptance

**Files:**
- `lib/onchain/rpc.ex` (modified — added 4 functions, parse_receipt helper, updated moduledoc)
- `test/onchain/rpc_test.exs` (modified — added 8 unit tests)
- `test/onchain/rpc/receipt_integration_test.exs` (created)
- `test/onchain/rpc/transaction_count_integration_test.exs` (created)

---

## Phase 2b: Read Essentials

### Task 19: eth_getLogs + Event Log Parsing (`Onchain.RPC` + `Onchain.Log`)
**Completed** | [D:4/B:9/U:8 → Eff:2.13]

**What was done:**
- Added `eth_get_logs/2` + bang variant to `Onchain.RPC` — accepts filter map with `:address`, `:topics`, `:from_block`, `:to_block`; converts block numbers to hex; returns parsed log maps
- Log parsing: raw RPC response logs are converted to atom-keyed maps with checksummed addresses, integer block numbers/indices, and boolean `removed` flag
- Created `Onchain.Log` with 4-function API: `event_topic/1`, `decode_event/2` + bang variants
- `event_topic/1` computes keccak256 hash of event signatures via `Signet.Hash.keccak/1`
- `decode_event/2` parses event signatures with indexed markers (e.g. `"Transfer(address indexed from, address indexed to, uint256 value)"`), extracts indexed params from topics and non-indexed from ABI-decoded data field
- Address values are checksummed in both indexed and non-indexed results
- Added descripex `api()` declarations with namespaces `/rpc` and `/log`
- Added `Onchain.Log` to Discoverable modules list
- Unit tests: event_topic hashes for Transfer/Approval, decode_event with constructed logs, error cases
- Integration tests: fetch recent USDC Transfer events via eth_get_logs, decode fetched Transfer log with decode_event, empty results for non-matching filter

**Files:**
- `lib/onchain/rpc.ex` (modified — added eth_get_logs, build_log_filter, parse_log helpers)
- `lib/onchain/log.ex` (created)
- `test/onchain/log_test.exs` (created)
- `test/onchain/rpc/eth_get_logs_integration_test.exs` (created)
- `test/onchain/log_integration_test.exs` (created)
- `lib/onchain.ex` (added Log to Discoverable)

---

### Task 22: Multicall3 Batched Reads (`Onchain.Multicall`)
**Completed** | [D:5/B:8/U:7 → Eff:1.50]

**What was done:**
- Created `Onchain.Multicall` with 4-function API: `aggregate3/2`, `call_many/2` + bang variants
- `aggregate3/2` — low-level: takes `[{address, allow_failure, calldata}]` tuples, encodes as `aggregate3((address,bool,bytes)[])` ABI call to the Multicall3 contract, returns `[{success, return_data_hex}]`
- `call_many/2` — high-level: takes `[{address, signature, params, return_type}]`, auto-encodes each call, batches into single `aggregate3`, auto-decodes results. Returns `[{:ok, decoded_values} | {:error, hex}]`
- All calls use `allow_failure: true` for partial failure handling — individual failed calls return `{:error, data_hex}` without failing the batch
- Uses the canonical Multicall3 address `0xcA11bde05977b3631167028862bE2a173976CA11` (identical on all EVM chains)
- Added descripex `api()` declarations with namespace `/multicall`
- Added `Onchain.Multicall` to Discoverable modules list
- Unit tests for address validation errors, ABI signature errors, bang variants
- Integration tests: batch 3 ERC-20 reads (USDC symbol, USDC decimals, WETH symbol), partial failure with non-contract address, result consistency vs individual `Contract.call`

**Files:**
- `lib/onchain/multicall.ex` (created)
- `test/onchain/multicall_test.exs` (created)
- `test/onchain/multicall_integration_test.exs` (created)
- `lib/onchain.ex` (added Multicall to Discoverable)

---

### Task 20: ERC-20 Read Operations (`Onchain.ERC20`)
**Completed** | [D:3/B:8/U:8 → Eff:2.67]

**What was done:**
- Created `Onchain.ERC20` with 8-function API: `balance_of/3`, `allowance/4`, `decimals/2`, `symbol/2` + bang variants
- Each function is a thin wrapper around `Contract.call/5` with hardcoded ABI signatures
- Single-value unwrap: `Contract.call/5` returns `{:ok, [value]}`, ERC-20 functions return `{:ok, value}`
- `balance_of` and `allowance` validate holder/owner/spender addresses before passing as ABI params
- `decimals` and `symbol` take no address params beyond the token contract — just call and unwrap
- Raw integer returns for balances — consumers use `Onchain.Decimal.to_decimal/2` to normalize
- Added descripex `api()` declarations with namespace `/erc20`
- Added `Onchain.ERC20` to Discoverable modules list
- Unit tests for address validation errors and bang variant error cases
- Integration tests using USDC on mainnet (decimals=6, symbol="USDC", balance_of > 0, allowance >= 0)

**Files:**
- `lib/onchain/erc20.ex` (created)
- `test/onchain/erc20_test.exs` (created)
- `test/onchain/erc20_integration_test.exs` (created)
- `lib/onchain.ex` (added ERC20 to Discoverable)

---

### Task 18: Generic Contract Call (`Onchain.Contract`)
**Completed** | [D:3/B:9/U:9 → Eff:3.00]

**What was done:**
- Created `Onchain.Contract` with 2-function API: `call/5`, `call!/5`
- Composes the ABI encode → eth_call → ABI decode pipeline into a single function
- Accepts contract address (hex string or 20-byte binary), function signature, params, return type, and opts
- Errors pass through from underlying modules (Address, ABI, RPC) — no wrapping
- Added descripex `api()` declarations with namespace `/contract`
- Added `Onchain.Contract` to Discoverable modules list
- Unit tests for input validation and bang variant error cases
- Integration tests for ERC-20 reads (balanceOf, decimals), binary address input, bang variant, and error cases

**Files:**
- `lib/onchain/contract.ex` (created)
- `test/onchain/contract_test.exs` (created)
- `test/onchain/contract_integration_test.exs` (created)
- `lib/onchain.ex` (added Contract to Discoverable)

---

## Phase 2: Aave Core (Read)

### Task 11: Oracle + Chainlink Price Feeds (`Onchain.Aave.Oracle`)
**Completed** | [D:5/B:7/U:6 → Eff:1.30]

**What was done:**
- Created `Onchain.Aave.Oracle` with 14-function API (7 functions + bang variants)
- Aave Oracle reads: `get_asset_price/2`, `get_asset_prices/2`, `get_source_of_asset/2`, `get_base_currency/1`, `get_base_currency_unit/1`, `get_fallback_oracle/1`
- Each follows the Pool pattern: split_opts → Contracts.address(:oracle) → Contract.call → unwrap
- `get_asset_prices/2` validates all addresses before making the batch call
- Chainlink direct read: `get_latest_round_data/2` calls `latestRoundData()` on any Chainlink aggregator (obtained via `get_source_of_asset`), returns plain map with `:round_id`, `:answer`, `:started_at`, `:updated_at`, `:answered_in_round`
- Address results checksummed via `Address.checksum/1`
- Added descripex `api()` declarations with namespace `/aave/oracle`
- Added `Onchain.Aave.Oracle` to Discoverable modules list
- Unit tests for address validation errors and bang variant error cases
- Integration tests: WETH/USDC prices (non-zero), batch prices, Chainlink source address, base currency/unit (verifies 10^8), fallback oracle, latest round data shape and values

**Files:**
- `lib/onchain/aave/oracle.ex` (created)
- `test/onchain/aave/oracle_test.exs` (created)
- `test/onchain/aave/oracle_integration_test.exs` (created)
- `lib/onchain.ex` (added Aave.Oracle to Discoverable)

---

### Task 21: Multi-chain Aave Addresses
**Completed** | [D:2/B:7/U:7 → Eff:3.50]

**What was done:**
- Added 5 networks to `@addresses` map: Arbitrum, Optimism, Base, Polygon, Avalanche
- Each network has all 4 contract keys: pool_addresses_provider, pool, oracle, ui_pool_data_provider
- Addresses verified against BGD Labs Aave Address Book CSV
- Notable: pool and pool_addresses_provider are identical across Arbitrum, Optimism, Polygon, Avalanche (CREATE2 deployments); Base has different addresses
- Updated @moduledoc to list all 6 supported networks
- Updated tests: fixed `:polygon` → `:solana` in unsupported network error tests, added multi-network validation (all 6 networks × 4 contracts), CREATE2 address sharing assertions

**Files:**
- `lib/onchain/aave/contracts.ex` (modified — added 5 network entries)
- `test/onchain/aave/contracts_test.exs` (modified — multi-network tests, fixed error tests)

---

### Task 10: UiPoolDataProvider + Type Structs
**Completed** | [D:5/B:8/U:7 → Eff:1.50]

**What was done:**
- Created `Onchain.Aave.UiPoolDataProvider` with 6-function API: `get_reserves_list/1`, `get_reserves_data/1`, `get_user_reserves_data/2` + bang variants
- Each function composes Contracts → Address → ABI → RPC → decode → type struct pipeline (same pattern as Pool)
- Created 3 type structs (40-field AggregatedReserveData, 4-field BaseCurrencyInfo, 4-field UserReserveData)
- Verified deployed contract (`0x56b7...`) returns 40-field layout via Tidewave: no stable borrow fields, no e-mode fields, includes `virtualUnderlyingBalance` and `deficit`
- Conversion philosophy: fixed-scale fields converted (basis points → `to_ltv`, rays → `to_ray`, USD → `to_usd`), context-dependent fields stay raw (token amounts, prices, caps)
- Addresses checksummed via `Address.checksum!/1`, booleans and timestamps passed through
- `getUserReservesData` returns `{[UserReserveData.t()], e_mode_category_id}` — the uint8 e-mode ID is a separate return value
- All functions use `Onchain.ABI.decode_response/2` with string type signatures (no need for `ABI.TypeDecoder`)

**Key discovery:** The [Aave Address Book](https://aave-dao.github.io/aave-address-book/) confirms `0x56b7...` as the official `UI_POOL_DATA_PROVIDER` for AaveV3Ethereum (serves all 4 Ethereum pools). It returns a 40-field AggregatedReserveData. Blockwatch uses a different contract (`0x3F78...`) not in the official address book, with a 41-field layout (has `unbacked` + `virtual_acc_active`, lacks `deficit`). Field differences will need handling during Task 17 migration.

**Files:**
- `lib/onchain/aave/ui_pool_data_provider.ex` (created)
- `lib/onchain/aave/types/aggregated_reserve_data.ex` (created)
- `lib/onchain/aave/types/base_currency_info.ex` (created)
- `lib/onchain/aave/types/user_reserve_data.ex` (created)
- `test/onchain/aave/types/aggregated_reserve_data_test.exs` (created)
- `test/onchain/aave/types/base_currency_info_test.exs` (created)
- `test/onchain/aave/types/user_reserve_data_test.exs` (created)
- `test/onchain/aave/ui_pool_data_provider_integration_test.exs` (created)
- `lib/onchain.ex` (added 4 modules to Discoverable)

---

### Task 9: UserAccountData Response Struct
**Completed** | [D:5/B:8/U:7 → Eff:1.50]

**What was done:**
- Created `Onchain.Aave.Types.UserAccountData` struct with `@enforce_keys` for all 6 Decimal fields
- `from_raw/1` converts a 6-element raw uint256 list using `Math.to_usd/1`, `Math.to_ltv/1`, `Math.to_health_factor/1` with integer guards on all params
- Updated `Onchain.Aave.Pool.get_user_account_data/2` to return `%UserAccountData{}` instead of a plain map
- Removed private `to_account_data_map/1` helper and its `@dialyzer` annotation from Pool
- Updated `@spec` return types and `api()` returns to reference `UserAccountData.t()`
- Updated integration tests to use struct pattern matching instead of map key/size assertions
- Remaining type structs (`AggregatedReserveData`, `BaseCurrencyInfo`, `UserReserveData`) deferred to Task 10 alongside their consumer module

**Files:**
- `lib/onchain/aave/types/user_account_data.ex` (created)
- `test/onchain/aave/types/user_account_data_test.exs` (created)
- `lib/onchain/aave/pool.ex` (modified — struct return, removed private helper)
- `test/onchain/aave/pool_integration_test.exs` (modified — struct assertions)

---

### Task 8b: Split Unit and Integration Tests
**Completed** | [D:2/B:4/U:5 → Eff:2.25]

**What was done:**
- Split all test modules into separate unit and integration test files
- Unit tests (`*_test.exs`) run without RPC credentials
- Integration tests (`*_integration_test.exs`) require `ETHEREUM_API_URL` or `ETH_RPC_URL`
- Covers: RPC, Block, Aave.Contracts, Aave.Math, Aave.Pool

**Files:**
- `test/onchain/rpc_integration_test.exs` (extracted from rpc_test.exs)
- `test/onchain/block_integration_test.exs` (extracted from block_test.exs)
- `test/onchain/aave/contracts_integration_test.exs` (extracted from contracts_test.exs)
- `test/onchain/aave/math_integration_test.exs` (extracted from math_test.exs)
- `test/onchain/aave/pool_integration_test.exs` (extracted from pool_test.exs)

---

### Task 8: Pool Read Calls (`Onchain.Aave.Pool`)
**Completed** | [D:5/B:9/U:8 → Eff:1.70]

**What was done:**
- Created `Onchain.Aave.Pool` with 2-function API: `get_user_account_data/2`, `get_user_account_data!/2`
- Composes 5 modules in a `with` pipeline: `Address.validate → Contracts.address → ABI.encode_call → RPC.eth_call → ABI.decode_response`
- Returns plain map with 6 keys (all `Decimal.t()`): `:total_collateral_base`, `:total_debt_base`, `:available_borrows_base`, `:current_liquidation_threshold`, `:ltv`, `:health_factor`
- Math conversions via `Math.to_usd/1` (10^8), `Math.to_ltv/1` (10^4), `Math.to_health_factor/1` (10^18)
- Options split: `:network` routed to Contracts, remaining opts (`:rpc_url`, `:timeout`, `:block`) to RPC
- Errors pass through unmodified from whichever module fails
- Added descripex `api()` declarations with namespace `/aave/pool`
- Added `Onchain.Aave.Pool` to Discoverable modules list
- Unit tests for input validation and error cases; integration tests for known borrower assertions (map structure, Decimal types, value ranges, Aave invariants), binary address input, zero-position behavior, and bang variant

**Files:**
- `lib/onchain/aave/pool.ex` (created)
- `test/onchain/aave/pool_test.exs` (created)
- `lib/onchain.ex` (added Aave.Pool to Discoverable)

---

### Task 7: Aave Math Conversions (`Onchain.Aave.Math`)
**Completed** | [D:3/B:9/U:8 → Eff:2.83]

**What was done:**
- Created `Onchain.Aave.Math` with 5-function API: `to_usd/1`, `to_ltv/1`, `to_health_factor/1`, `to_ray/1`, `to_wad/1`
- Pure functions with integer guards, each delegating to `Onchain.Decimal.div_pow10/2` with named exponent constants
- Covers all Aave scaling conventions: 10^8 (oracle/USD), 10^4 (LTV/basis points), 10^18 (health factor/wad), 10^27 (ray/interest rates)
- Added descripex `api()` declarations for all 5 public functions with namespace `/aave/math`
- Added `Onchain.Aave.Math` to Discoverable modules list
- 28 tests: 26 unit (real-world Aave values, zero, large uint256, guard clause violations, consistency between to_health_factor/to_wad) + 2 integration (getUserAccountData with to_usd/to_health_factor on live position, getAssetPrice for WETH with to_usd sanity range check)

**Files:**
- `lib/onchain/aave/math.ex` (created)
- `test/onchain/aave/math_test.exs` (created)
- `lib/onchain.ex` (added Aave.Math to Discoverable)

---

### Task 6: Contract Address Registry (`Onchain.Aave.Contracts`)
**Completed** | [D:2/B:8/U:7 → Eff:3.75]

**What was done:**
- Created `Onchain.Aave.Contracts` with 4-function API: `address/2`, `address!/2`, `networks/0`, `contracts/1`
- Pure-function lookup for Aave V3 mainnet contract addresses (pool, pool_addresses_provider, oracle, ui_pool_data_provider)
- Addresses stored as hex strings, returned checksummed via `Onchain.Address.checksum/1`
- Network parameter (`network: :ethereum`) for future multi-chain support — adding networks = adding map entries
- Error tuples: `{:error, {:unknown_contract, key}}` and `{:error, {:unsupported_network, network}}`
- Added descripex `api()` declarations for all 4 public functions with namespace `/aave/contracts`
- Added `Onchain.Aave.Contracts` to Discoverable modules list
- 19 tests: 16 unit (address lookup for all 4 contracts, checksummed validation, error cases, bang variants, networks, contracts listing) + 3 integration (on-chain verification of pool/oracle via PoolAddressesProvider, plus UiPoolDataProvider response check)
- Integration tests call `getPool()` and `getPriceOracle()` on PoolAddressesProvider contract and verify results match stored addresses

**Files:**
- `lib/onchain/aave/contracts.ex` (created)
- `test/onchain/aave/contracts_test.exs` (created)
- `lib/onchain.ex` (added Aave.Contracts to Discoverable)

---

### Task 6b: Block Fetching + Timestamp Binary Search (`Onchain.Block`)
**Completed** | [D:3/B:7/U:8 → Eff:2.50]

**What was done:**
- Added `get_block_by_number/2` + bang variant to `Onchain.RPC` — accepts integer, hex string, or tag ("latest", "finalized", etc.), returns raw block map
- Created `Onchain.Block` with 4-function API: `get_by_number/2`, `get_by_number!/2`, `find_by_timestamp/2`, `find_by_timestamp!/2`
- `get_by_number/2` delegates to RPC, parses hex fields (number, timestamp, hash) into native types, returns plain map
- `find_by_timestamp/2` implements binary search ported from blockwatch's `BlockFromTimestamp` — finds highest block with `timestamp <= target`
- Binary search accepts `:floor`/`:ceil` opts so consumers with cached data skip boundary fetches; defaults to block 1 and "finalized"
- Pure algorithm, no caching — consumers add their own caching layer
- Added descripex `api()` declarations for all 6 new public functions (4 Block + 2 RPC)
- Added `Onchain.Block` to Discoverable modules list
- 22 new tests: 10 unit (input validation + bang variants) + 12 integration (known block fetching, tag support, binary search with exact match, between-blocks, bounds, future timestamp, before-floor error)

**Files:**
- `lib/onchain/block.ex` (created)
- `lib/onchain/rpc.ex` (added get_block_by_number/2 + bang variant)
- `lib/onchain.ex` (added Block to Discoverable)
- `test/onchain/block_test.exs` (created)
- `test/onchain/rpc_test.exs` (added get_block_by_number tests)

---

## Code Review Fixes (Phase 1)

**What was done:**
- `address.ex`: Replaced `Signet.Hex.decode_hex/1` with `Onchain.Hex.decode/1` in private `to_binary/1` for consistency with all other modules
- `rpc.ex`: Replaced 3-clause `ensure_hex_address/1` (18 lines) with 2-line version delegating to `Address.validate/1`. Removed `@dialyzer {:no_match, ensure_hex_address: 1}` annotation (no longer needed). Now also accepts bare hex addresses without 0x prefix.
- `hex_test.exs`: Staged the `apply(Hex, :from_integer, [1.5])` version (standard Elixir idiom for testing guard clauses) instead of variable indirection
- Added test for bare hex address acceptance in `rpc_test.exs` (148 total tests)

---

## Phase 1: Ethereum Primitives

### Task 5: Address Validation + EIP-55 Checksum (`Onchain.Address`)
**Completed** | [D:4/B:9/U:7 → Eff:2.00]

**What was done:**
- Created `Onchain.Address` with 7-function API: `validate/1`, `valid?/1`, `checksum/1`, `checksum!/1`, `normalize/1`, `equal?/2`, `zero?/1`
- Wraps `Signet.Hex.decode_address!/1`, `Signet.Util.checksum_address/1`, and `Onchain.Hex.encode/1`
- Flexible input: all functions accept hex strings (with/without 0x prefix) or 20-byte binaries
- Private `to_binary/1` helper normalizes any valid input before each operation
- Error tuples: `{:error, {:invalid_address, input}}` — bang variant raises `Signet.Hex.HexError`
- EIP-55 test vectors verified against the spec (4 canonical addresses)
- Added descripex `api()` declarations for all 7 public functions
- Added `Onchain.Address` to Discoverable modules list in `Onchain`
- 43 tests covering all functions: validation (13), valid? (6), checksum (6), checksum! (4), normalize (4), equal? (5), zero? (5)

**Files:**
- `lib/onchain/address.ex` (created)
- `test/onchain/address_test.exs` (created)
- `lib/onchain.ex` (added Address to Discoverable)

---

### Task 4: Ethereum JSON-RPC Wrapper (`Onchain.RPC`)
**Completed** | [D:4/B:9/U:9 → Eff:2.25]

**What was done:**
- Created `Onchain.RPC` with 10-function API: 5 RPC methods + bang variants
- `eth_call/3` — read-only contract call, returns raw hex (preserves ABI pipeline)
- `eth_send_raw_transaction/2` — broadcast signed tx, returns tx hash
- `get_balance/2` — account ETH balance in wei as integer
- `block_number/1` — current block height as integer
- `chain_id/1` — network chain ID as integer
- All accept `:rpc_url`, `:timeout`, `:block` options; maps to signet's `send_rpc/3`
- Input validation: addresses (hex string or 20-byte binary), data (0x-prefixed hex)
- Error normalization: JSON-RPC maps pass through as `{:rpc_error, map}`, network errors wrapped
- `@dialyzer` annotations for signet spec mismatches (same pattern as hex.ex, abi.ex)
- Added descripex `api()` declarations for all 10 public functions
- Added `Onchain.RPC` to Discoverable modules list in `Onchain`
- Created `test/support/rpc_case.ex` helper for RPC URL resolution across tests
- Added `elixirc_paths/1` to mix.exs for test/support compilation
- 22 tests: 16 unit (input validation + bang variants) + 6 integration (mainnet RPC)
- Integration tests include full pipeline: `ABI.encode_call → RPC.eth_call → ABI.decode_response`

**Files:**
- `lib/onchain/rpc.ex` (created)
- `test/onchain/rpc_test.exs` (created)
- `test/support/rpc_case.ex` (created)
- `lib/onchain.ex` (added RPC to Discoverable)
- `mix.exs` (added elixirc_paths for test/support)

---

### Task 3: Decimal Precision Helpers (`Onchain.Decimal`)
**Completed** | [D:3/B:8/U:7 → Eff:2.50]

**What was done:**
- Created `Onchain.Decimal` with 3-function API: `to_decimal/2`, `div_pow10/2`, `to_basis_points/1`
- `to_decimal/2` converts raw token integers to `Decimal.t()` given decimal places (18 for ETH, 6 for USDC, 8 for WBTC)
- `div_pow10/2` provides general power-of-10 division with both integer and `%Decimal{}` input heads
- `to_basis_points/1` converts decimal ratios to integer basis points, truncating toward zero
- All functions are pure math with guards — no error tuples, no bang variants needed
- Named constant `@bps_multiplier` for the 10,000 multiplier (no magic numbers)
- Added descripex `api()` declarations for all public functions
- Added `Onchain.Decimal` to Discoverable modules list in `Onchain`
- 25 tests across 4 describe blocks (to_decimal, div_pow10, to_basis_points, roundtrip)

**Files:**
- `lib/onchain/decimal.ex` (created)
- `test/onchain/decimal_test.exs` (created)
- `lib/onchain.ex` (added Decimal to Discoverable)

---

### Task 2: ABI Helpers (`Onchain.ABI`)
**Completed** | [D:3/B:9/U:8 → Eff:2.83]

**What was done:**
- Created `Onchain.ABI` with 4-function API: `encode_call/2`, `encode_call!/2`, `decode_response/2`, `decode_response!/2`
- Wraps the `abi` library (signet dep) with `0x`-prefixed hex string handling via `Onchain.Hex`
- `encode_call/2` takes function signature + params, returns `{:ok, "0x..."}` calldata
- `decode_response/2` takes tuple type signature + hex data, returns `{:ok, [values]}`
- Error tuples use `:encode_error` / `:decode_error` tags; hex failures preserve original `{:invalid_hex, _}` reason
- Bang variants (`!/2`) raise naturally without double rescue
- Added descripex `api()` declarations for all public functions
- Added `Onchain.ABI` to Discoverable modules list in `Onchain`
- 18 tests covering encode, decode, error cases, bang variants, and roundtrip

**Files:**
- `lib/onchain/abi.ex` (created)
- `test/onchain/abi_test.exs` (created)
- `lib/onchain.ex` (added ABI to Discoverable)

---

### Task 1: Hex Utilities (`Onchain.Hex`)
**Completed** | [D:3/B:9/U:8 → Eff:2.83]

**What was done:**
- Created `Onchain.Hex` with 7-function API: `decode/1`, `decode!/1`, `encode/1`, `to_integer/1`, `to_integer!/1`, `from_integer/1`, `valid?/1`
- Delegates to `Signet.Hex` with normalized error tuples: `{:error, {:invalid_hex, input}}`
- Added descripex `api()` declarations for all public functions
- Added `use Descripex.Discoverable` to root `Onchain` module for `Onchain.describe/0-2`
- `valid?/1` uses regex to accept `0x` (empty bytes) while rejecting empty strings
- `to_integer/1` guards against empty string and bare `0x` (rejects instead of Signet's silent `{:ok, 0}`)
- `@dialyzer {:no_match, ...}` for Signet spec mismatch (returns `:invalid_hex`, spec says `:error`)
- 34 tests covering all functions, edge cases, roundtrips, and guard clause enforcement

**Files:**
- `lib/onchain/hex.ex` (created)
- `test/onchain/hex_test.exs` (created)
- `lib/onchain.ex` (added Discoverable)

---

## Project Setup

**Completed** | Initial project creation

**What was done:**
- Created Elixir project with `--sup` flag
- Added signet + decimal as runtime deps
- Added standard dev tooling (styler, credo, dialyxir, doctor, sobelow, ex_unit_json, dialyzer_json, ex_doc)
- Copied ABI files from aave_sim (aave_pool, aave_addresses_provider, aave_price_oracle, chainlink_aggregator)
- Created ROADMAP.md with 17 scored tasks across 4 phases
- Created CLAUDE.md with architecture docs and @include directives
