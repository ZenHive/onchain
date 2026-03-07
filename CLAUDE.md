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
@include ~/.claude/includes/elixir-patterns.md
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
- **defisaver** (planned) — Automated position management via DeFiSaver open-source contracts (Phase 5+)

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

## After Every Task

Update ROADMAP.md (⬜→✅) and CHANGELOG.md (add entry) after completing any roadmap task. This is part of every task, not a separate step.

**Code reviewers**: Verify ROADMAP.md and CHANGELOG.md were updated. Reject reviews where task completion didn't include these updates.

## Testing

- Unit tests for all pure functions (hex, address, decimal, math)
- Integration tests for RPC calls require `ETHEREUM_API_URL` or `ETH_RPC_URL` env var
- Use `Onchain.RPCCase.rpc_url!/0` from `test/support/rpc_case.ex` to resolve RPC URL
- Use `flunk/1` with setup instructions for missing credentials, never silent skip

### Quick Commands

```bash
mix test.json --quiet                          # AI-friendly test output (failures only)
mix test.json --quiet --failed --first-failure # Iterate on failures
mix dialyzer.json --quiet                      # AI-friendly dialyzer output
mix credo --strict --format json               # Static analysis (JSON output)
mix test.json --quiet --exclude integration    # Test all exchanges
```

## Contract Address Verification

When adding or updating addresses in `lib/onchain/aave/contracts.ex`, verify against the **Aave Address Book CSV** — the canonical source maintained by BGD Labs (~5,000 entries covering every Aave contract, asset, and network).

All 4 current project addresses were verified on 2026-03-03.

```bash
# Verify a single address
curl -s "https://raw.githubusercontent.com/bgd-labs/aave-address-book/main/safe.csv" | grep -i "0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2"
# → 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2,AaveV3Ethereum POOL,1

# Verify all project addresses at once
curl -s "https://raw.githubusercontent.com/bgd-labs/aave-address-book/main/safe.csv" | grep -i -E "0x2f39d218|0x87870Bca|0x54586bE6|0x56b7A101"

# Search by contract name
curl -s "https://raw.githubusercontent.com/bgd-labs/aave-address-book/main/safe.csv" | grep "AaveV3Ethereum POOL,"
```

CSV format: `address,name,chainId` (chainId 1 = Ethereum mainnet)

**Other useful resources:**
- **Web UI**: https://aave-dao.github.io/aave-address-book/ (JS-rendered — needs Chrome browser tools, not `web` command)
- **GitHub repo**: https://github.com/bgd-labs/aave-address-book (Solidity interfaces, JSON exports)
- **Etherscan**: https://etherscan.io (verified source code, ABIs, proxy implementations)
