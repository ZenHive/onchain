defmodule Onchain.Log do
  @moduledoc """
  Event log parsing for Ethereum contract events.

  Computes event topic hashes from signatures and decodes raw log data
  against event signatures with indexed parameter markers.

  ## Limitations

  - Tuple-typed params (e.g. `(uint256,address)`) are not supported in event signatures.
    The comma-based parser cannot distinguish tuple-internal commas from param separators.
  - Indexed dynamic types (string, bytes, arrays) return the raw keccak256 topic hash
    since the original value is not recoverable from the log.

  ## Error Format

  - Invalid signature: `{:error, {:invalid_signature, input}}`
  - Topic mismatch: `{:error, {:decode_error, {:topic_mismatch, [expected: ..., got: ...]}}}`
  - Decode errors: `{:error, {:decode_error, reason}}`

  ## Functions

  | Function | Purpose |
  |----------|---------|
  | `event_topic/1` | Event signature → keccak256 topic hash |
  | `event_topic!/1` | Same, raises on error |
  | `decode_event/2` | Raw log + signature → decoded param map |
  | `decode_event!/2` | Same, raises on error |
  """

  use Descripex, namespace: "/log"

  # ABI.decode/2 has upstream spec mismatch (success typing is no_return()).
  @dialyzer {:no_match, [decode_event: 2, decode_event!: 2]}
  @dialyzer {:no_return, [decode_event!: 1, decode_event!: 2]}
  @dialyzer {:no_contracts, [decode_event!: 1, decode_event!: 2]}

  # --- event_topic ---

  api(:event_topic, "Compute the keccak256 topic hash for an event signature.",
    params: [
      signature: [
        kind: :value,
        description: ~s{Event signature without param names, e.g. "Transfer(address,address,uint256)"}
      ]
    ],
    returns: %{
      type: "{:ok, hex_string} | {:error, term}",
      description: "0x-prefixed 32-byte keccak256 hash",
      example: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
    }
  )

  @spec event_topic(String.t()) :: {:ok, String.t()} | {:error, term()}
  def event_topic(signature) when is_binary(signature) do
    if String.contains?(signature, "(") and String.ends_with?(signature, ")") do
      {:ok, Onchain.Hex.encode(Signet.Hash.keccak(signature))}
    else
      {:error, {:invalid_signature, signature}}
    end
  end

  def event_topic(other), do: {:error, {:invalid_signature, other}}

  # --- event_topic! ---

  api(:event_topic!, "Compute the keccak256 topic hash. Raises on error.",
    params: [
      signature: [kind: :value, description: "Event signature string"]
    ],
    returns: %{type: :string, description: "0x-prefixed 32-byte keccak256 hash"}
  )

  @spec event_topic!(String.t()) :: String.t()
  def event_topic!(signature) do
    case event_topic(signature) do
      {:ok, hash} -> hash
      {:error, reason} -> raise "event_topic failed: #{inspect(reason)}"
    end
  end

  # --- decode_event ---

  api(:decode_event, "Decode a raw log map against an event signature with indexed markers.",
    params: [
      log: [
        kind: :value,
        description: "Raw log map with :topics (list of hex strings) and :data (hex string) keys"
      ],
      signature: [
        kind: :value,
        description:
          ~s{Event signature with indexed markers, e.g. "Transfer(address indexed from, address indexed to, uint256 value)"}
      ]
    ],
    returns: %{
      type: "{:ok, map} | {:error, term}",
      description: "Map with atom keys for each decoded parameter",
      example: ~s(%{from: "0xAb5...", to: "0xCd9...", value: 1000000})
    }
  )

  @spec decode_event(map(), String.t()) :: {:ok, map()} | {:error, term()}
  def decode_event(%{topics: [topic0 | _] = topics, data: data}, signature) when is_binary(signature) do
    with {:ok, params} <- parse_event_signature(signature),
         :ok <- verify_topic0(topic0, signature) do
      {indexed, non_indexed} = Enum.split_with(params, fn {_name, _type, indexed?} -> indexed? end)
      do_decode_event(topics, data, indexed, non_indexed)
    end
  end

  def decode_event(%{topics: [], data: _data}, _signature), do: {:error, {:decode_error, :missing_event_topic}}

  def decode_event(_log, _signature), do: {:error, {:decode_error, :invalid_log_format}}

  # --- decode_event! ---

  api(:decode_event!, "Decode a raw log map. Raises on error.",
    params: [
      log: [kind: :value, description: "Raw log map with :topics and :data keys"],
      signature: [kind: :value, description: "Event signature with indexed markers"]
    ],
    returns: %{type: :map, description: "Map with atom keys for each decoded parameter"}
  )

  @spec decode_event!(map(), String.t()) :: map()
  def decode_event!(log, signature) do
    case decode_event(log, signature) do
      {:ok, result} -> result
      {:error, reason} -> raise "decode_event failed: #{inspect(reason)}"
    end
  end

  # --- Private helpers ---

  @doc false
  # Verifies that topics[0] matches the keccak256 hash of the canonical event signature.
  # Strips param names and "indexed" keywords to produce the canonical form.
  @spec verify_topic0(String.t(), String.t()) :: :ok | {:error, term()}
  defp verify_topic0(topic0, signature) do
    canonical = to_canonical_signature(signature)
    expected = Onchain.Hex.encode(Signet.Hash.keccak(canonical))

    if String.downcase(topic0) == String.downcase(expected),
      do: :ok,
      else: {:error, {:decode_error, {:topic_mismatch, expected: expected, got: topic0}}}
  end

  @doc false
  # Converts "Transfer(address indexed from, address indexed to, uint256 value)"
  # into "Transfer(address,address,uint256)" for hashing.
  @spec to_canonical_signature(String.t()) :: String.t()
  defp to_canonical_signature(signature) do
    case Regex.run(~r/^(\w+)\((.+)\)$/, signature) do
      [_, name, params_str] ->
        types =
          params_str
          |> String.split(",")
          |> Enum.map_join(",", fn param ->
            param |> String.trim() |> String.split() |> extract_type()
          end)

        "#{name}(#{types})"

      nil ->
        signature
    end
  end

  @doc false
  # Extracts the type from a parsed param like ["address", "indexed", "from"] or ["uint256", "value"].
  @spec extract_type([String.t()]) :: String.t()
  defp extract_type([type, "indexed", _name]), do: type
  defp extract_type([type, _name]), do: type
  defp extract_type([type]), do: type

  @doc false
  # Parses "Transfer(address indexed from, address indexed to, uint256 value)"
  # into [{:from, "address", true}, {:to, "address", true}, {:value, "uint256", false}]
  @spec parse_event_signature(String.t()) ::
          {:ok, [{atom(), String.t(), boolean()}]} | {:error, term()}
  defp parse_event_signature(signature) do
    case Regex.run(~r/^\w+\((.+)\)$/, signature) do
      [_, params_str] ->
        params =
          params_str
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.map(&parse_param/1)

        {:ok, params}

      nil ->
        # Try empty params: "EventName()"
        if Regex.match?(~r/^\w+\(\)$/, signature) do
          {:ok, []}
        else
          {:error, {:invalid_signature, signature}}
        end
    end
  end

  @doc false
  # Parses a single param like "address indexed from" or "uint256 value".
  # String.to_atom is safe here — signatures are developer-provided constants, not user input.
  # sobelow_skip ["DOS.StringToAtom"]
  @spec parse_param(String.t()) :: {atom(), String.t(), boolean()}
  defp parse_param(param_str) do
    case String.split(param_str) do
      [type, "indexed", name] -> {String.to_atom(name), type, true}
      [type, name] -> {String.to_atom(name), type, false}
      [type] -> {String.to_atom(type), type, false}
      _other -> {String.to_atom(param_str), param_str, false}
    end
  end

  @doc false
  # Decodes indexed params from topics and non-indexed from data.
  @spec do_decode_event(list(), String.t() | nil, list(), list()) ::
          {:ok, map()} | {:error, term()}
  defp do_decode_event(topics, data, indexed, non_indexed) do
    # topics[0] is the event signature hash, indexed params start at topics[1]
    indexed_topics = Enum.drop(topics, 1)

    indexed_result =
      indexed
      |> Enum.zip(indexed_topics)
      |> Enum.map(fn {{name, type, _}, topic_hex} ->
        {name, decode_indexed_param(topic_hex, type)}
      end)

    non_indexed_result = decode_non_indexed_params(data, non_indexed)

    case non_indexed_result do
      {:ok, decoded_pairs} ->
        result = Map.new(indexed_result ++ decoded_pairs)
        {:ok, result}

      error ->
        error
    end
  end

  # Indexed dynamic types (string, bytes, arrays, tuples) are stored as keccak256(value)
  # in topics. The original value is not recoverable — return the raw topic hash.
  @dynamic_indexed_types ["string", "bytes"]

  @doc false
  # Decodes a single indexed param from a 32-byte topic.
  # Dynamic types (string, bytes, arrays, tuples) return the raw topic hash
  # since Solidity stores keccak256(value) for these, not the value itself.
  @spec decode_indexed_param(String.t(), String.t()) :: term()
  defp decode_indexed_param(topic_hex, type) do
    if dynamic_indexed_type?(type) do
      topic_hex
    else
      binary = Onchain.Hex.decode!(topic_hex)

      case type do
        "address" ->
          # Address is right-padded in 32 bytes — take last 20
          <<_::binary-size(12), addr::binary-size(20)>> = binary
          Onchain.Address.checksum!(addr)

        _value_type ->
          # uint256, int256, bool, bytes32, etc. — decode as ABI value
          [value] = ABI.decode("(#{type})", binary)
          value
      end
    end
  end

  @doc false
  # Returns true for types that Solidity stores as keccak256(value) when indexed.
  # Covers string, bytes (not bytesN), and array types (e.g. uint256[]).
  # Tuple types are not supported by the signature parser (see @moduledoc Limitations).
  @spec dynamic_indexed_type?(String.t()) :: boolean()
  defp dynamic_indexed_type?(type) when type in @dynamic_indexed_types, do: true
  defp dynamic_indexed_type?(type), do: String.contains?(type, "[")

  @doc false
  # Decodes non-indexed params from the data field.
  @spec decode_non_indexed_params(String.t() | nil, list()) ::
          {:ok, [{atom(), term()}]} | {:error, term()}
  defp decode_non_indexed_params(_data, []), do: {:ok, []}

  defp decode_non_indexed_params(nil, _params), do: {:error, {:decode_error, :missing_data_field}}

  defp decode_non_indexed_params("0x", _params), do: {:error, {:decode_error, :empty_data_field}}

  defp decode_non_indexed_params(data, params) do
    type_sig = "(" <> Enum.map_join(params, ",", fn {_name, type, _} -> type end) <> ")"

    case Onchain.ABI.decode_response(type_sig, data) do
      {:ok, values} ->
        pairs =
          params
          |> Enum.zip(values)
          |> Enum.map(fn {{name, type, _}, value} ->
            {name, maybe_checksum_address(value, type)}
          end)

        {:ok, pairs}

      error ->
        error
    end
  end

  @doc false
  # Checksums address values from non-indexed ABI decoding.
  @spec maybe_checksum_address(term(), String.t()) :: term()
  defp maybe_checksum_address(value, "address") when is_binary(value) and byte_size(value) == 20,
    do: Onchain.Address.checksum!(value)

  defp maybe_checksum_address(value, _type), do: value
end
