defmodule Onchain.RPC do
  @moduledoc """
  Ethereum JSON-RPC wrapper using signet's RPC client.

  Provides a curated API for common Ethereum RPC methods with consistent
  error tuples and option handling. All functions accept `:rpc_url`,
  `:timeout`, and `:block` options.

  ## Error Format

  - Address validation: `{:error, {:invalid_address, input}}`
  - Data validation: `{:error, {:invalid_data, input}}`
  - Block validation: `{:error, {:invalid_block, input}}`
  - Tx hash validation: `{:error, {:invalid_tx_hash, input}}` (must be 32 bytes)
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
  | `get_block_by_number/2` | Fetch block by number or tag |
  | `get_block_by_number!/2` | Same, raises on error |
  | `chain_id/1` | Network chain ID |
  | `chain_id!/1` | Same, raises on error |
  | `eth_get_logs/2` | Fetch event logs by filter |
  | `eth_get_logs!/2` | Same, raises on error |
  | `get_transaction_receipt/2` | Transaction receipt by hash |
  | `get_transaction_receipt!/2` | Same, raises on error |
  | `get_transaction_count/2` | Account nonce (tx count) |
  | `get_transaction_count!/2` | Same, raises on error |
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
         {:ok, hex_data} <- ensure_hex_data(data),
         {:ok, block} <- normalize_block(Keyword.get(opts, :block, "latest")) do
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
    with {:ok, hex_addr} <- ensure_hex_address(address),
         {:ok, block} <- normalize_block(Keyword.get(opts, :block, "latest")) do
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

  # --- get_block_by_number ---

  api(:get_block_by_number, "Fetch a block by number or tag (eth_getBlockByNumber).",
    params: [
      block_id: [
        kind: :value,
        description:
          ~s{Block number (integer) or tag string ("latest", "finalized", "pending", "earliest", "safe", or "0x..." hex)}
      ],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout"]
    ],
    returns: %{
      type: "{:ok, map} | {:error, term}",
      description: "Raw block map with hex-encoded fields from the node",
      example: ~s(%{"number" => "0x1312d00", "timestamp" => "0x665ba27f", ...})
    }
  )

  @block_tags ~w(latest finalized pending earliest safe)

  @spec get_block_by_number(integer() | String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def get_block_by_number(block_id, opts \\ [])

  def get_block_by_number(block_id, opts) when is_integer(block_id) and block_id >= 0 do
    hex = Onchain.Hex.from_integer(block_id)
    do_rpc("eth_getBlockByNumber", [hex, false], to_signet_opts(opts))
  end

  def get_block_by_number(tag, opts) when tag in @block_tags do
    do_rpc("eth_getBlockByNumber", [tag, false], to_signet_opts(opts))
  end

  def get_block_by_number("0x" <> _ = hex_num, opts) do
    if Onchain.Hex.valid?(hex_num) do
      do_rpc("eth_getBlockByNumber", [hex_num, false], to_signet_opts(opts))
    else
      {:error, {:invalid_block_id, hex_num}}
    end
  end

  def get_block_by_number(block_id, _opts), do: {:error, {:invalid_block_id, block_id}}

  # --- get_block_by_number! ---

  api(:get_block_by_number!, "Fetch a block by number or tag. Raises on error.",
    params: [
      block_id: [
        kind: :value,
        description: "Block number (integer) or tag string"
      ],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout"]
    ],
    returns: %{type: :map, description: "Raw block map with hex-encoded fields"}
  )

  @spec get_block_by_number!(integer() | String.t(), keyword()) :: map()
  def get_block_by_number!(block_id, opts \\ []) do
    case get_block_by_number(block_id, opts) do
      {:ok, result} -> result
      {:error, reason} -> raise "get_block_by_number failed: #{inspect(reason)}"
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

  # --- get_transaction_receipt ---

  api(:get_transaction_receipt, "Get a transaction receipt by hash (eth_getTransactionReceipt).",
    params: [
      tx_hash: [kind: :value, description: "0x-prefixed hex transaction hash"],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout"]
    ],
    returns: %{
      type: "{:ok, map | nil} | {:error, term}",
      description: "Parsed receipt map, or nil if the transaction is pending/unknown"
    }
  )

  @spec get_transaction_receipt(String.t(), keyword()) :: {:ok, map() | nil} | {:error, term()}
  def get_transaction_receipt(tx_hash, opts \\ []) do
    with {:ok, _hex} <- ensure_tx_hash(tx_hash) do
      case do_rpc("eth_getTransactionReceipt", [tx_hash], to_signet_opts(opts)) do
        {:ok, nil} -> {:ok, nil}
        {:ok, receipt} when is_map(receipt) -> {:ok, parse_receipt(receipt)}
        error -> error
      end
    end
  end

  # --- get_transaction_receipt! ---

  api(:get_transaction_receipt!, "Get a transaction receipt by hash. Raises on error.",
    params: [
      tx_hash: [kind: :value, description: "0x-prefixed hex transaction hash"],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout"]
    ],
    returns: %{type: "map | nil", description: "Parsed receipt map or nil"}
  )

  @spec get_transaction_receipt!(String.t(), keyword()) :: map() | nil
  def get_transaction_receipt!(tx_hash, opts \\ []) do
    case get_transaction_receipt(tx_hash, opts) do
      {:ok, result} -> result
      {:error, reason} -> raise "get_transaction_receipt failed: #{inspect(reason)}"
    end
  end

  # --- get_transaction_count ---

  api(:get_transaction_count, "Get the transaction count (nonce) of an address.",
    params: [
      address: [kind: :value, description: "Account address as 0x hex string or 20-byte binary"],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout, :block"]
    ],
    returns: %{
      type: "{:ok, non_neg_integer} | {:error, term}",
      description: "Transaction count (nonce)"
    }
  )

  @spec get_transaction_count(String.t() | binary(), keyword()) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def get_transaction_count(address, opts \\ []) do
    with {:ok, hex_addr} <- ensure_hex_address(address),
         {:ok, block} <- normalize_block(Keyword.get(opts, :block, "latest")) do
      do_rpc(
        "eth_getTransactionCount",
        [hex_addr, block],
        Keyword.put(to_signet_opts(opts), :decode, :hex_unsigned)
      )
    end
  end

  # --- get_transaction_count! ---

  api(:get_transaction_count!, "Get the transaction count (nonce) of an address. Raises on error.",
    params: [
      address: [kind: :value, description: "Account address as 0x hex string or 20-byte binary"],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout, :block"]
    ],
    returns: %{type: :non_neg_integer, description: "Transaction count (nonce)"}
  )

  @spec get_transaction_count!(String.t() | binary(), keyword()) :: non_neg_integer()
  def get_transaction_count!(address, opts \\ []) do
    case get_transaction_count(address, opts) do
      {:ok, result} -> result
      {:error, reason} -> raise "get_transaction_count failed: #{inspect(reason)}"
    end
  end

  # --- eth_get_logs ---

  api(:eth_get_logs, "Fetch event logs matching a filter (eth_getLogs).",
    params: [
      filter: [
        kind: :value,
        description:
          "Filter map with keys: :address (hex string or binary), :topics (list), :from_block (integer or tag), :to_block (integer or tag)"
      ],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout"]
    ],
    returns: %{
      type: "{:ok, [log_map]} | {:error, term}",
      description:
        "List of log maps with keys: address, topics, data, block_number, transaction_hash, log_index, transaction_index, removed"
    }
  )

  @spec eth_get_logs(map(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def eth_get_logs(filter, opts \\ []) when is_map(filter) do
    with {:ok, rpc_filter} <- build_log_filter(filter) do
      case do_rpc("eth_getLogs", [rpc_filter], to_signet_opts(opts)) do
        {:ok, logs} when is_list(logs) -> {:ok, Enum.map(logs, &parse_log/1)}
        {:ok, other} -> {:error, {:rpc_error, %{message: "unexpected response: #{inspect(other)}"}}}
        error -> error
      end
    end
  end

  # --- eth_get_logs! ---

  api(:eth_get_logs!, "Fetch event logs matching a filter. Raises on error.",
    params: [
      filter: [kind: :value, description: "Filter map (see eth_get_logs/2)"],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout"]
    ],
    returns: %{type: "[log_map]", description: "List of parsed log maps"}
  )

  @spec eth_get_logs!(map(), keyword()) :: [map()]
  def eth_get_logs!(filter, opts \\ []) do
    case eth_get_logs(filter, opts) do
      {:ok, logs} -> logs
      {:error, reason} -> raise "eth_get_logs failed: #{inspect(reason)}"
    end
  end

  # --- Private helpers ---

  @doc false
  # Builds a JSON-RPC filter object from an Elixir map.
  @spec build_log_filter(map()) :: {:ok, map()} | {:error, term()}
  defp build_log_filter(filter) do
    with {:ok, result} <- put_filter_address(%{}, filter),
         {:ok, result} <- put_filter_topics(result, filter),
         {:ok, result} <- put_block_param(result, "fromBlock", :fromBlock, Map.get(filter, :from_block)) do
      put_block_param(result, "toBlock", :toBlock, Map.get(filter, :to_block))
    end
  end

  @doc false
  @spec put_filter_address(map(), map()) :: {:ok, map()} | {:error, term()}
  defp put_filter_address(result, filter) do
    case Map.get(filter, :address) do
      nil -> {:ok, result}
      addr -> with {:ok, hex} <- ensure_hex_address(addr), do: {:ok, Map.put(result, "address", hex)}
    end
  end

  @doc false
  @spec put_filter_topics(map(), map()) :: {:ok, map()} | {:error, term()}
  defp put_filter_topics(result, filter) do
    case Map.get(filter, :topics) do
      nil -> {:ok, result}
      topics when is_list(topics) -> {:ok, Map.put(result, "topics", topics)}
      other -> {:error, {:invalid_filter, {:topics, other}}}
    end
  end

  @doc false
  # Converts a block identifier to hex for the filter.
  # `error_label` is an atom used in error tuples (e.g. :fromBlock, :toBlock).
  @spec put_block_param(map(), String.t(), atom(), term()) :: {:ok, map()} | {:error, term()}
  defp put_block_param(result, _key, _error_label, nil), do: {:ok, result}

  defp put_block_param(result, key, _error_label, n) when is_integer(n) and n >= 0,
    do: {:ok, Map.put(result, key, Onchain.Hex.from_integer(n))}

  defp put_block_param(result, key, _error_label, tag) when tag in @block_tags, do: {:ok, Map.put(result, key, tag)}

  defp put_block_param(result, key, error_label, "0x" <> _ = hex) do
    if Onchain.Hex.valid?(hex),
      do: {:ok, Map.put(result, key, hex)},
      else: {:error, {:invalid_filter, {error_label, hex}}}
  end

  defp put_block_param(_result, _key, error_label, other), do: {:error, {:invalid_filter, {error_label, other}}}

  @doc false
  # Parses hex fields in a raw log map from the RPC response.
  @spec parse_log(map()) :: map()
  defp parse_log(log) when is_map(log) do
    %{
      address: parse_address(log["address"]),
      topics: log["topics"] || [],
      data: log["data"],
      block_number: parse_hex_integer(log["blockNumber"]),
      transaction_hash: log["transactionHash"],
      log_index: parse_hex_integer(log["logIndex"]),
      transaction_index: parse_hex_integer(log["transactionIndex"]),
      removed: log["removed"] || false
    }
  end

  @doc false
  # Parses a raw transaction receipt map from the RPC response into atom-keyed map.
  @spec parse_receipt(map()) :: map()
  defp parse_receipt(receipt) when is_map(receipt) do
    %{
      transaction_hash: receipt["transactionHash"],
      transaction_index: parse_hex_integer(receipt["transactionIndex"]),
      block_hash: receipt["blockHash"],
      block_number: parse_hex_integer(receipt["blockNumber"]),
      from: parse_address(receipt["from"]),
      to: parse_address(receipt["to"]),
      cumulative_gas_used: parse_hex_integer(receipt["cumulativeGasUsed"]),
      gas_used: parse_hex_integer(receipt["gasUsed"]),
      effective_gas_price: parse_hex_integer(receipt["effectiveGasPrice"]),
      status: parse_hex_integer(receipt["status"]),
      contract_address: parse_address(receipt["contractAddress"]),
      logs: Enum.map(receipt["logs"] || [], &parse_log/1),
      type: parse_hex_integer(receipt["type"])
    }
  end

  @doc false
  # Parses a hex address string to checksummed format.
  @spec parse_address(String.t() | nil) :: String.t() | nil
  defp parse_address(nil), do: nil
  defp parse_address(hex), do: Onchain.Address.checksum!(hex)

  @doc false
  # Parses a hex integer string, returning nil for nil input.
  @spec parse_hex_integer(String.t() | nil) :: non_neg_integer() | nil
  defp parse_hex_integer(nil), do: nil
  defp parse_hex_integer(hex), do: Onchain.Hex.to_integer!(hex)

  @doc false
  # Sends an RPC request and normalizes the error format.
  # Signet.RPC.send_rpc/3 spec says errors are always %{code: int, message: str},
  # but runtime errors include non-map values (Finch timeouts, connection refused).
  @dialyzer {:no_match, do_rpc: 3}
  @spec do_rpc(String.t(), list(), keyword()) :: {:ok, term()} | {:error, term()}
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
  @spec ensure_hex_address(term()) :: {:ok, String.t()} | {:error, term()}
  defp ensure_hex_address(input) do
    case Onchain.Address.validate(input) do
      {:ok, binary} -> {:ok, Onchain.Hex.encode(binary)}
      {:error, _} -> {:error, {:invalid_address, input}}
    end
  end

  @doc false
  # Normalizes a block identifier for RPC params.
  # Accepts tag strings, non-negative integers (converted to hex), and "0x..." hex strings.
  @spec normalize_block(term()) :: {:ok, String.t()} | {:error, term()}
  defp normalize_block(tag) when tag in @block_tags, do: {:ok, tag}
  defp normalize_block(n) when is_integer(n) and n >= 0, do: {:ok, Onchain.Hex.from_integer(n)}

  defp normalize_block("0x" <> _ = hex) do
    if Onchain.Hex.valid?(hex), do: {:ok, hex}, else: {:error, {:invalid_block, hex}}
  end

  defp normalize_block(other), do: {:error, {:invalid_block, other}}

  @tx_hash_hex_length 66

  @doc false
  # Validates that a value is a 0x-prefixed hex string of exactly 32 bytes (66 chars).
  @spec ensure_tx_hash(term()) :: {:ok, String.t()} | {:error, term()}
  defp ensure_tx_hash("0x" <> _ = hash) do
    cond do
      not Onchain.Hex.valid?(hash) -> {:error, {:invalid_tx_hash, hash}}
      String.length(hash) != @tx_hash_hex_length -> {:error, {:invalid_tx_hash, hash}}
      true -> {:ok, hash}
    end
  end

  defp ensure_tx_hash(other), do: {:error, {:invalid_tx_hash, other}}

  @doc false
  # Validates that data is a 0x-prefixed hex string.
  @spec ensure_hex_data(term()) :: {:ok, String.t()} | {:error, term()}
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
  @spec to_signet_opts(keyword()) :: keyword()
  defp to_signet_opts(opts) do
    opts
    |> Keyword.take([:rpc_url, :timeout])
    |> Keyword.put_new(:timeout, @default_timeout_ms)
    |> rename_key(:rpc_url, :ethereum_node)
  end

  @doc false
  # Renames a keyword list key if present.
  @spec rename_key(keyword(), atom(), atom()) :: keyword()
  defp rename_key(opts, old_key, new_key) do
    case Keyword.pop(opts, old_key) do
      {nil, opts} -> opts
      {value, opts} -> Keyword.put(opts, new_key, value)
    end
  end
end
