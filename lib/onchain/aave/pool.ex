defmodule Onchain.Aave.Pool do
  @moduledoc """
  High-level Aave V3 Pool read operations.

  Composes `Address`, `Contracts`, `ABI`, `RPC`, and `Math` into single-call
  functions that return converted `Decimal` values. Consumers don't need to
  manually encode ABI calls, make RPC requests, and decode responses.

  ## Error Format

  Errors pass through from the underlying module that failed:

  | Source | Error Shape |
  |--------|-------------|
  | `Onchain.Address.validate/1` | `{:error, {:invalid_address, input}}` |
  | `Onchain.Aave.Contracts.address/2` | `{:error, {:unsupported_network, network}}` |
  | `Onchain.ABI.encode_call/2` | `{:error, {:encode_error, reason}}` |
  | `Onchain.RPC.eth_call/3` | `{:error, {:rpc_error, map}}` |
  | `Onchain.ABI.decode_response/2` | `{:error, {:decode_error, reason}}` |

  ## Functions

  | Function | Purpose |
  |----------|---------|
  | `get_user_account_data/2` | Full position summary as `UserAccountData` struct |
  | `get_user_account_data!/2` | Same, raises on error |
  """

  use Descripex, namespace: "/aave/pool"

  alias Onchain.Aave.Contracts
  alias Onchain.Aave.Types.UserAccountData
  alias Onchain.ABI
  alias Onchain.Address
  alias Onchain.RPC

  # ABI.decode_response/2 has upstream spec mismatch (success typing is no_return()
  # due to Signet.Hex spec issues). This cascades through the entire call chain:
  # 1. {:ok, values} pattern in get_user_account_data/2 appears unreachable → no_match
  # 2. Bang variant calls it, inherits "no return" → no_return, no_match, no_contracts
  # Same root cause as @dialyzer annotations in abi.ex.
  @dialyzer {:no_match, [get_user_account_data: 2, get_user_account_data!: 2]}
  @dialyzer {:no_return, [get_user_account_data!: 1, get_user_account_data!: 2]}
  @dialyzer {:no_contracts, [get_user_account_data!: 1, get_user_account_data!: 2]}

  @user_account_data_response "(uint256,uint256,uint256,uint256,uint256,uint256)"

  # --- get_user_account_data ---

  api(:get_user_account_data, "Fetch a user's full Aave V3 position as converted Decimal values.",
    params: [
      user_address: [
        kind: :value,
        description: "User address as 0x hex string or 20-byte binary"
      ],
      opts: [
        kind: :value,
        default: [],
        description: "Options: :network (default :ethereum), :rpc_url, :timeout, :block"
      ]
    ],
    returns: %{
      type: "{:ok, UserAccountData.t()} | {:error, term()}",
      description:
        "UserAccountData struct with Decimal values for collateral, debt, borrows, thresholds, and health factor",
      example: ~s[%UserAccountData{total_collateral_base: Decimal.new("1234.56"), health_factor: Decimal.new("1.5"), ...}]
    }
  )

  @spec get_user_account_data(String.t() | binary(), keyword()) ::
          {:ok, UserAccountData.t()} | {:error, term()}
  def get_user_account_data(user_address, opts \\ []) do
    {network_opts, rpc_opts} = split_opts(opts)

    with {:ok, user_bin} <- Address.validate(user_address),
         {:ok, pool_addr} <- Contracts.address(:pool, network_opts),
         {:ok, calldata} <- ABI.encode_call("getUserAccountData(address)", [user_bin]),
         {:ok, hex_result} <- RPC.eth_call(pool_addr, calldata, rpc_opts),
         {:ok, values} <- ABI.decode_response(@user_account_data_response, hex_result) do
      {:ok, UserAccountData.from_raw(values)}
    end
  end

  # --- get_user_account_data! ---

  api(:get_user_account_data!, "Fetch a user's full Aave V3 position. Raises on error.",
    params: [
      user_address: [
        kind: :value,
        description: "User address as 0x hex string or 20-byte binary"
      ],
      opts: [
        kind: :value,
        default: [],
        description: "Options: :network (default :ethereum), :rpc_url, :timeout, :block"
      ]
    ],
    returns: %{
      type: "UserAccountData.t()",
      description:
        "UserAccountData struct with Decimal values for collateral, debt, borrows, thresholds, and health factor"
    }
  )

  @spec get_user_account_data!(String.t() | binary(), keyword()) :: UserAccountData.t()
  def get_user_account_data!(user_address, opts \\ []) do
    case get_user_account_data(user_address, opts) do
      {:ok, data} -> data
      {:error, reason} -> raise "get_user_account_data failed: #{inspect(reason)}"
    end
  end

  # --- Private helpers ---

  @doc false
  # Separates :network option (for Contracts) from RPC options (:rpc_url, :timeout, :block).
  @spec split_opts(keyword()) :: {keyword(), keyword()}
  defp split_opts(opts) do
    {network_val, rpc_opts} = Keyword.pop(opts, :network)

    network_opts =
      if network_val do
        [network: network_val]
      else
        []
      end

    {network_opts, rpc_opts}
  end
end
