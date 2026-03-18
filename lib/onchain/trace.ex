defmodule Onchain.Trace do
  @moduledoc """
  Debug and trace API wrapper for Ethereum nodes.

  Provides access to the `debug_*` JSON-RPC namespace for transaction tracing,
  call tracing, and direct storage slot reads. These methods are supported by
  reth, geth, Erigon, and Nethermind — any full node with debug APIs enabled.

  **Not a core dependency** — the library works with any RPC endpoint. This module
  provides enhanced debugging and inspection capabilities when available.

  ## Tracer Types

  - `"callTracer"` (default) — returns the call tree: type, from, to, gas, value,
    input, output, and nested calls
  - `"prestateTracer"` — returns the pre-execution state: balance, nonce, code,
    and storage for each touched account

  ## Performance Note

  For faster EVM simulation, pass a local node URL (e.g. `http://localhost:8545`)
  as `:rpc_url` to `Onchain.EVM.simulate_*/3`. Local nodes eliminate network
  latency and rate limits — no special integration needed.

  ## Error Format

  - Address validation: `{:error, {:invalid_address, input}}`
  - Data validation: `{:error, {:invalid_data, input}}`
  - Block validation: `{:error, {:invalid_block, input}}`
  - Tx hash validation: `{:error, {:invalid_tx_hash, input}}` (must be 32 bytes)
  - Slot validation: `{:error, {:invalid_slot, input}}` (must be 0x hex)
  - RPC/network errors: `{:error, {:rpc_error, %{code: integer, message: string}}}`

  ## Functions

  | Function | Purpose |
  |----------|---------|
  | `trace_transaction/2` | Full execution trace of a mined transaction |
  | `trace_transaction!/2` | Same, raises on error |
  | `trace_call/3` | Trace a call without mining it |
  | `trace_call!/3` | Same, raises on error |
  | `storage_at/3` | Read a contract storage slot directly |
  | `storage_at!/3` | Same, raises on error |
  | `available?/1` | Check if debug/trace APIs are supported |
  """

  use Descripex, namespace: "/trace"

  @default_timeout_ms 30_000
  @block_tags ~w(latest finalized pending earliest safe)
  @tx_hash_hex_length 66
  @valid_tracers ~w(callTracer prestateTracer)

  # --- trace_transaction ---

  api(:trace_transaction, "Get a full execution trace of a mined transaction (debug_traceTransaction).",
    params: [
      tx_hash: [kind: :value, description: "0x-prefixed hex transaction hash"],
      opts: [
        kind: :value,
        default: [],
        description: ~s[Options: :rpc_url, :timeout, :tracer ("callTracer" or "prestateTracer", default: "callTracer")]
      ]
    ],
    returns: %{
      type: "{:ok, map} | {:error, term}",
      description: "Raw trace output from the node (shape depends on tracer type)"
    }
  )

  @spec trace_transaction(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def trace_transaction(tx_hash, opts \\ []) do
    with {:ok, _hex} <- ensure_tx_hash(tx_hash),
         {:ok, tracer_config} <- build_tracer_config(opts) do
      do_rpc("debug_traceTransaction", [tx_hash, tracer_config], to_signet_opts(opts))
    end
  end

  # --- trace_transaction! ---

  api(:trace_transaction!, "Get a full execution trace of a mined transaction. Raises on error.",
    params: [
      tx_hash: [kind: :value, description: "0x-prefixed hex transaction hash"],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout, :tracer"]
    ],
    returns: %{type: :map, description: "Raw trace output from the node"}
  )

  @spec trace_transaction!(String.t(), keyword()) :: map()
  def trace_transaction!(tx_hash, opts \\ []) do
    case trace_transaction(tx_hash, opts) do
      {:ok, result} -> result
      {:error, reason} -> raise "trace_transaction failed: #{inspect(reason)}"
    end
  end

  # --- trace_call ---

  api(:trace_call, "Trace a call without mining it (debug_traceCall).",
    params: [
      call_params: [
        kind: :value,
        description:
          "Call parameters map with :to (address), :data (hex calldata), and optional :from (address), :value (hex wei)"
      ],
      block: [
        kind: :value,
        default: "latest",
        description: ~s[Block number (integer), tag ("latest", "finalized", etc.), or "0x..." hex]
      ],
      opts: [
        kind: :value,
        default: [],
        description: ~s[Options: :rpc_url, :timeout, :tracer ("callTracer" or "prestateTracer", default: "callTracer")]
      ]
    ],
    returns: %{
      type: "{:ok, map} | {:error, term}",
      description: "Raw trace output from the node (shape depends on tracer type)"
    }
  )

  @spec trace_call(map(), non_neg_integer() | String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def trace_call(call_params, block \\ "latest", opts \\ []) when is_map(call_params) do
    with {:ok, rpc_params} <- build_call_params(call_params),
         {:ok, block_hex} <- normalize_block(block),
         {:ok, tracer_config} <- build_tracer_config(opts) do
      do_rpc("debug_traceCall", [rpc_params, block_hex, tracer_config], to_signet_opts(opts))
    end
  end

  # --- trace_call! ---

  api(:trace_call!, "Trace a call without mining it. Raises on error.",
    params: [
      call_params: [kind: :value, description: "Call parameters map (see trace_call/3)"],
      block: [kind: :value, default: "latest", description: "Block identifier"],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout, :tracer"]
    ],
    returns: %{type: :map, description: "Raw trace output from the node"}
  )

  @spec trace_call!(map(), non_neg_integer() | String.t(), keyword()) :: map()
  def trace_call!(call_params, block \\ "latest", opts \\ []) do
    case trace_call(call_params, block, opts) do
      {:ok, result} -> result
      {:error, reason} -> raise "trace_call failed: #{inspect(reason)}"
    end
  end

  # --- storage_at ---

  api(:storage_at, "Read a contract storage slot directly (eth_getStorageAt).",
    params: [
      address: [kind: :value, description: "Contract address as 0x hex string or 20-byte binary"],
      slot: [kind: :value, description: "Storage slot position as 0x-prefixed hex string (32 bytes)"],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout, :block"]
    ],
    returns: %{
      type: "{:ok, hex_string} | {:error, term}",
      description: "32-byte hex value at the storage slot",
      example: "0x0000000000000000000000000000000000000000000000000000000000000001"
    }
  )

  @spec storage_at(String.t() | binary(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def storage_at(address, slot, opts \\ []) do
    with {:ok, hex_addr} <- ensure_hex_address(address),
         {:ok, hex_slot} <- ensure_hex_slot(slot),
         {:ok, block} <- normalize_block(Keyword.get(opts, :block, "latest")) do
      do_rpc("eth_getStorageAt", [hex_addr, hex_slot, block], to_signet_opts(opts))
    end
  end

  # --- storage_at! ---

  api(:storage_at!, "Read a contract storage slot directly. Raises on error.",
    params: [
      address: [kind: :value, description: "Contract address as 0x hex string or 20-byte binary"],
      slot: [kind: :value, description: "Storage slot position as 0x-prefixed hex string"],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout, :block"]
    ],
    returns: %{type: :string, description: "32-byte hex value at the storage slot"}
  )

  @spec storage_at!(String.t() | binary(), String.t(), keyword()) :: String.t()
  def storage_at!(address, slot, opts \\ []) do
    case storage_at(address, slot, opts) do
      {:ok, result} -> result
      {:error, reason} -> raise "storage_at failed: #{inspect(reason)}"
    end
  end

  # --- available? ---

  api(:available?, "Check if debug/trace APIs are supported by the connected node.",
    params: [
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout"]
    ],
    returns: %{
      type: :boolean,
      description: "true if the node supports debug_traceCall, false otherwise"
    }
  )

  @zero_address "0x0000000000000000000000000000000000000000"

  @spec available?(keyword()) :: boolean()
  def available?(opts \\ []) do
    probe_params = %{"to" => @zero_address, "data" => "0x"}
    tracer_config = %{"tracer" => "callTracer"}

    case do_rpc("debug_traceCall", [probe_params, "latest", tracer_config], to_signet_opts(opts)) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  # --- Private helpers ---

  @doc false
  # Builds the tracer configuration map from options.
  @spec build_tracer_config(keyword()) :: {:ok, map()} | {:error, term()}
  defp build_tracer_config(opts) do
    tracer = Keyword.get(opts, :tracer, "callTracer")

    if tracer in @valid_tracers do
      {:ok, %{"tracer" => tracer}}
    else
      {:error, {:invalid_tracer, tracer}}
    end
  end

  @doc false
  # Builds the call parameters map for debug_traceCall, validating required fields.
  @spec build_call_params(map()) :: {:ok, map()} | {:error, term()}
  defp build_call_params(params) do
    with {:ok, to} <- fetch_and_validate_address(params, :to),
         {:ok, data} <- fetch_and_validate_data(params),
         base = %{"to" => to, "data" => data},
         {:ok, result} <- maybe_put_address(base, params, :from) do
      {:ok, maybe_put_value(result, params)}
    end
  end

  @doc false
  @spec fetch_and_validate_address(map(), atom()) :: {:ok, String.t()} | {:error, term()}
  defp fetch_and_validate_address(params, key) do
    case Map.get(params, key) do
      nil -> {:error, {:missing_param, key}}
      addr -> ensure_hex_address(addr)
    end
  end

  @doc false
  @spec fetch_and_validate_data(map()) :: {:ok, String.t()} | {:error, term()}
  defp fetch_and_validate_data(params) do
    case Map.get(params, :data) do
      nil -> {:error, {:missing_param, :data}}
      data -> ensure_hex_data(data)
    end
  end

  @doc false
  @spec maybe_put_address(map(), map(), atom()) :: {:ok, map()} | {:error, term()}
  defp maybe_put_address(result, params, key) do
    case Map.get(params, key) do
      nil ->
        {:ok, result}

      addr ->
        case ensure_hex_address(addr) do
          {:ok, hex} -> {:ok, Map.put(result, to_string(key), hex)}
          {:error, _} = err -> err
        end
    end
  end

  @doc false
  @spec maybe_put_value(map(), map()) :: map()
  defp maybe_put_value(result, params) do
    case Map.get(params, :value) do
      nil -> result
      value -> Map.put(result, "value", value)
    end
  end

  @doc false
  # Validates that a slot is a 0x-prefixed hex string.
  @spec ensure_hex_slot(term()) :: {:ok, String.t()} | {:error, term()}
  defp ensure_hex_slot("0x" <> _ = slot) do
    if Onchain.Hex.valid?(slot), do: {:ok, slot}, else: {:error, {:invalid_slot, slot}}
  end

  defp ensure_hex_slot(other), do: {:error, {:invalid_slot, other}}

  @doc false
  # Sends an RPC request and normalizes the error format.
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
  @spec ensure_hex_address(term()) :: {:ok, String.t()} | {:error, term()}
  defp ensure_hex_address(input) do
    case Onchain.Address.validate(input) do
      {:ok, binary} -> {:ok, Onchain.Hex.encode(binary)}
      {:error, _} -> {:error, {:invalid_address, input}}
    end
  end

  @doc false
  # Validates that data is a 0x-prefixed hex string.
  @spec ensure_hex_data(term()) :: {:ok, String.t()} | {:error, term()}
  defp ensure_hex_data("0x" <> _ = data) do
    if Onchain.Hex.valid?(data), do: {:ok, data}, else: {:error, {:invalid_data, data}}
  end

  defp ensure_hex_data(input), do: {:error, {:invalid_data, input}}

  @doc false
  # Normalizes a block identifier for RPC params.
  @spec normalize_block(term()) :: {:ok, String.t()} | {:error, term()}
  defp normalize_block(tag) when tag in @block_tags, do: {:ok, tag}
  defp normalize_block(n) when is_integer(n) and n >= 0, do: {:ok, Onchain.Hex.from_integer(n)}

  defp normalize_block("0x" <> _ = hex) do
    if Onchain.Hex.valid?(hex), do: {:ok, hex}, else: {:error, {:invalid_block, hex}}
  end

  defp normalize_block(other), do: {:error, {:invalid_block, other}}

  @doc false
  # Validates that a value is a 0x-prefixed hex string of exactly 32 bytes (66 chars).
  @spec ensure_tx_hash(term()) :: {:ok, String.t()} | {:error, term()}
  defp ensure_tx_hash("0x" <> _ = hash) do
    cond do
      not Onchain.Hex.valid?(hash) -> {:error, {:invalid_tx_hash, hash}}
      byte_size(hash) != @tx_hash_hex_length -> {:error, {:invalid_tx_hash, hash}}
      true -> {:ok, hash}
    end
  end

  defp ensure_tx_hash(other), do: {:error, {:invalid_tx_hash, other}}

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
