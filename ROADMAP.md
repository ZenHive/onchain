# Onchain Roadmap

**Vision:** Shared Ethereum library — analytics first, then act. Read + write from day one.

**Completed work:** See [CHANGELOG.md](CHANGELOG.md) for finished tasks.

---

## Current Focus

**Phase 1: Ethereum Primitives** — Foundation modules that everything else builds on.

> **Philosophy:** Pure functions first. Consumers call from their own state. No forced state management.

### Current Tasks

| # | Task | Status | D | B | U | Eff | Module |
|---|------|--------|---|---|---|-----|--------|
| 1 | Hex utilities (hex↔binary, hex↔integer, 0x prefix) | ✅ | 3 | 9 | 8 | 2.83 🎯 | `Onchain.Hex` |
| 2 | ABI helpers (wrapping signet's `abi` pkg) | ✅ | 3 | 9 | 8 | 2.83 🎯 | `Onchain.ABI` |
| 3 | Decimal precision helpers (to_decimal, div_pow10) | ⬜ | 3 | 8 | 7 | 2.50 🎯 | `Onchain.Decimal` |
| 4 | RPC wrapper (signet's RPC client) | ⬜ | 4 | 9 | 9 | 2.25 🚀 | `Onchain.RPC` |
| 5 | Address validation + EIP-55 checksum | ⬜ | 4 | 9 | 7 | 2.00 🚀 | `Onchain.Address` |

### Priority Order

1. ~~`Onchain.Hex` [Eff:2.83] — everything depends on hex conversion~~
2. ~~`Onchain.ABI` [Eff:2.83] — needed for all contract calls~~
3. `Onchain.Decimal` [Eff:2.50] — needed for all value conversions
4. `Onchain.RPC` [Eff:2.25] — needed for any on-chain read/write
5. `Onchain.Address` [Eff:2.00] — needed for contract interaction

---

## Phase 2: Aave Core (Read)

| # | Task | Status | D | B | U | Eff | Module |
|---|------|--------|---|---|---|-----|--------|
| 6 | Contract address registry (mainnet + network param) | ⬜ | 2 | 8 | 7 | 3.75 🎯 | `Onchain.Aave.Contracts` |
| 7 | Aave math conversions (to_usd, to_ltv, to_ray) | ⬜ | 3 | 9 | 8 | 2.83 🎯 | `Onchain.Aave.Math` |
| 8 | Pool read calls (getUserAccountData) | ⬜ | 5 | 9 | 8 | 1.70 🚀 | `Onchain.Aave.Pool` |
| 9 | Response type structs | ⬜ | 5 | 8 | 7 | 1.50 📋 | `Onchain.Aave.Types.*` |
| 10 | UiPoolDataProvider calls | ⬜ | 5 | 8 | 7 | 1.50 📋 | `Onchain.Aave.UiPoolDataProvider` |
| 11 | Oracle + Chainlink price feeds | ⬜ | 5 | 7 | 6 | 1.30 📋 | `Onchain.Aave.Oracle` |

---

## Phase 3: Aave Actions (Write)

| # | Task | Status | D | B | U | Eff | Module |
|---|------|--------|---|---|---|-----|--------|
| 12 | Transaction signing setup | ⬜ | 4 | 9 | 9 | 2.25 🚀 | `Onchain.Signer` |
| 13 | Token approvals (ERC-20 approve) | ⬜ | 4 | 8 | 8 | 2.00 🚀 | `Onchain.ERC20` |
| 14 | Pool write calls (supply, borrow, repay, withdraw) | ⬜ | 6 | 9 | 8 | 1.42 📋 | `Onchain.Aave.Pool` |

---

## Phase 4: Consumer Migration

| # | Task | Status | D | B | U | Eff |
|---|------|--------|---|---|---|-----|
| 15 | ccxt_ex integration (path dep, shared types) | ⬜ | 2 | 5 | 4 | 2.25 🚀 |
| 16 | aave_sim migration | ⬜ | 6 | 8 | 7 | 1.25 📋 |
| 17 | blockwatch migration | ⬜ | 7 | 9 | 8 | 1.21 📋 |

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

## Module Structure

```
lib/
  onchain.ex
  onchain/
    hex.ex                        # hex↔binary, hex↔integer, 0x prefix
    address.ex                    # validate, checksum (EIP-55), normalize
    abi.ex                        # encode_call/2, decode_response/2
    decimal.ex                    # to_decimal/2, to_basis_points/1, div_pow10/2
    rpc.ex                        # eth_call, eth_send_raw_transaction
    signer.ex                     # key management, transaction signing
    erc20.ex                      # approve, transfer, balanceOf
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
priv/
  abis/
    aave_pool.json
    aave_addresses_provider.json
    aave_price_oracle.json
    chainlink_aggregator.json
```
