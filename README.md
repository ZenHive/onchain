# Onchain

Pure Elixir Ethereum library. Provides read (`eth_call`) and write (transaction signing) capabilities using [`signet`](https://hex.pm/packages/signet) as the sole Ethereum dependency. No native deps, no Rustler.

## Package Family

| Package | Purpose | Deps |
|---------|---------|------|
| **onchain** (this) | Core Ethereum primitives, RPC, ABI, signing | signet |
| [onchain_aave](https://github.com/ZenHive/onchain_aave) | Aave V3 protocol wrappers | onchain |
| [onchain_evm](https://github.com/ZenHive/onchain_evm) | Rust NIFs: revm simulation, Solidity parsing, codegen | onchain + rustler |
| [onchain_js](https://github.com/ZenHive/onchain_js) | JS bridge: npm packages on the BEAM via QuickBEAM | onchain + quickbeam |
| [onchain_tempo](https://github.com/ZenHive/onchain_tempo) | Tempo chain primitives: 0x76 transactions, TIP-20 encoding | onchain |

Pick what you need — consumers who only need `eth_call` never compile Rust or Zig.

## Installation

```elixir
def deps do
  [
    {:onchain, "~> 0.5"},
    # Add if you need Aave:
    {:onchain_aave, "~> 0.1"},
    # Add if you need EVM simulation / Solidity parsing:
    {:onchain_evm, "~> 0.1"},
    # Add if you need JS bridge (solc-js, Uniswap SDK, etc.):
    {:onchain_js, "~> 0.1"},
    # Add if you need Tempo chain (0x76 transactions, TIP-20 tokens):
    {:onchain_tempo, "~> 0.1"}
  ]
end
```

Requires an Ethereum JSON-RPC endpoint. Configure via:

```elixir
# config/config.exs
config :signet, :rpc_url, "https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"
```

Or pass the URL per-call to `Onchain.RPC` functions.

## Quick Start

```elixir
# Read an ERC-20 token balance (USDC on mainnet)
usdc = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
{:ok, balance} = Onchain.ERC20.balance_of(usdc, "0xYourAddress")

# Resolve an ENS name
{:ok, address} = Onchain.ENS.resolve("vitalik.eth")

# Generic contract call (encode -> eth_call -> decode)
{:ok, [name]} = Onchain.Contract.call(usdc, "name()", [], "(string)")

# All functions have bang variants that raise on error
balance = Onchain.ERC20.balance_of!(usdc, "0xYourAddress")
```

## Modules

### Core

| Module | Purpose |
|--------|---------|
| `Onchain.Hex` | Hex encoding/decoding (hex<->binary, hex<->integer, 0x prefix) |
| `Onchain.ABI` | ABI encoding/decoding for contract calls |
| `Onchain.Address` | Address validation, EIP-55 checksum, normalization |
| `Onchain.Decimal` | Decimal precision helpers (to_decimal, div_pow10, to_basis_points) |
| `Onchain.RPC` | Ethereum JSON-RPC wrapper (eth_call, eth_getLogs, receipts, nonces, balances; `call/3` for any other method) |
| `Onchain.RPC.Helpers` | Shared RPC helper functions (hex normalization, block tags, tx hash validation) |
| `Onchain.Block` | Block fetching with parsed fields, timestamp-based binary search |
| `Onchain.Contract` | Generic contract call (encode -> eth_call -> decode in one function) |
| `Onchain.Multicall` | Batch multiple eth_call via Multicall3 |
| `Onchain.Log` | Event log parsing against ABI signatures |
| `Onchain.Signer` | Key management and transaction signing |
| `Onchain.ERC20` | ERC-20 read (balanceOf, allowance, decimals, symbol, totalSupply) and write (transfer, approve) |
| `Onchain.ERC721` | ERC-721 NFT reads (owner_of, token_uri, balance_of, name, symbol, get_approved, approved_for_all?) |
| `Onchain.ERC1155` | ERC-1155 multi-token reads (balance_of, balance_of_batch, uri, approved_for_all?) |

### Chain Intelligence

| Module | Purpose |
|--------|---------|
| `Onchain.Wallet` | Classify address (EOA/contract), native ETH balance |
| `Onchain.Transfer` | Parse ERC-20/721/1155 Transfer events into normalized structs |
| `Onchain.ENS` | ENS name resolution (forward, reverse, text records, contenthash) |
| `Onchain.Subscription` | Real-time streaming via eth_subscribe (newHeads, pendingTx, logs) |

All public functions have `function!/1` bang variants that raise on error instead of returning `{:error, reason}` tuples.

## Real-time Subscriptions

Stream new blocks, pending transactions, and event logs via WebSocket:

```elixir
# Connect to a WebSocket endpoint
{:ok, sub} = Onchain.Subscription.connect("wss://eth-mainnet.g.alchemy.com/v2/KEY")

# Subscribe to new block headers
{:ok, sub_id} = Onchain.Subscription.subscribe(sub, :new_heads)

# Events arrive as messages to the calling process
receive do
  {:subscription, {:new_heads, ^sub_id, head}} ->
    IO.inspect(head.number, label: "new block")
end

# Or provide a custom handler
{:ok, sub} = Onchain.Subscription.connect("wss://...",
  handler: fn {:new_heads, _id, head} -> Logger.info("Block #{head.number}") end
)

# Subscribe to filtered event logs
{:ok, _} = Onchain.Subscription.subscribe(sub, {:logs, %{
  address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
  topics: [Onchain.Transfer.transfer_topics()]
}})

# Clean up
Onchain.Subscription.unsubscribe(sub, sub_id)
Onchain.Subscription.close(sub)
```

Requires a WebSocket-capable endpoint (`wss://` or `ws://`), separate from the HTTP RPC URL.

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

WebSocket subscription tests require a WebSocket endpoint:

```bash
export ETHEREUM_WS_URL="wss://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"
```

Sepolia write tests additionally require `ETH_SEPOLIA_RPC_URL` and `SIGNER_PRIVATE_KEY`.

## License

[MIT](LICENSE)
