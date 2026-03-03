# Onchain

Shared Ethereum/blockchain library for the portfolio. Provides read (eth_call) and write (transaction signing) capabilities using `signet` as the sole Ethereum dependency.

@include ~/.claude/includes/across-instances.md
@include ~/.claude/includes/critical-rules.md
@include ~/.claude/includes/skills-awareness.md
@include ~/.claude/includes/task-prioritization.md
@include ~/.claude/includes/task-writing.md
@include ~/.claude/includes/web-command.md
@include ~/.claude/includes/code-style.md
@include ~/.claude/includes/development-philosophy.md
@include ~/.claude/includes/documentation-guidelines.md
@include ~/.claude/includes/agent-economy.md
@include ~/.claude/includes/api-integration.md
@include ~/.claude/includes/development-commands.md
@include ~/.claude/includes/elixir-patterns.md
@include ~/.claude/includes/elixir-setup.md
@include ~/.claude/includes/ex-unit-json.md
@include ~/.claude/includes/dialyzer-json.md
@include ~/.claude/includes/library-design.md

## Architecture

- **signet** is the sole Ethereum dep — RPC, ABI encoding, signing, crypto all in one
- Signet wraps **curvy** (pure Elixir secp256k1) internally for signing/key ops — never add curvy as a direct dep
- Consumers configure RPC URL via `config :signet` or pass URL per-call
- Standard error tuples: `{:ok, result} | {:error, {:tag, reason}}`
- Plain structs with `defstruct` + `@enforce_keys`, no private macro deps
- Path dependency in consumers: `{:onchain, path: "../onchain"}`

## Consumers

- **blockwatch** — Aave position monitoring (read-only)
- **aave_sim** — Aave position simulation (read-only)
- **ccxt_ex** — Exchange trading (DEX signing planned)

## Module Layout

```
lib/onchain/
  hex.ex          # hex<->binary, hex<->integer, 0x prefix
  address.ex      # validate, checksum (EIP-55), normalize
  abi.ex          # encode_call/2, decode_response/2
  decimal.ex      # to_decimal/2, to_basis_points/1, div_pow10/2
  rpc.ex          # eth_call, eth_send_raw_transaction
  signer.ex       # key management, transaction signing (Phase 3)
  erc20.ex        # approve, transfer, balanceOf (Phase 3)
  aave/
    math.ex       # to_usd, to_ltv, to_health_factor, to_ray
    contracts.ex  # address registry
    pool.ex       # read + write calls
    oracle.ex     # getAssetPrice + Chainlink
    types/        # response structs
```

## Testing

- Unit tests for all pure functions (hex, address, decimal, math)
- Integration tests for RPC calls require `ETHEREUM_API_URL` or `ETH_RPC_URL` env var
- Use `Onchain.RPCCase.rpc_url!/0` from `test/support/rpc_case.ex` to resolve RPC URL
- Use `flunk/1` with setup instructions for missing credentials, never silent skip
