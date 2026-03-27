defmodule Onchain do
  @moduledoc """
  Shared Ethereum/blockchain library providing read and write capabilities.

  Uses `signet` as the sole Ethereum dependency for RPC calls, ABI encoding,
  transaction signing, and cryptographic operations.

  ## Discovery

  Use `Onchain.describe/0` for a module overview, `Onchain.describe/1` for
  function listings, and `Onchain.describe/2` for full function details.

  """

  use Descripex.Discoverable,
    modules: [
      Onchain.Hex,
      Onchain.ABI,
      Onchain.Address,
      Onchain.Decimal,
      Onchain.RPC,
      Onchain.Block,
      Onchain.Contract,
      Onchain.ERC20,
      Onchain.ENS,
      Onchain.Log,
      Onchain.Multicall,
      Onchain.Signer,
      Onchain.Transfer,
      Onchain.Wallet
    ]
end
