defmodule Onchain.Contract do
  @moduledoc """
  Generic contract call: ABI encode → eth_call → ABI decode in one function.

  Eliminates the 3-step `with` chain every consumer writes for contract reads.
  Takes a contract address, function signature, params, and return type — returns
  decoded values.

  ## Error Format

  Errors pass through from the underlying module that failed:

  | Source | Error Shape |
  |--------|-------------|
  | `Onchain.Address.validate/1` | `{:error, {:invalid_address, input}}` |
  | `Onchain.ABI.encode_call/2` | `{:error, {:encode_error, reason}}` |
  | `Onchain.RPC.eth_call/3` | `{:error, {:rpc_error, map}}` |
  | `Onchain.ABI.decode_response/2` | `{:error, {:decode_error, reason}}` |

  ## Functions

  | Function | Purpose |
  |----------|---------|
  | `call/5` | Generic contract read → decoded values list |
  | `call!/5` | Same, raises on error |
  """

  use Descripex, namespace: "/contract"

  alias Onchain.ABI
  alias Onchain.Address
  alias Onchain.RPC

  # ABI.decode_response/2 has upstream spec mismatch (success typing is no_return()
  # due to Signet.Hex spec issues). This cascades through the entire call chain:
  # 1. {:ok, values} pattern in call/5 appears unreachable → no_match
  # 2. Bang variant calls it, inherits "no return" → no_return, no_match, no_contracts
  # Same root cause as @dialyzer annotations in abi.ex and pool.ex.
  @dialyzer {:no_match, [call: 5, call!: 5]}
  @dialyzer {:no_return, [call!: 4, call!: 5]}
  @dialyzer {:no_contracts, [call!: 4, call!: 5]}

  # --- call ---

  api(:call, "Execute a read-only contract call: encode → eth_call → decode.",
    params: [
      address: [
        kind: :value,
        description: "Contract address as 0x hex string or 20-byte binary"
      ],
      signature: [
        kind: :value,
        description: ~s{Function signature, e.g. "balanceOf(address)"}
      ],
      params: [
        kind: :value,
        description: "List of parameter values matching the signature"
      ],
      return_type: [
        kind: :value,
        description: ~s{Tuple type signature for decoding, e.g. "(uint256)" or "(uint256,bool)"}
      ],
      opts: [
        kind: :value,
        default: [],
        description: "Options: :rpc_url, :timeout, :block"
      ]
    ],
    returns: %{
      type: "{:ok, [decoded_values]} | {:error, term()}",
      description: "List of decoded return values from the contract call",
      example: ~s|{:ok, [1000000]}|
    }
  )

  @spec call(String.t() | binary(), String.t(), list(), String.t(), keyword()) ::
          {:ok, list()} | {:error, term()}
  def call(address, signature, params, return_type, opts \\ []) do
    with {:ok, addr_bin} <- Address.validate(address),
         {:ok, calldata} <- ABI.encode_call(signature, params),
         {:ok, hex_result} <- RPC.eth_call(addr_bin, calldata, opts) do
      ABI.decode_response(return_type, hex_result)
    end
  end

  # --- call! ---

  api(:call!, "Execute a read-only contract call. Raises on error.",
    params: [
      address: [
        kind: :value,
        description: "Contract address as 0x hex string or 20-byte binary"
      ],
      signature: [
        kind: :value,
        description: ~s{Function signature, e.g. "balanceOf(address)"}
      ],
      params: [
        kind: :value,
        description: "List of parameter values matching the signature"
      ],
      return_type: [
        kind: :value,
        description: ~s{Tuple type signature for decoding, e.g. "(uint256)"}
      ],
      opts: [
        kind: :value,
        default: [],
        description: "Options: :rpc_url, :timeout, :block"
      ]
    ],
    returns: %{
      type: "[decoded_values]",
      description: "List of decoded return values from the contract call"
    }
  )

  @spec call!(String.t() | binary(), String.t(), list(), String.t(), keyword()) :: list()
  def call!(address, signature, params, return_type, opts \\ []) do
    case call(address, signature, params, return_type, opts) do
      {:ok, values} -> values
      {:error, reason} -> raise "contract call failed: #{inspect(reason)}"
    end
  end
end
