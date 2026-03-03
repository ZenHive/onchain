# Onchain

Shared Ethereum/blockchain library for the portfolio. Provides read (`eth_call`) and write (transaction signing) capabilities using `signet` as the sole Ethereum dependency.

## Installation

Path dependency in consumer projects:

```elixir
def deps do
  [
    {:onchain, path: "../onchain"}
  ]
end
```

## Modules

| Module | Purpose |
|--------|---------|
| `Onchain.Hex` | Hex encoding/decoding (hex<->binary, hex<->integer, 0x prefix) |
| `Onchain.ABI` | ABI encoding/decoding (encode_call, decode_response for contract calls) |
| `Onchain.Decimal` | Decimal precision helpers (to_decimal, div_pow10, to_basis_points) |
| `Onchain.RPC` | Ethereum JSON-RPC wrapper (eth_call, get_balance, block_number, chain_id, get_block_by_number) |
| `Onchain.Address` | Address validation, EIP-55 checksum, normalization, comparison |
| `Onchain.Block` | Block fetching with parsed fields, timestamp-based binary search |

## Discovery

All modules use [descripex](https://hex.pm/packages/descripex) for self-describing APIs:

```elixir
Onchain.describe()                  # Module overview
Onchain.describe(:hex)              # Function list
Onchain.describe(:hex, :decode)     # Full function details
```

## Consumers

- **blockwatch** -- Aave position monitoring (read-only)
- **aave_sim** -- Aave position simulation (read-only)
- **ccxt_ex** -- Exchange trading (DEX signing planned)

