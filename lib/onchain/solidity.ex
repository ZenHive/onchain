defmodule Onchain.Solidity do
  @moduledoc """
  Solidity ABI parser powered by Alloy and solang-parser via Rustler NIF.

  Supports two input formats:

  - **ABI JSON** — standard `solc` output. Parses function signatures, selectors,
    parameter types, events, and errors. Use `parse_abi_json/1`.
  - **Solidity source** — raw `.sol` files. Recovers struct definitions, enum
    definitions, NatSpec documentation, and constants that ABI JSON discards.
    Use `parse_sol/1`.

  ## Output Structure

  Both parsers return maps with `:functions`, `:events`, `:errors`, `:constructor`.
  The `.sol` parser additionally returns `:structs`, `:enums`, `:constants`, and
  attaches `:natspec` to each function entry.

  ### Parameter Maps

  All parameter maps use `:ty` (not `:type`) for the Solidity type string —
  this follows Alloy's naming convention since `type` is a reserved keyword in Rust.
  Nested struct/tuple parameters include `:components` with recursive `param()` maps.

  ### Selectors & Topics

  Selectors and topic hashes are `0x`-prefixed hex strings (e.g. `"0x70a08231"`),
  consistent with the `Onchain.Hex` convention used throughout the codebase.

  The `:return_type` field on each function produces tuple-type strings compatible
  with `Onchain.ABI.decode_response/2` (e.g. `"(uint256,uint256,bool)"`).

  ## Error Format

  | Source | Error Shape |
  |--------|-------------|
  | Invalid JSON / malformed ABI | `{:error, {:parse_error, reason}}` |
  | Invalid Solidity source | `{:error, {:parse_error, reason}}` |
  | File not found / unreadable | `{:error, {:file_error, reason}}` |

  ## Functions

  | Function | Purpose |
  |----------|---------|
  | `parse_abi_json/1` | Parse ABI JSON string → structured map |
  | `parse_abi_json!/1` | Same, raises on error |
  | `parse_abi_file/1` | Read file + parse ABI JSON |
  | `parse_abi_file!/1` | Same, raises on error |
  | `parse_sol/1` | Parse Solidity source string → enriched map |
  | `parse_sol!/1` | Same, raises on error |
  | `parse_sol_file/1` | Read file + parse Solidity source |
  | `parse_sol_file!/1` | Same, raises on error |
  """

  use Descripex, namespace: "/solidity"
  use Rustler, otp_app: :onchain, crate: "onchain_solidity"

  # --- Types ---

  @typedoc "ABI parameter with Solidity type and optional nested components."
  @type param :: %{name: String.t(), ty: String.t(), components: [param()]}

  @typedoc "Event parameter — like `param()` but includes `:indexed` flag."
  @type event_param :: %{
          name: String.t(),
          ty: String.t(),
          indexed: boolean(),
          components: [param()]
        }

  @typedoc "Parsed ABI function entry."
  @type function_info :: %{
          name: String.t(),
          signature: String.t(),
          selector: String.t(),
          return_type: String.t(),
          state_mutability: String.t(),
          inputs: [param()],
          outputs: [param()]
        }

  @typedoc "Parsed function entry with NatSpec (from .sol source)."
  @type function_info_with_natspec :: %{
          name: String.t(),
          signature: String.t(),
          selector: String.t(),
          return_type: String.t(),
          state_mutability: String.t(),
          inputs: [param()],
          outputs: [param()],
          natspec: natspec() | nil
        }

  @typedoc "Parsed ABI event entry."
  @type event_info :: %{
          name: String.t(),
          signature: String.t(),
          topic: String.t(),
          anonymous: boolean(),
          inputs: [event_param()]
        }

  @typedoc "Parsed ABI error entry."
  @type error_info :: %{
          name: String.t(),
          signature: String.t(),
          selector: String.t(),
          inputs: [param()]
        }

  @typedoc "Parsed ABI constructor entry, or `nil` if not present."
  @type constructor_info :: %{inputs: [param()], state_mutability: String.t()} | nil

  @typedoc "Complete parsed ABI with functions, events, errors, and constructor."
  @type parsed_abi :: %{
          functions: [function_info()],
          events: [event_info()],
          errors: [error_info()],
          constructor: constructor_info()
        }

  @typedoc "Struct definition from Solidity source."
  @type struct_info :: %{name: String.t(), fields: [%{name: String.t(), ty: String.t()}]}

  @typedoc "Enum definition from Solidity source."
  @type enum_info :: %{name: String.t(), variants: [String.t()]}

  @typedoc "Constant definition from Solidity source."
  @type constant_info :: %{name: String.t(), ty: String.t(), value: String.t()}

  @typedoc "NatSpec documentation for a function."
  @type natspec :: %{
          notice: String.t(),
          params: %{String.t() => String.t()},
          returns: %{String.t() => String.t()}
        }

  @typedoc "Complete parsed Solidity source with structs, enums, constants, and NatSpec."
  @type parsed_sol :: %{
          functions: [function_info_with_natspec()],
          events: [event_info()],
          errors: [error_info()],
          constructor: constructor_info(),
          structs: [struct_info()],
          enums: [enum_info()],
          constants: [constant_info()]
        }

  # --- parse_abi_json ---

  api(:parse_abi_json, "Parse a Solidity ABI JSON string into structured Elixir data.",
    params: [
      json: [
        kind: :value,
        description: "ABI JSON string (standard solc output format — array of ABI items)"
      ]
    ],
    returns: %{
      type: "{:ok, parsed_abi()} | {:error, {:parse_error, String.t()}}",
      description: "Parsed ABI with :functions, :events, :errors, :constructor keys"
    }
  )

  @spec parse_abi_json(String.t()) :: {:ok, parsed_abi()} | {:error, {:parse_error, String.t()}}
  def parse_abi_json(_json), do: :erlang.nif_error(:nif_not_loaded)

  # --- parse_abi_json! ---

  api(:parse_abi_json!, "Parse a Solidity ABI JSON string. Raises on error.",
    params: [
      json: [
        kind: :value,
        description: "ABI JSON string (standard solc output format — array of ABI items)"
      ]
    ],
    returns: %{
      type: "parsed_abi()",
      description: "Parsed ABI with :functions, :events, :errors, :constructor keys"
    }
  )

  @spec parse_abi_json!(String.t()) :: parsed_abi()
  def parse_abi_json!(json) do
    case parse_abi_json(json) do
      {:ok, result} -> result
      {:error, {:parse_error, reason}} -> raise "ABI parse failed: #{reason}"
      {:error, reason} -> raise "ABI parse failed: #{inspect(reason)}"
    end
  end

  # --- parse_abi_file ---

  api(:parse_abi_file, "Read a file and parse its contents as Solidity ABI JSON.",
    params: [
      path: [
        kind: :value,
        description: "Path to an ABI JSON file (e.g. \"priv/abis/erc20.json\")"
      ]
    ],
    returns: %{
      type: "{:ok, parsed_abi()} | {:error, {:parse_error, String.t()} | {:file_error, String.t()}}",
      description: "Parsed ABI with :functions, :events, :errors, :constructor keys"
    }
  )

  @spec parse_abi_file(String.t()) ::
          {:ok, parsed_abi()} | {:error, {:parse_error, String.t()} | {:file_error, String.t()}}
  def parse_abi_file(path) do
    case File.read(path) do
      {:ok, contents} -> parse_abi_json(contents)
      {:error, reason} -> {:error, {:file_error, "#{path}: #{reason}"}}
    end
  end

  # --- parse_abi_file! ---

  api(:parse_abi_file!, "Read a file and parse its contents as Solidity ABI JSON. Raises on error.",
    params: [
      path: [
        kind: :value,
        description: "Path to an ABI JSON file (e.g. \"priv/abis/erc20.json\")"
      ]
    ],
    returns: %{
      type: "parsed_abi()",
      description: "Parsed ABI with :functions, :events, :errors, :constructor keys"
    }
  )

  @spec parse_abi_file!(String.t()) :: parsed_abi()
  def parse_abi_file!(path) do
    case parse_abi_file(path) do
      {:ok, result} -> result
      {:error, {:parse_error, reason}} -> raise "ABI parse failed: #{reason}"
      {:error, {:file_error, reason}} -> raise "ABI file error: #{reason}"
      {:error, reason} -> raise "ABI error: #{inspect(reason)}"
    end
  end

  # --- parse_sol ---

  api(
    :parse_sol,
    "Parse a Solidity source string into structured Elixir data with structs, enums, and NatSpec.",
    params: [
      source: [
        kind: :value,
        description: "Solidity source code string (e.g. an interface definition)"
      ]
    ],
    returns: %{
      type: "{:ok, parsed_sol()} | {:error, {:parse_error, String.t()}}",
      description:
        "Enriched parsed data with :functions, :events, :errors, :constructor, :structs, :enums, :constants keys"
    }
  )

  @spec parse_sol(String.t()) :: {:ok, parsed_sol()} | {:error, {:parse_error, String.t()}}
  def parse_sol(_source), do: :erlang.nif_error(:nif_not_loaded)

  # --- parse_sol! ---

  api(:parse_sol!, "Parse a Solidity source string. Raises on error.",
    params: [
      source: [
        kind: :value,
        description: "Solidity source code string (e.g. an interface definition)"
      ]
    ],
    returns: %{
      type: "parsed_sol()",
      description:
        "Enriched parsed data with :functions, :events, :errors, :constructor, :structs, :enums, :constants keys"
    }
  )

  @spec parse_sol!(String.t()) :: parsed_sol()
  def parse_sol!(source) do
    case parse_sol(source) do
      {:ok, result} -> result
      {:error, {:parse_error, reason}} -> raise "Solidity parse failed: #{reason}"
      {:error, reason} -> raise "Solidity parse failed: #{inspect(reason)}"
    end
  end

  # --- parse_sol_file ---

  api(:parse_sol_file, "Read a file and parse its contents as Solidity source.",
    params: [
      path: [
        kind: :value,
        description: "Path to a .sol file (e.g. \"priv/contracts/IPool.sol\")"
      ]
    ],
    returns: %{
      type: "{:ok, parsed_sol()} | {:error, {:parse_error, String.t()} | {:file_error, String.t()}}",
      description:
        "Enriched parsed data with :functions, :events, :errors, :constructor, :structs, :enums, :constants keys"
    }
  )

  @spec parse_sol_file(String.t()) ::
          {:ok, parsed_sol()} | {:error, {:parse_error, String.t()} | {:file_error, String.t()}}
  def parse_sol_file(path) do
    case File.read(path) do
      {:ok, contents} -> parse_sol(contents)
      {:error, reason} -> {:error, {:file_error, "#{path}: #{reason}"}}
    end
  end

  # --- parse_sol_file! ---

  api(:parse_sol_file!, "Read a file and parse its contents as Solidity source. Raises on error.",
    params: [
      path: [
        kind: :value,
        description: "Path to a .sol file (e.g. \"priv/contracts/IPool.sol\")"
      ]
    ],
    returns: %{
      type: "parsed_sol()",
      description:
        "Enriched parsed data with :functions, :events, :errors, :constructor, :structs, :enums, :constants keys"
    }
  )

  @spec parse_sol_file!(String.t()) :: parsed_sol()
  def parse_sol_file!(path) do
    case parse_sol_file(path) do
      {:ok, result} -> result
      {:error, {:parse_error, reason}} -> raise "Solidity parse failed: #{reason}"
      {:error, {:file_error, reason}} -> raise "Solidity file error: #{reason}"
      {:error, reason} -> raise "Solidity error: #{inspect(reason)}"
    end
  end
end
