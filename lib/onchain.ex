defmodule Onchain do
  @moduledoc """
  Shared Ethereum/blockchain library providing read and write capabilities.

  Uses `signet` as the sole Ethereum dependency for RPC calls, ABI encoding,
  transaction signing, and cryptographic operations.

  ## Discovery

  Use `Onchain.describe/0` for a module overview, `Onchain.describe/1` for
  function listings, and `Onchain.describe/2` for full function details.

  ## Consumers

  - **blockwatch** — Aave position monitoring
  - **aave_sim** — Aave position simulation
  - **ccxt_ex** — Exchange trading (DEX signing)
  """

  use Descripex.Discoverable,
    modules: [
      Onchain.Hex,
      Onchain.ABI,
      Onchain.Decimal,
      Onchain.RPC,
      Onchain.Address,
      Onchain.Block,
      Onchain.Aave.Contracts,
      Onchain.Aave.Math,
      Onchain.Aave.Pool,
      Onchain.Aave.UiPoolDataProvider,
      Onchain.Aave.Types.UserAccountData,
      Onchain.Aave.Types.AggregatedReserveData,
      Onchain.Aave.Types.BaseCurrencyInfo,
      Onchain.Aave.Types.UserReserveData
    ]
end
