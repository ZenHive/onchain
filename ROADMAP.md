# Onchain Roadmap

**Vision:** Shared Ethereum library — analytics first, then act. Read + write from day one.

**Completed work:** See [CHANGELOG.md](CHANGELOG.md) for finished tasks.

---

## Current Focus

**Phase 2: Aave Core (Read)** — Read on-chain Aave protocol data. Just completed Task 6b (Block module).

> **Philosophy:** Pure functions first. Consumers call from their own state. No forced state management.

---

## Phase 1: Ethereum Primitives ✅

> 5 tasks complete. See [CHANGELOG.md](CHANGELOG.md#phase-1-ethereum-primitives) for details.
> Built: Hex utilities, ABI encoding, decimal conversion, JSON-RPC wrapper, address validation.

---

## Phase 2: Aave Core (Read)

| # | Task | Status | D | B | U | Eff | Module |
|---|------|--------|---|---|---|-----|--------|
| 6 | Contract address registry (mainnet + network param) | ⬜ | 2 | 8 | 7 | 3.75 🎯 | `Onchain.Aave.Contracts` |
| 6b | Block fetching + timestamp binary search | ✅ | 3 | 7 | 8 | 2.50 🎯 | `Onchain.Block` |
| 7 | Aave math conversions (to_usd, to_ltv, to_ray) | ⬜ | 3 | 9 | 8 | 2.83 🎯 | `Onchain.Aave.Math` |
| 8 | Pool read calls (getUserAccountData) + integration tests | ⬜ | 5 | 9 | 8 | 1.70 🚀 | `Onchain.Aave.Pool` |
| 9 | Response type structs | ⬜ | 5 | 8 | 7 | 1.50 📋 | `Onchain.Aave.Types.*` |
| 10 | UiPoolDataProvider calls + integration tests | ⬜ | 5 | 8 | 7 | 1.50 📋 | `Onchain.Aave.UiPoolDataProvider` |
| 11 | Oracle + Chainlink price feeds + integration tests | ⬜ | 5 | 7 | 6 | 1.30 📋 | `Onchain.Aave.Oracle` |

---

## Phase 3: Aave Actions (Write)

| # | Task | Status | D | B | U | Eff | Module |
|---|------|--------|---|---|---|-----|--------|
| 12 | Transaction signing setup + integration tests | ⬜ | 4 | 9 | 9 | 2.25 🚀 | `Onchain.Signer` |
| 13 | Token approvals (ERC-20 approve) + integration tests | ⬜ | 4 | 8 | 8 | 2.00 🚀 | `Onchain.ERC20` |
| 14 | Pool write calls (supply, borrow, repay, withdraw) + integration tests | ⬜ | 6 | 9 | 8 | 1.42 📋 | `Onchain.Aave.Pool` |

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
    rpc.ex                        # eth_call, eth_send_raw_transaction, get_block_by_number
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
