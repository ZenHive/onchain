defmodule Onchain.ABI do
  @moduledoc """
  ABI encoding/decoding for Ethereum contract calls.

  Wraps the `hieroglyph` ABI library (transitively pulled in by cartouche) with `0x`-prefixed hex string
  handling and consistent error tuples. Consumers work with hex strings from
  RPC; this module bridges the gap.

  ## Type Signatures

  `decode_response/2` (and its alias `decode_types/2`) expects **tuple type
  syntax** for return values — the type list MUST be wrapped in parentheses,
  e.g. `"(uint256)"` or `"(uint256,bool)"`. Bare comma-separated types
  (`"uint256,bool"`) raise an unhelpful upstream error and are not accepted.
  This is the standard pattern for decoding `eth_call` responses — NOT
  function signatures with names.

  Use `decode_response/2` when the input is an `eth_call` reply; use
  `decode_types/2` when the input is arbitrary ABI-encoded bytes
  (mempool calldata, custom payloads). They behave identically.

  ## Error Format

  - Encode errors: `{:error, {:encode_error, reason}}`
  - Decode errors: `{:error, {:decode_error, reason}}`

  Where `reason` is either:
  - A string from the upstream exception message
  - A tuple like `{:invalid_hex, hex_data}` preserving the original hex error

  ## Functions

  | Function | Purpose |
  |----------|---------|
  | `encode_call/2` | Function signature + params → hex calldata |
  | `encode_call!/2` | Same, raises on error |
  | `decode_response/2` | Type signature + hex data → decoded values |
  | `decode_response!/2` | Same, raises on error |
  | `decode_types/2` | Alias of `decode_response/2` for non-RPC callers |
  | `decode_types!/2` | Alias of `decode_response!/2`, raises on error |
  """

  use Descripex, namespace: "/abi"

  # --- encode_call ---

  api(:encode_call, "Encode a function call to 0x-prefixed hex calldata.",
    params: [
      signature: [kind: :value, description: "Function signature, e.g. \"balanceOf(address)\""],
      params: [kind: :value, description: "List of parameter values matching the signature"]
    ],
    returns: %{
      type: "{:ok, hex_string} | {:error, {:encode_error, reason}}",
      description: "0x-prefixed hex-encoded calldata",
      example: "0x70a08231..."
    }
  )

  @spec encode_call(String.t(), list()) :: {:ok, String.t()} | {:error, {:encode_error, term()}}
  def encode_call(signature, params) do
    {:ok, Onchain.Hex.encode(ABI.encode(signature, params))}
  rescue
    e -> {:error, {:encode_error, Exception.message(e)}}
  end

  # --- encode_call! ---

  api(:encode_call!, "Encode a function call to 0x-prefixed hex calldata. Raises on error.",
    params: [
      signature: [kind: :value, description: "Function signature, e.g. \"balanceOf(address)\""],
      params: [kind: :value, description: "List of parameter values matching the signature"]
    ],
    returns: %{type: :string, description: "0x-prefixed hex-encoded calldata"}
  )

  @spec encode_call!(String.t(), list()) :: String.t()
  def encode_call!(signature, params) do
    Onchain.Hex.encode(ABI.encode(signature, params))
  end

  # --- decode_response ---

  api(:decode_response, "Decode hex-encoded ABI response data to Elixir values.",
    params: [
      type_signature: [
        kind: :value,
        description:
          ~s{Tuple type signature wrapped in parentheses, e.g. "(uint256)" or "(uint256,bool)". Bare comma-separated types like "uint256,bool" are NOT accepted and raise an unhelpful upstream error.}
      ],
      hex_data: [kind: :value, description: "0x-prefixed hex string of ABI-encoded data"]
    ],
    returns: %{
      type: "{:ok, list} | {:error, {:decode_error, reason}}",
      description: "List of decoded values"
    }
  )

  @spec decode_response(String.t(), String.t()) ::
          {:ok, list()} | {:error, {:decode_error, term()}}
  def decode_response(type_signature, hex_data) do
    case Onchain.Hex.decode(hex_data) do
      {:ok, binary} ->
        {:ok, ABI.decode(type_signature, binary)}

      {:error, {:invalid_hex, _} = reason} ->
        {:error, {:decode_error, reason}}
    end
  rescue
    e -> {:error, {:decode_error, Exception.message(e)}}
  end

  # --- decode_response! ---

  api(:decode_response!, "Decode hex-encoded ABI response data to Elixir values. Raises on error.",
    params: [
      type_signature: [
        kind: :value,
        description:
          ~s{Tuple type signature wrapped in parentheses, e.g. "(uint256)" or "(uint256,bool)". Bare comma-separated types are NOT accepted.}
      ],
      hex_data: [kind: :value, description: "0x-prefixed hex string of ABI-encoded data"]
    ],
    returns: %{type: :list, description: "List of decoded values"}
  )

  @spec decode_response!(String.t(), String.t()) :: list()
  def decode_response!(type_signature, hex_data) do
    ABI.decode(type_signature, Onchain.Hex.decode!(hex_data))
  end

  # --- decode_types ---

  api(:decode_types, "Decode arbitrary ABI-encoded hex data. Alias of decode_response/2.",
    params: [
      type_signature: [
        kind: :value,
        description:
          ~s{Tuple type signature wrapped in parentheses, e.g. "(uint256)" or "(uint256,bool)". Bare comma-separated types are NOT accepted.}
      ],
      hex_data: [kind: :value, description: "0x-prefixed hex string of ABI-encoded data"]
    ],
    returns: %{
      type: "{:ok, list} | {:error, {:decode_error, reason}}",
      description:
        "List of decoded values. Identical to decode_response/2 — use this name when the input isn't an RPC response (mempool calldata, custom ABI payloads)."
    }
  )

  @spec decode_types(String.t(), String.t()) ::
          {:ok, list()} | {:error, {:decode_error, term()}}
  def decode_types(type_signature, hex_data), do: decode_response(type_signature, hex_data)

  # --- decode_types! ---

  api(:decode_types!, "Decode arbitrary ABI-encoded hex data. Alias of decode_response!/2.",
    params: [
      type_signature: [
        kind: :value,
        description:
          ~s{Tuple type signature wrapped in parentheses, e.g. "(uint256)" or "(uint256,bool)". Bare comma-separated types are NOT accepted.}
      ],
      hex_data: [kind: :value, description: "0x-prefixed hex string of ABI-encoded data"]
    ],
    returns: %{type: :list, description: "List of decoded values"}
  )

  @spec decode_types!(String.t(), String.t()) :: list()
  def decode_types!(type_signature, hex_data), do: decode_response!(type_signature, hex_data)
end
