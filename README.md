# Onchain

Shared Ethereum/blockchain library for Elixir. Provides read (`eth_call`) and write (transaction signing) capabilities using [`signet`](https://hex.pm/packages/signet) as the sole Ethereum dependency.

## Installation

Add `onchain` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:onchain, github: "ZenHive/onchain"}
  ]
end
```

Requires an Ethereum JSON-RPC endpoint. Configure via:

```elixir
# config/config.exs
config :signet, :rpc_url, "https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"
```

Or pass the URL per-call to `Onchain.RPC` functions.

## Modules

### Core

| Module | Purpose |
|--------|---------|
| `Onchain.Hex` | Hex encoding/decoding (hex<->binary, hex<->integer, 0x prefix) |
| `Onchain.ABI` | ABI encoding/decoding for contract calls |
| `Onchain.Address` | Address validation, EIP-55 checksum, normalization |
| `Onchain.Decimal` | Decimal precision helpers (to_decimal, div_pow10, to_basis_points) |
| `Onchain.RPC` | Ethereum JSON-RPC wrapper (eth_call, send_raw_transaction, receipts, nonces) |
| `Onchain.Block` | Block fetching with parsed fields, timestamp-based binary search |
| `Onchain.Contract` | Generic contract read helper |
| `Onchain.Multicall` | Batch multiple eth_call via Multicall3 |
| `Onchain.Log` | Event log parsing |
| `Onchain.Signer` | Key management and transaction signing |
| `Onchain.ERC20` | ERC-20 read (balanceOf, allowance) and write (transfer, approve) |

### Aave v3

| Module | Purpose |
|--------|---------|
| `Onchain.Aave.Pool` | Pool read + write calls (getUserAccountData, supply, borrow, repay) |
| `Onchain.Aave.Oracle` | Asset price oracle + Chainlink |
| `Onchain.Aave.Math` | USD conversion, LTV, health factor, ray math |
| `Onchain.Aave.Contracts` | Verified address registry (Ethereum mainnet) |
| `Onchain.Aave.UIPoolDataProvider` | Reserves and user reserves data |

## Discovery

All modules use [descripex](https://hex.pm/packages/descripex) for self-describing APIs:

```elixir
Onchain.describe()                  # Module overview
Onchain.describe(:hex)              # Function list
Onchain.describe(:hex, :decode)     # Full function details
```

## Testing

```bash
mix test                    # Unit tests (no RPC needed)
mix test --include integration  # Integration tests (requires RPC)
```

Integration tests require an Ethereum RPC endpoint:

```bash
export ETHEREUM_API_URL="https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"
```

## License

[MIT](LICENSE)
