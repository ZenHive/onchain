defmodule Onchain.Aave.Contracts do
  @moduledoc """
  Aave V3 contract address registry.

  Pure-function lookup for known Aave protocol contract addresses. All other
  Aave modules (Pool, Oracle, UiPoolDataProvider) depend on this for addresses.

  ## Supported Networks

  Currently `:ethereum` mainnet only. Adding networks = adding map entries.

  ## Error Format

  - Unknown contract: `{:error, {:unknown_contract, key}}`
  - Unsupported network: `{:error, {:unsupported_network, network}}`

  ## Functions

  | Function | Purpose |
  |----------|---------|
  | `address/2` | Look up a contract's checksummed address |
  | `address!/2` | Same, raises on error |
  | `networks/0` | List supported networks |
  | `contracts/1` | List contract keys for a network |
  """

  use Descripex, namespace: "/aave/contracts"

  @addresses %{
    ethereum: %{
      pool_addresses_provider: "0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e",
      pool: "0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2",
      oracle: "0x54586bE62E3c3580375aE3723C145253060Ca0C2",
      ui_pool_data_provider: "0x56b7A1012765C285afAC8b8F25C69Bf10ccfE978"
    }
  }

  # --- address ---

  api(:address, "Look up a contract's EIP-55 checksummed address.",
    params: [
      contract: [kind: :value, description: "Contract key atom, e.g. :pool, :oracle"],
      opts: [kind: :value, default: [], description: "Options: [network: :ethereum]"]
    ],
    returns: %{
      type: "{:ok, String.t()} | {:error, term()}",
      description: "Checksummed hex address",
      example: "0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2"
    }
  )

  @spec address(atom(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def address(contract, opts \\ []) do
    network = Keyword.get(opts, :network, :ethereum)

    case @addresses do
      %{^network => %{^contract => hex}} -> Onchain.Address.checksum(hex)
      %{^network => %{}} -> {:error, {:unknown_contract, contract}}
      %{} -> {:error, {:unsupported_network, network}}
    end
  end

  # --- address! ---

  api(:address!, "Look up a contract's checksummed address. Raises on error.",
    params: [
      contract: [kind: :value, description: "Contract key atom, e.g. :pool, :oracle"],
      opts: [kind: :value, default: [], description: "Options: [network: :ethereum]"]
    ],
    returns: %{
      type: :string,
      description: "Checksummed hex address"
    }
  )

  @spec address!(atom(), keyword()) :: String.t()
  def address!(contract, opts \\ []) do
    case address(contract, opts) do
      {:ok, addr} -> addr
      {:error, reason} -> raise "address lookup failed: #{inspect(reason)}"
    end
  end

  # --- networks ---

  api(:networks, "List supported networks.",
    params: [],
    returns: %{
      type: "[atom()]",
      description: "List of network atoms",
      example: "[:ethereum]"
    }
  )

  @spec networks() :: [atom()]
  def networks, do: Map.keys(@addresses)

  # --- contracts ---

  api(:contracts, "List available contract keys for a network.",
    params: [
      opts: [kind: :value, default: [], description: "Options: [network: :ethereum]"]
    ],
    returns: %{
      type: "{:ok, [atom()]} | {:error, {:unsupported_network, atom()}}",
      description: "List of contract key atoms"
    }
  )

  @spec contracts(keyword()) :: {:ok, [atom()]} | {:error, {:unsupported_network, atom()}}
  def contracts(opts \\ []) do
    network = Keyword.get(opts, :network, :ethereum)

    case @addresses do
      %{^network => network_map} -> {:ok, Map.keys(network_map)}
      %{} -> {:error, {:unsupported_network, network}}
    end
  end
end
