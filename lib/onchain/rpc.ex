defmodule Onchain.RPC do
  @moduledoc """
  Ethereum JSON-RPC wrapper using signet's RPC client.

  Provides a curated API for common Ethereum RPC methods with consistent
  error tuples and option handling. All functions accept `:rpc_url`,
  `:timeout`, and `:block` options.

  ## Error Format

  - Input validation: `{:error, {:invalid_address, input}}` or `{:error, {:invalid_data, input}}`
  - RPC/network errors: `{:error, {:rpc_error, %{code: integer, message: string}}}`

  For RPC errors, the map always has at least a `:message` key. JSON-RPC error
  responses from the node include `:code`; network/transport errors are wrapped
  with `inspect/1` as the message.

  ## Functions

  | Function | Purpose |
  |----------|---------|
  | `eth_call/3` | Read-only contract call → raw hex response |
  | `eth_call!/3` | Same, raises on error |
  | `eth_send_raw_transaction/2` | Broadcast signed tx → tx hash |
  | `eth_send_raw_transaction!/2` | Same, raises on error |
  | `get_balance/2` | Account ETH balance in wei |
  | `get_balance!/2` | Same, raises on error |
  | `block_number/1` | Current block height |
  | `block_number!/1` | Same, raises on error |
  | `chain_id/1` | Network chain ID |
  | `chain_id!/1` | Same, raises on error |
  """

  use Descripex, namespace: "/rpc"

  @default_timeout_ms 30_000

  # --- eth_call ---

  api(:eth_call, "Execute a read-only contract call (eth_call).",
    params: [
      address: [kind: :value, description: "Contract address as 0x hex string or 20-byte binary"],
      data: [kind: :value, description: "0x-prefixed hex-encoded calldata (from ABI.encode_call)"],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout, :block"]
    ],
    returns: %{
      type: "{:ok, hex_string} | {:error, term}",
      description: "Raw 0x-prefixed hex response from the contract",
      example: "0x000000000000000000000000000000000000000000000000000000000000002a"
    }
  )

  @spec eth_call(String.t() | binary(), String.t(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def eth_call(address, data, opts \\ []) do
    with {:ok, hex_addr} <- ensure_hex_address(address),
         {:ok, hex_data} <- ensure_hex_data(data) do
      block = Keyword.get(opts, :block, "latest")

      call_params = %{"to" => hex_addr, "data" => hex_data}

      do_rpc("eth_call", [call_params, block], to_signet_opts(opts))
    end
  end

  # --- eth_call! ---

  api(:eth_call!, "Execute a read-only contract call. Raises on error.",
    params: [
      address: [kind: :value, description: "Contract address as 0x hex string or 20-byte binary"],
      data: [kind: :value, description: "0x-prefixed hex-encoded calldata"],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout, :block"]
    ],
    returns: %{type: :string, description: "Raw 0x-prefixed hex response"}
  )

  @spec eth_call!(String.t() | binary(), String.t(), keyword()) :: String.t()
  def eth_call!(address, data, opts \\ []) do
    case eth_call(address, data, opts) do
      {:ok, result} -> result
      {:error, reason} -> raise "eth_call failed: #{inspect(reason)}"
    end
  end

  # --- eth_send_raw_transaction ---

  api(:eth_send_raw_transaction, "Broadcast a signed transaction.",
    params: [
      data: [kind: :value, description: "0x-prefixed hex-encoded signed transaction"],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout"]
    ],
    returns: %{
      type: "{:ok, tx_hash} | {:error, term}",
      description: "Transaction hash as 0x hex string",
      example: "0xabc123..."
    }
  )

  @spec eth_send_raw_transaction(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def eth_send_raw_transaction(data, opts \\ []) do
    with {:ok, _hex_data} <- ensure_hex_data(data) do
      do_rpc("eth_sendRawTransaction", [data], to_signet_opts(opts))
    end
  end

  # --- eth_send_raw_transaction! ---

  api(:eth_send_raw_transaction!, "Broadcast a signed transaction. Raises on error.",
    params: [
      data: [kind: :value, description: "0x-prefixed hex-encoded signed transaction"],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout"]
    ],
    returns: %{type: :string, description: "Transaction hash as 0x hex string"}
  )

  @spec eth_send_raw_transaction!(String.t(), keyword()) :: String.t()
  def eth_send_raw_transaction!(data, opts \\ []) do
    case eth_send_raw_transaction(data, opts) do
      {:ok, result} -> result
      {:error, reason} -> raise "eth_send_raw_transaction failed: #{inspect(reason)}"
    end
  end

  # --- get_balance ---

  api(:get_balance, "Get the ETH balance of an address in wei.",
    params: [
      address: [kind: :value, description: "Account address as 0x hex string or 20-byte binary"],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout, :block"]
    ],
    returns: %{
      type: "{:ok, non_neg_integer} | {:error, term}",
      description: "Balance in wei"
    }
  )

  @spec get_balance(String.t() | binary(), keyword()) :: {:ok, non_neg_integer()} | {:error, term()}
  def get_balance(address, opts \\ []) do
    with {:ok, hex_addr} <- ensure_hex_address(address) do
      block = Keyword.get(opts, :block, "latest")

      do_rpc("eth_getBalance", [hex_addr, block], Keyword.put(to_signet_opts(opts), :decode, :hex_unsigned))
    end
  end

  # --- get_balance! ---

  api(:get_balance!, "Get the ETH balance of an address in wei. Raises on error.",
    params: [
      address: [kind: :value, description: "Account address as 0x hex string or 20-byte binary"],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout, :block"]
    ],
    returns: %{type: :non_neg_integer, description: "Balance in wei"}
  )

  @spec get_balance!(String.t() | binary(), keyword()) :: non_neg_integer()
  def get_balance!(address, opts \\ []) do
    case get_balance(address, opts) do
      {:ok, result} -> result
      {:error, reason} -> raise "get_balance failed: #{inspect(reason)}"
    end
  end

  # --- block_number ---

  api(:block_number, "Get the current block height.",
    params: [
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout"]
    ],
    returns: %{
      type: "{:ok, non_neg_integer} | {:error, term}",
      description: "Current block number"
    }
  )

  @spec block_number(keyword()) :: {:ok, non_neg_integer()} | {:error, term()}
  def block_number(opts \\ []) do
    do_rpc("eth_blockNumber", [], Keyword.put(to_signet_opts(opts), :decode, :hex_unsigned))
  end

  # --- block_number! ---

  api(:block_number!, "Get the current block height. Raises on error.",
    params: [
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout"]
    ],
    returns: %{type: :non_neg_integer, description: "Current block number"}
  )

  @spec block_number!(keyword()) :: non_neg_integer()
  def block_number!(opts \\ []) do
    case block_number(opts) do
      {:ok, result} -> result
      {:error, reason} -> raise "block_number failed: #{inspect(reason)}"
    end
  end

  # --- chain_id ---

  api(:chain_id, "Get the network chain ID.",
    params: [
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout"]
    ],
    returns: %{
      type: "{:ok, non_neg_integer} | {:error, term}",
      description: "Chain ID (1 = mainnet, 11155111 = sepolia, etc.)"
    }
  )

  @spec chain_id(keyword()) :: {:ok, non_neg_integer()} | {:error, term()}
  def chain_id(opts \\ []) do
    do_rpc("eth_chainId", [], Keyword.put(to_signet_opts(opts), :decode, :hex_unsigned))
  end

  # --- chain_id! ---

  api(:chain_id!, "Get the network chain ID. Raises on error.",
    params: [
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout"]
    ],
    returns: %{type: :non_neg_integer, description: "Chain ID integer"}
  )

  @spec chain_id!(keyword()) :: non_neg_integer()
  def chain_id!(opts \\ []) do
    case chain_id(opts) do
      {:ok, result} -> result
      {:error, reason} -> raise "chain_id failed: #{inspect(reason)}"
    end
  end

  # --- Private helpers ---

  @doc false
  # Sends an RPC request and normalizes the error format.
  # Signet.RPC.send_rpc/3 spec says errors are always %{code: int, message: str},
  # but runtime errors include non-map values (Finch timeouts, connection refused).
  @dialyzer {:no_match, do_rpc: 3}
  defp do_rpc(method, params, opts) do
    case Signet.RPC.send_rpc(method, params, opts) do
      {:ok, result} -> {:ok, result}
      {:error, %{} = map} -> {:error, {:rpc_error, map}}
      {:error, other} -> {:error, {:rpc_error, %{message: inspect(other)}}}
    end
  end

  @doc false
  # Validates and normalizes an address to a 0x-prefixed lowercase hex string.
  # Delegates to Address.validate/1, then encodes the validated binary.
  defp ensure_hex_address(input) do
    case Onchain.Address.validate(input) do
      {:ok, binary} -> {:ok, Onchain.Hex.encode(binary)}
      {:error, _} -> {:error, {:invalid_address, input}}
    end
  end

  @doc false
  # Validates that data is a 0x-prefixed hex string.
  defp ensure_hex_data("0x" <> _ = data) do
    if Onchain.Hex.valid?(data) do
      {:ok, data}
    else
      {:error, {:invalid_data, data}}
    end
  end

  defp ensure_hex_data(input), do: {:error, {:invalid_data, input}}

  @doc false
  # Maps our option names to signet's expected keys.
  defp to_signet_opts(opts) do
    opts
    |> Keyword.take([:rpc_url, :timeout])
    |> Keyword.put_new(:timeout, @default_timeout_ms)
    |> rename_key(:rpc_url, :ethereum_node)
  end

  @doc false
  # Renames a keyword list key if present.
  defp rename_key(opts, old_key, new_key) do
    case Keyword.pop(opts, old_key) do
      {nil, opts} -> opts
      {value, opts} -> Keyword.put(opts, new_key, value)
    end
  end
end
