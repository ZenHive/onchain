defmodule Onchain.RPC.Helpers do
  @moduledoc false

  # Shared helpers for RPC-adjacent modules (Onchain.RPC, Onchain.Block, etc.).
  # Provides input validation, block normalization, option mapping, and RPC dispatch.

  require Logger

  @default_timeout_ms 30_000
  @block_tags ~w(latest finalized pending earliest safe)
  @tx_hash_hex_length 66

  @doc false
  @spec block_tags() :: [String.t()]
  def block_tags, do: @block_tags

  @doc false
  # Sends an RPC request and normalizes the error format.
  # Cartouche.RPC.send_rpc/3 narrowly types errors as %{code: int, message: str},
  # but runtime errors include non-map values (Finch timeouts, connection refused).
  # Tracked upstream as cartouche ROADMAP Phase 2, Tasks 14+15+35 — error-shape
  # widening + JSON-encode rescue (see ../cartouche/ROADMAP.md). Re-probed
  # 2026-04-30 against cartouche 0.1.0,
  # still narrow. Re-probe on next cartouche bump; strip this suppression once
  # the upstream union lands.
  @dialyzer {:no_match, do_rpc: 3}
  @spec do_rpc(String.t(), list(), keyword()) :: {:ok, term()} | {:error, term()}
  def do_rpc(method, params, opts) do
    case Cartouche.RPC.send_rpc(method, params, opts) do
      {:ok, result} -> {:ok, result}
      {:error, %{} = map} -> {:error, {:rpc_error, map}}
      {:error, other} -> {:error, {:rpc_error, %{message: inspect(other)}}}
    end
  end

  @doc false
  # Validates an address at the RPC-helper boundary and normalizes to lowercase hex.
  # Accepts either:
  #   * "0x" + exactly 40 hex chars (canonical hex form)
  #   * 20-byte raw binary (internal flow from Onchain.Address.validate/1)
  # Rejects malformed hex strings (wrong length, bad chars, missing 0x) — including
  # the Task 55 ambiguity: a 20-byte binary whose leading two bytes are the ASCII
  # "0x" literal. Those are almost always a hex string of wrong length rather than
  # an intentional raw binary address, and silently re-encoding them produced a
  # wildly different on-chain address.
  @spec ensure_hex_address(term()) :: {:ok, String.t()} | {:error, term()}
  def ensure_hex_address("0x" <> rest = input) when byte_size(rest) == 40 do
    if Onchain.Hex.valid?(input),
      do: {:ok, "0x" <> String.downcase(rest)},
      else: {:error, {:invalid_address, input}}
  end

  def ensure_hex_address(<<"0x", _::binary>> = input), do: {:error, {:invalid_address, input}}

  def ensure_hex_address(bin) when is_binary(bin) and byte_size(bin) == 20, do: {:ok, Onchain.Hex.encode(bin)}

  def ensure_hex_address(input), do: {:error, {:invalid_address, input}}

  @doc false
  # Validates that data is a 0x-prefixed even-length hex string.
  # "0x" alone (empty calldata) is accepted.
  @spec ensure_hex_data(term()) :: {:ok, String.t()} | {:error, term()}
  def ensure_hex_data("0x" <> rest = data) do
    cond do
      not Onchain.Hex.valid?(data) -> {:error, {:invalid_data, data}}
      rem(byte_size(rest), 2) != 0 -> {:error, {:invalid_data, data}}
      true -> {:ok, data}
    end
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
  # Maps our option names to the underlying RPC client's expected keys.
  @spec to_rpc_opts(keyword()) :: keyword()
  def to_rpc_opts(opts) do
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

  # --- RPC response parsing helpers ---
  # Used by Onchain.RPC and Onchain.Subscription.Parser to convert
  # raw JSON-RPC response fields into normalized Elixir values.

  @doc false
  # Parses hex fields in a raw log map from the RPC response.
  @spec parse_log(map()) :: map()
  def parse_log(log) when is_map(log) do
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
  # Parses a hex address string to checksummed format.
  @spec parse_address(String.t() | nil) :: String.t() | nil
  def parse_address(nil), do: nil

  def parse_address(hex) do
    case Onchain.Address.checksum(hex) do
      {:ok, checksummed} -> checksummed
      {:error, _} -> hex
    end
  end

  @doc false
  # Parses a hex integer string, returning nil for nil input.
  @spec parse_hex_integer(String.t() | nil) :: non_neg_integer() | nil
  def parse_hex_integer(nil), do: nil

  def parse_hex_integer(hex) do
    case Onchain.Hex.to_integer(hex) do
      {:ok, n} ->
        n

      {:error, _} ->
        Logger.debug("Failed to parse hex integer from RPC response: #{inspect(hex)}")
        nil
    end
  end
end
