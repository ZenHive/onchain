defmodule Onchain.Solidity do
  @moduledoc """
  Solidity ABI parser powered by Alloy via Rustler NIF.

  Parses ABI JSON (standard `solc` output) into structured Elixir maps with
  function signatures, selectors, parameter types, events, and errors —
  everything needed to generate typed contract wrappers.

  ## Output Structure

  Returns a `parsed_abi()` map with four keys:

  - `:functions` — list of `function_info()` maps with `:name`, `:signature`,
    `:selector`, `:return_type`, `:state_mutability`, `:inputs`, `:outputs`
  - `:events` — list of `event_info()` maps with `:name`, `:signature`, `:topic`,
    `:anonymous`, `:inputs`
  - `:errors` — list of `error_info()` maps with `:name`, `:signature`, `:selector`,
    `:inputs`
  - `:constructor` — `constructor_info()` map with `:inputs`, `:state_mutability`
    (or `nil`)

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
  | File not found / unreadable | `{:error, {:file_error, reason}}` |

  ## Functions

  | Function | Purpose |
  |----------|---------|
  | `parse_abi_json/1` | Parse ABI JSON string → structured map |
  | `parse_abi_json!/1` | Same, raises on error |
  | `parse_abi_file/1` | Read file + parse ABI JSON |
  | `parse_abi_file!/1` | Same, raises on error |
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
end
