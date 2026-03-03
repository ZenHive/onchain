# Changelog

Completed roadmap tasks. For upcoming work, see [ROADMAP.md](ROADMAP.md).

---

## Phase 2: Aave Core (Read)

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
