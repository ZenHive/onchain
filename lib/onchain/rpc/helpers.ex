defmodule Onchain.RPC.Helpers do
  @moduledoc false

  # Shared helpers for RPC-adjacent modules (Onchain.RPC, Onchain.Trace, etc.).
  # Provides input validation, block normalization, option mapping, and RPC dispatch.

  @default_timeout_ms 30_000
  @block_tags ~w(latest finalized pending earliest safe)
  @tx_hash_hex_length 66

  @doc false
  # Sends an RPC request and normalizes the error format.
  # Signet.RPC.send_rpc/3 spec says errors are always %{code: int, message: str},
  # but runtime errors include non-map values (Finch timeouts, connection refused).
  @dialyzer {:no_match, do_rpc: 3}
  @spec do_rpc(String.t(), list(), keyword()) :: {:ok, term()} | {:error, term()}
  def do_rpc(method, params, opts) do
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
  def ensure_hex_address(input) do
    case Onchain.Address.validate(input) do
      {:ok, binary} -> {:ok, Onchain.Hex.encode(binary)}
      {:error, _} -> {:error, {:invalid_address, input}}
    end
  end

  @doc false
  # Validates that data is a 0x-prefixed hex string.
  @spec ensure_hex_data(term()) :: {:ok, String.t()} | {:error, term()}
  def ensure_hex_data("0x" <> _ = data) do
    if Onchain.Hex.valid?(data), do: {:ok, data}, else: {:error, {:invalid_data, data}}
  end

  def ensure_hex_data(input), do: {:error, {:invalid_data, input}}

  @doc false
  # Normalizes a block identifier for RPC params.
  # Accepts tag strings, non-negative integers (converted to hex), and "0x..." hex strings.
  @spec normalize_block(term()) :: {:ok, String.t()} | {:error, term()}
  def normalize_block(tag) when tag in @block_tags, do: {:ok, tag}
  def normalize_block(n) when is_integer(n) and n >= 0, do: {:ok, Onchain.Hex.from_integer(n)}

  def normalize_block("0x" <> _ = hex) do
    if Onchain.Hex.valid?(hex), do: {:ok, hex}, else: {:error, {:invalid_block, hex}}
  end

  def normalize_block(other), do: {:error, {:invalid_block, other}}

  @doc false
  # Validates that a value is a 0x-prefixed hex string of exactly 32 bytes (66 chars).
  @spec ensure_tx_hash(term()) :: {:ok, String.t()} | {:error, term()}
  def ensure_tx_hash("0x" <> _ = hash) do
    cond do
      not Onchain.Hex.valid?(hash) -> {:error, {:invalid_tx_hash, hash}}
      byte_size(hash) != @tx_hash_hex_length -> {:error, {:invalid_tx_hash, hash}}
      true -> {:ok, hash}
    end
  end

  def ensure_tx_hash(other), do: {:error, {:invalid_tx_hash, other}}

  @doc false
  # Maps our option names to signet's expected keys.
  @spec to_signet_opts(keyword()) :: keyword()
  def to_signet_opts(opts) do
    opts
    |> Keyword.take([:rpc_url, :timeout])
    |> Keyword.put_new(:timeout, @default_timeout_ms)
    |> rename_key(:rpc_url, :ethereum_node)
  end

  @doc false
  # Renames a keyword list key if present.
  @spec rename_key(keyword(), atom(), atom()) :: keyword()
  def rename_key(opts, old_key, new_key) do
    case Keyword.pop(opts, old_key) do
      {nil, opts} -> opts
      {value, opts} -> Keyword.put(opts, new_key, value)
    end
  end
end
