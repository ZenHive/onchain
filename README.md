# Onchain

Pure Elixir Ethereum library. Provides read (`eth_call`) and write (transaction signing) capabilities using [`signet`](https://hex.pm/packages/signet) as the sole Ethereum dependency. No native deps, no Rustler.

## Package Family

| Package | Purpose | Deps |
|---------|---------|------|
| **onchain** (this) | Core Ethereum primitives, RPC, ABI, signing | signet |
| [onchain_aave](https://github.com/ZenHive/onchain_aave) | Aave V3 protocol wrappers | onchain |
| [onchain_evm](https://github.com/ZenHive/onchain_evm) | Rust NIFs: revm simulation, Solidity parsing, codegen | onchain + rustler |
| [onchain_js](https://github.com/ZenHive/onchain_js) | JS bridge: npm packages on the BEAM via QuickBEAM | onchain + quickbeam |

Pick what you need — consumers who only need `eth_call` never compile Rust or Zig.

## Installation

```elixir
def deps do
  [
    {:onchain, "~> 0.4"},
    # Add if you need Aave:
    {:onchain_aave, "~> 0.1"},
    # Add if you need EVM simulation / Solidity parsing:
    {:onchain_evm, "~> 0.1"},
    # Add if you need JS bridge (solc-js, Uniswap SDK, etc.):
    {:onchain_js, "~> 0.1"}
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
| `Onchain.ERC721` | ERC-721 NFT reads (owner_of, token_uri, balance_of, name, symbol, get_approved, approved_for_all?) |
| `Onchain.ERC1155` | ERC-1155 multi-token reads (balance_of, balance_of_batch, uri, approved_for_all?) |

### Chain Intelligence

| Module | Purpose |
|--------|---------|
| `Onchain.Wallet` | Classify address (EOA/contract), native ETH balance |
| `Onchain.Transfer` | Parse ERC-20/721/1155 Transfer events into normalized structs |
| `Onchain.ENS` | ENS name resolution (forward, reverse, text records, contenthash) |

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
