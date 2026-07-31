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
  | `decode_call/3` | Selector-prefixed calldata → decoded function args (forwards opts) |
  | `decode_call!/3` | Same, raises on error |
  | `decode_error/2` | Solidity 0.8.4+ custom-error revert data → `%{error, args}` |
  | `decode_error!/2` | Same, raises on error |
  """

  use Descripex, namespace: "/abi"

  # Exceptions hieroglyph raises on malformed signatures, params, or payloads. These
  # are the *input* failure modes this module converts into `{:error, {_, reason}}`
  # tuples; anything outside the list (UndefinedFunctionError from a typo'd call,
  # BadArityError, KeyError) is a bug here and must propagate.
  #
  # Verified against hieroglyph by probing each entry point:
  #   MatchError                       unparseable signature / truncated or malformed payload
  #   RuntimeError                     signature/params arity mismatch
  #   FunctionClauseError              unknown type, nil/map param
  #   CaseClauseError                  word outside the type's domain (e.g. bool /= 0|1)
  #   ArgumentError                    explicit spec violations (packed mode, parser)
  #   ABI.TypeDecoder.StrictViolation  strict-mode decode violation
  @abi_errors [
    ABI.TypeDecoder.StrictViolation,
    ArgumentError,
    CaseClauseError,
    FunctionClauseError,
    MatchError,
    RuntimeError
  ]

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
    e in @abi_errors -> {:error, {:encode_error, Exception.message(e)}}
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
    e in @abi_errors -> {:error, {:decode_error, Exception.message(e)}}
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

  # --- decode_call ---

  api(:decode_call, "Decode selector-prefixed calldata to function args.",
    params: [
      signature_or_selector: [
        kind: :value,
        description:
          ~s{Function signature like "transfer(address,uint256)" OR a hieroglyph FunctionSelector struct. The 4-byte selector of the signature must match the first 4 bytes of calldata.}
      ],
      hex_calldata: [
        kind: :value,
        description: "0x-prefixed hex string of selector-prefixed ABI-encoded calldata"
      ],
      opts: [
        kind: :value,
        default: [],
        description:
          ~s{Forwarded to hieroglyph's `ABI.decode_call/3`. Pass `decode_structs: true` for a named-field map instead of a positional list.}
      ]
    ],
    returns: %{
      type: "{:ok, list | map} | {:error, {:decode_error, reason}}",
      description:
        ~s|List of args (or map when `decode_structs: true`). Error reasons: `:calldata_too_short`, `:selector_mismatch`, `:no_function_name`, `{:invalid_hex, _}`, or upstream exception message string.|
    }
  )

  @spec decode_call(String.t() | ABI.FunctionSelector.t(), String.t(), keyword()) ::
          {:ok, list() | map()} | {:error, {:decode_error, term()}}
  def decode_call(signature_or_selector, hex_calldata, opts \\ []) do
    with {:ok, binary} <- Onchain.Hex.decode(hex_calldata),
         {:ok, decoded} <- ABI.decode_call(signature_or_selector, binary, opts) do
      {:ok, decoded}
    else
      {:error, {:invalid_hex, _} = reason} -> {:error, {:decode_error, reason}}
      {:error, atom} when is_atom(atom) -> {:error, {:decode_error, atom}}
    end
  rescue
    e in @abi_errors -> {:error, {:decode_error, Exception.message(e)}}
  end

  # --- decode_call! ---

  api(:decode_call!, "Decode selector-prefixed calldata. Raises on error.",
    params: [
      signature_or_selector: [
        kind: :value,
        description: "Function signature string or hieroglyph FunctionSelector struct"
      ],
      hex_calldata: [
        kind: :value,
        description: "0x-prefixed hex string of selector-prefixed calldata"
      ],
      opts: [
        kind: :value,
        default: [],
        description: "Forwarded to hieroglyph's `ABI.decode_call/3` (e.g. `decode_structs: true`)"
      ]
    ],
    returns: %{
      type: "list | map",
      description: "List of decoded args (or map when `decode_structs: true`)"
    }
  )

  @spec decode_call!(String.t() | ABI.FunctionSelector.t(), String.t(), keyword()) ::
          list() | map()
  def decode_call!(signature_or_selector, hex_calldata, opts \\ []) do
    {:ok, decoded} = ABI.decode_call(signature_or_selector, Onchain.Hex.decode!(hex_calldata), opts)
    decoded
  end

  # --- decode_error ---

  api(
    :decode_error,
    "Decode Solidity 0.8.4+ custom-error revert data against a list of candidate error signatures.",
    params: [
      hex_revert_data: [
        kind: :value,
        description: "0x-prefixed hex string of revert data (4-byte error selector + ABI-encoded args)"
      ],
      error_definitions: [
        kind: :value,
        description:
          ~s{List of candidate error signatures like ["InsufficientBalance(uint256,uint256)", "Unauthorized()"] (or hieroglyph FunctionSelector structs). The first one whose 4-byte selector matches the prefix of `hex_revert_data` decodes the args.}
      ]
    ],
    returns: %{
      type: "{:ok, %{error: name, args: list}} | {:error, {:decode_error, reason}}",
      description:
        ~s|Map with the matched error name (or `nil`) and decoded args. Error reasons: `:calldata_too_short`, `:no_match`, `{:invalid_hex, _}`, or upstream exception message string.|
    }
  )

  @spec decode_error(String.t(), [String.t() | ABI.FunctionSelector.t()]) ::
          {:ok, %{error: String.t() | nil, args: list()}}
          | {:error, {:decode_error, term()}}
  def decode_error(hex_revert_data, error_definitions) do
    with {:ok, binary} <- Onchain.Hex.decode(hex_revert_data),
         {:ok, decoded} <- ABI.decode_error(binary, error_definitions) do
      {:ok, decoded}
    else
      {:error, {:invalid_hex, _} = reason} -> {:error, {:decode_error, reason}}
      {:error, atom} when is_atom(atom) -> {:error, {:decode_error, atom}}
    end
  rescue
    e in @abi_errors -> {:error, {:decode_error, Exception.message(e)}}
  end

  # --- decode_error! ---

  api(:decode_error!, "Decode custom-error revert data. Raises on error.",
    params: [
      hex_revert_data: [kind: :value, description: "0x-prefixed hex string of revert data"],
      error_definitions: [
        kind: :value,
        description: "List of candidate error signatures or FunctionSelector structs"
      ]
    ],
    returns: %{
      type: "%{error: name, args: list}",
      description: "Map with the matched error name and decoded args"
    }
  )

  @spec decode_error!(String.t(), [String.t() | ABI.FunctionSelector.t()]) ::
          %{error: String.t() | nil, args: list()}
  def decode_error!(hex_revert_data, error_definitions) do
    {:ok, decoded} = ABI.decode_error(Onchain.Hex.decode!(hex_revert_data), error_definitions)
    decoded
  end
end
