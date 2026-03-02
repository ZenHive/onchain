# Changelog

Completed roadmap tasks. For upcoming work, see [ROADMAP.md](ROADMAP.md).

---

## Phase 1: Ethereum Primitives

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
