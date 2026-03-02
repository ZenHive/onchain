defmodule Onchain do
  @moduledoc """
  Shared Ethereum/blockchain library providing read and write capabilities.

  Uses `signet` as the sole Ethereum dependency for RPC calls, ABI encoding,
  transaction signing, and cryptographic operations.

  ## Consumers

  - **blockwatch** — Aave position monitoring
  - **aave_sim** — Aave position simulation
  - **ccxt_ex** — Exchange trading (DEX signing)
  """
end
