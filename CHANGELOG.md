# Changelog

Completed roadmap tasks. For upcoming work, see [ROADMAP.md](ROADMAP.md).

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
