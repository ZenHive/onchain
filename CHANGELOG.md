# Changelog

Completed roadmap tasks. For upcoming work, see [ROADMAP.md](ROADMAP.md).

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
