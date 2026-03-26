# Onchain

Shared Ethereum/blockchain library for Elixir. Provides read (`eth_call`) and write (transaction signing) capabilities using [`signet`](https://hex.pm/packages/signet) as the sole Ethereum dependency.

## Installation

Add `onchain` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:onchain, "~> 0.3"}
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
| `Onchain.RPC` | Ethereum JSON-RPC wrapper (eth_call, eth_getLogs, receipts, nonces, balances) |
| `Onchain.RPC.Helpers` | Shared RPC helper functions (hex normalization, block tags, tx hash validation) |
| `Onchain.Block` | Block fetching with parsed fields, timestamp-based binary search |
| `Onchain.Contract` | Generic contract call (encode -> eth_call -> decode in one function) |
| `Onchain.Multicall` | Batch multiple eth_call via Multicall3 |
| `Onchain.Log` | Event log parsing against ABI signatures |
| `Onchain.Signer` | Key management and transaction signing |
| `Onchain.ERC20` | ERC-20 read (balanceOf, allowance) and write (transfer, approve) |

### Chain Intelligence

| Module | Purpose |
|--------|---------|
| `Onchain.Wallet` | Classify address (EOA/contract), native ETH balance |
| `Onchain.Transfer` | Parse ERC-20/721/1155 Transfer events into normalized structs |
| `Onchain.ENS` | ENS name resolution (forward, reverse, text records, contenthash) |

### Contract Codegen

| Module | Purpose |
|--------|---------|
| `Onchain.Solidity` | Rustler NIF: Alloy-powered Solidity ABI parser |
| `Onchain.Contract.Generator` | Macro: `.sol` file -> typed Elixir module at compile time |

### Local EVM Simulation

| Module | Purpose |
|--------|---------|
| `Onchain.EVM` | Rustler NIF: revm local EVM execution (fork mainnet, simulate transactions) |
| `Onchain.Trace` | Debug/trace APIs (trace_transaction, trace_call, storage_at) |

### Aave v3

| Module | Purpose |
|--------|---------|
| `Onchain.Aave.Pool` | Pool read + write calls (getUserAccountData, supply, borrow, repay) |
| `Onchain.Aave.Oracle` | Asset price oracle + Chainlink |
| `Onchain.Aave.Math` | USD conversion, LTV, health factor, ray math |
| `Onchain.Aave.Contracts` | Verified address registry (mainnet + multi-chain) |
| `Onchain.Aave.UIPoolDataProvider` | Reserves and user reserves data |
| `Onchain.Aave.Faucet` | Testnet faucet interactions (mint test tokens) |

## Discovery

All modules use [descripex](https://hex.pm/packages/descripex) for self-describing APIs:

```elixir
Onchain.describe()                  # Module overview
Onchain.describe(:hex)              # Function list
Onchain.describe(:hex, :decode)     # Full function details
```

## Testing

```bash
mix test.json --quiet                          # Unit tests (no RPC needed)
mix test.json --quiet --include integration    # Integration tests (requires RPC)
```

Integration tests require an Ethereum RPC endpoint:

```bash
export ETHEREUM_API_URL="https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"
```

Sepolia write tests additionally require `SIGNER_PRIVATE_KEY`.

## License

[MIT](LICENSE)
