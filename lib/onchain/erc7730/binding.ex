defmodule Onchain.ERC7730.Binding do
  @moduledoc """
  Binding evaluator for ERC-7730 descriptors.

  Given a parsed descriptor and a concrete signing request — calldata, an
  EIP-712 typed message, or an ERC-4337 UserOperation — `resolve/3` decides
  **which display format applies** and decodes the bound data into a name →
  value map ready for the display-rule engine.

  ## Binding rules

  | Request | Match on |
  |---------|----------|
  | `{:calldata, address, chain_id, hex_data}` | contract deployment `{chain_id, address}` + 4-byte selector |
  | `{:eip712, payload}` | EIP-712 `domain` fields + `primaryType` |
  | `{:user_op, address, chain_id, user_op}` | unwraps `callData`, then binds as calldata |

  ## Proxy detection

  Reference implementations (Ledger's `python-erc7730`, Uniswap's descriptors)
  bind by matching the transaction's target against the `deployments` list, and
  delegate proxy/implementation resolution to an optional `addressMatcher` URI.
  Resolving a matcher (or an EIP-1967 implementation slot behind a proxy)
  requires on-chain reads and is registry/runtime-side — out of scope here. This
  evaluator binds against the literal `deployments` list; when a descriptor
  carries an `addressMatcher` and no deployment matches, the error reason notes
  that an unresolved matcher was present.

  The resolution result is a map consumed by `Onchain.ERC7730.Formatter`:

      %{
        format: format(),            # the matched display format
        signature: %ABI.FunctionSelector{} | nil,
        message: %{name => value},   # decoded bound data (path "#." root)
        types: %{name => abi_type},  # ABI type per message field
        envelope: %{to: _, value: _, from: _}  # transaction envelope (path "@." root)
      }
  """

  use Descripex, namespace: "/erc7730/binding"

  alias Onchain.ABI, as: OnchainABI
  alias Onchain.Address
  alias Onchain.ERC7730.Descriptor
  alias Onchain.Hex

  @type request ::
          {:calldata, String.t() | binary(), non_neg_integer(), String.t()}
          | {:eip712, map()}
          | {:user_op, String.t() | binary(), non_neg_integer(), map()}

  @type resolution :: %{
          format: Descriptor.format(),
          signature: ABI.FunctionSelector.t() | nil,
          message: %{optional(String.t()) => term()},
          types: %{optional(String.t()) => term()},
          envelope: map()
        }

  api(:resolve, "Resolve which display format applies to a signing request and decode the bound data.",
    params: [
      descriptor: [kind: :value, description: "Parsed %Onchain.ERC7730.Descriptor{}"],
      request: [
        kind: :value,
        description:
          "{:calldata, address, chain_id, hex_data} | {:eip712, payload} | {:user_op, address, chain_id, user_op}"
      ],
      opts: [
        kind: :value,
        default: [],
        description: "Envelope overrides for the @. root: :value (native value), :from (sender)"
      ]
    ],
    returns: %{
      type: "{:ok, resolution} | {:error, {tag, reason}}",
      description:
        "Resolution map (format/signature/message/types/envelope). Errors: :context_mismatch, :no_deployment_match, :no_format_match, :decode_error, :invalid_request, :missing_calldata"
    }
  )

  @spec resolve(Descriptor.t(), request(), keyword()) ::
          {:ok, resolution()} | {:error, {atom(), term()}}
  def resolve(descriptor, request, opts \\ [])

  def resolve(%Descriptor{context: {:contract, ctx}} = descriptor, {:calldata, address, chain_id, hex_data}, opts) do
    with {:ok, _} <- match_deployment(ctx, chain_id, address),
         {:ok, selector} <- selector_of(hex_data),
         {:ok, key, format, fs} <- find_format_by_selector(descriptor, selector),
         {:ok, message, types} <- decode_calldata(fs, hex_data) do
      {:ok,
       %{
         format: format,
         signature: fs,
         message: message,
         types: types,
         envelope: envelope(address, opts),
         format_key: key
       }}
    end
  end

  def resolve(%Descriptor{context: {:contract, _}}, {:eip712, _}, _opts),
    do: {:error, {:context_mismatch, "descriptor is a contract context; got an eip712 request"}}

  def resolve(%Descriptor{context: {:eip712, ctx}} = descriptor, {:eip712, payload}, opts) do
    with {:ok, domain} <- fetch(payload, "domain", %{}),
         {:ok, primary_type} <- fetch(payload, "primaryType"),
         {:ok, message} <- fetch(payload, "message", %{}),
         :ok <- match_domain(ctx, domain),
         {:ok, _key, format, fs} <- find_format_by_type(descriptor, primary_type) do
      verifying = stringify_keys(domain)["verifyingContract"]

      {:ok,
       %{
         format: format,
         signature: fs,
         message: stringify_keys(message),
         types: types_from_selector(fs),
         envelope: %{to: verifying, value: Keyword.get(opts, :value, 0), from: Keyword.get(opts, :from)}
       }}
    end
  end

  def resolve(%Descriptor{context: {:eip712, _}}, {:calldata, _, _, _}, _opts),
    do: {:error, {:context_mismatch, "descriptor is an eip712 context; got a calldata request"}}

  def resolve(%Descriptor{} = descriptor, {:user_op, address, chain_id, user_op}, opts) do
    case fetch(user_op, "callData") do
      {:ok, call_data} when is_binary(call_data) ->
        resolve(descriptor, {:calldata, address, chain_id, call_data}, opts)

      {:ok, _other} ->
        {:error, {:missing_calldata, "user_op callData is not a hex string"}}

      {:error, _} ->
        {:error, {:missing_calldata, "user_op has no callData"}}
    end
  end

  def resolve(%Descriptor{}, request, _opts), do: {:error, {:invalid_request, request}}

  # --- deployment matching ---

  defp match_deployment(%{deployments: deployments} = ctx, chain_id, address) do
    match =
      Enum.find(deployments, fn dep ->
        dep.chain_id == chain_id and Address.equal?(dep.address, address)
      end)

    cond do
      not is_nil(match) -> {:ok, match}
      is_nil(ctx.address_matcher) -> {:error, {:no_deployment_match, {chain_id, address}}}
      true -> {:error, {:no_deployment_match, {:unresolved_address_matcher, ctx.address_matcher}}}
    end
  end

  # --- domain matching (EIP-712) ---

  defp match_domain(%{domain: nil}, _domain), do: :ok

  defp match_domain(%{domain: expected}, actual) when is_map(expected) do
    actual = stringify_keys(actual)
    expected = stringify_keys(expected)

    # Only compare keys the descriptor actually constrains; ignore the rest.
    mismatch =
      Enum.find(expected, fn {key, expected_value} ->
        actual_value = Map.get(actual, key)
        not is_nil(actual_value) and not domain_value_equal?(key, expected_value, actual_value)
      end)

    case mismatch do
      nil -> :ok
      {key, _} -> {:error, {:domain_mismatch, key}}
    end
  end

  defp domain_value_equal?("verifyingContract", a, b), do: Address.equal?(a, b)
  defp domain_value_equal?("chainId", a, b), do: to_int(a) == to_int(b)
  defp domain_value_equal?(_key, a, b), do: a == b

  # --- format lookup ---

  defp find_format_by_selector(descriptor, selector) do
    descriptor.display.formats
    |> Enum.find_value(fn {key, format} ->
      case function_selector(key) do
        {:ok, fs, sel} when sel == selector -> {key, format, fs}
        _ -> nil
      end
    end)
    |> case do
      {key, format, fs} -> {:ok, key, format, fs}
      nil -> {:error, {:no_format_match, Hex.encode(selector)}}
    end
  end

  defp find_format_by_type(descriptor, primary_type) do
    descriptor.display.formats
    |> Enum.find_value(fn {key, format} ->
      case parse_selector(key) do
        {:ok, %{function: ^primary_type} = fs} -> {key, format, fs}
        _ -> nil
      end
    end)
    |> case do
      {key, format, fs} -> {:ok, key, format, fs}
      nil -> {:error, {:no_format_match, primary_type}}
    end
  end

  defp function_selector(key) do
    with {:ok, fs} <- parse_selector(key),
         bare = ABI.FunctionSelector.encode(fs),
         <<sel::binary-size(4), _::binary>> <- Cartouche.Hash.keccak(bare) do
      {:ok, fs, sel}
    end
  rescue
    _ -> :error
  end

  defp parse_selector(key) do
    {:ok, ABI.FunctionSelector.decode(key)}
  rescue
    _ -> {:error, {:invalid_format_key, key}}
  end

  # --- calldata decoding ---

  defp selector_of(hex_data) do
    case Hex.decode(hex_data) do
      {:ok, <<selector::binary-size(4), _::binary>>} -> {:ok, selector}
      {:ok, _short} -> {:error, {:decode_error, :calldata_too_short}}
      {:error, reason} -> {:error, {:decode_error, reason}}
    end
  end

  defp decode_calldata(fs, hex_data) do
    case OnchainABI.decode_call(fs, hex_data) do
      {:ok, values} ->
        names = field_names(fs)
        message = names |> Enum.zip(values) |> Map.new()
        {:ok, message, types_from_selector(fs)}

      {:error, reason} ->
        {:error, {:decode_error, reason}}
    end
  end

  defp field_names(%ABI.FunctionSelector{types: types}) do
    types
    |> Enum.with_index()
    |> Enum.map(fn {type, i} -> Map.get(type, :name) || Integer.to_string(i) end)
  end

  defp types_from_selector(%ABI.FunctionSelector{types: types}) do
    types
    |> Enum.with_index()
    |> Map.new(fn {type, i} ->
      {Map.get(type, :name) || Integer.to_string(i), Map.get(type, :type)}
    end)
  end

  defp types_from_selector(_), do: %{}

  # --- helpers ---

  defp envelope(address, opts) do
    %{to: address, value: Keyword.get(opts, :value, 0), from: Keyword.get(opts, :from)}
  end

  defp fetch(map, key, default \\ :__none__) do
    case Map.get(map, key, Map.get(map, safe_atom(key), :__missing__)) do
      :__missing__ when default == :__none__ -> {:error, {:missing_key, key}}
      :__missing__ -> {:ok, default}
      value -> {:ok, value}
    end
  end

  defp safe_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> :__no_such_atom__
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end

  defp stringify_keys(other), do: other

  defp to_int(v) when is_integer(v), do: v
  defp to_int(v) when is_binary(v), do: String.to_integer(v)
end
