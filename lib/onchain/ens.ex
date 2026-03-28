defmodule Onchain.ENS do
  @moduledoc """
  ENS (Ethereum Name Service) resolution and namehash computation.

  ## Does

  - Compute EIP-137 namehash for ENS names (`namehash/1`)
  - Normalize names (lowercase ASCII, strip trailing dot)
  - Validate name structure (reject empty labels, non-ASCII)
  - Forward resolution: ENS name → ETH address (`resolve/2`)
  - Reverse resolution: ETH address → ENS name (`reverse/2`)
  - Text record queries (`text/3`), contenthash, ABI, pubkey retrieval
  - Look up resolver contracts (`resolver/2`)
  - Configurable registry address via `:registry` opt

  ## Does Not

  - CCIP-Read / EIP-3668 off-chain lookups (future enhancement)
  - Wildcard resolution (ENSIP-10)
  - ENS name registration or management (write operations)
  - Full UTS-46 / ENSIP-15 Unicode normalization (internationalized names)
  - Caching — consumers manage their own cache
  - Multi-coin address resolution (only ETH via `addr(bytes32)`)

  ## Functions

  | Function | Purpose |
  |----------|---------|
  | `namehash/1` | ENS name -> 32-byte EIP-137 node hash |
  | `namehash!/1` | Same, raises on error |
  | `resolver/2` | ENS name -> resolver contract address |
  | `resolver!/2` | Same, raises on error |
  | `resolve/2` | ENS name -> ETH address (forward resolution) |
  | `resolve!/2` | Same, raises on error |
  | `reverse/2` | ETH address -> ENS name (reverse resolution) |
  | `reverse!/2` | Same, raises on error |
  | `text/3` | Retrieve a text record (avatar, url, etc.) |
  | `text!/3` | Same, raises on error |
  | `contenthash/2` | Retrieve the contenthash record |
  | `contenthash!/2` | Same, raises on error |
  | `pubkey/2` | Retrieve the ECDSA public key |
  | `pubkey!/2` | Same, raises on error |
  | `abi/3` | Retrieve ABI data (ENSIP-7) |
  | `abi!/3` | Same, raises on error |
  """

  # TODO: CCIP-Read / EIP-3668 off-chain lookups — needed for names using off-chain resolvers
  # TODO: Wildcard resolution (ENSIP-10) — needed for *.subdomain patterns
  # TODO: Full UTS-46 / ENSIP-15 Unicode normalization — needed for internationalized names
  # TODO: Multi-coin address resolution — currently only ETH via addr(bytes32)

  use Descripex, namespace: "/ens"

  alias Onchain.Address
  alias Onchain.Contract
  alias Onchain.Hex

  # TODO: Remove when upstream specs are fixed (abi: ABI.decode/2 no_return, signet: Hex specs).
  # Upstream Signet.Hex spec cascade through Contract.call/5 → ABI.decode_response/2.
  @dialyzer {:no_match,
             [
               resolve: 2,
               resolve!: 2,
               resolver: 2,
               resolver!: 2,
               reverse: 2,
               reverse!: 2,
               text: 3,
               text!: 3,
               contenthash: 2,
               contenthash!: 2,
               pubkey: 2,
               pubkey!: 2,
               abi: 3,
               abi!: 3,
               with_resolver: 6,
               get_resolver: 2
             ]}
  @dialyzer {:no_return,
             [
               resolve!: 1,
               resolve!: 2,
               resolver!: 1,
               resolver!: 2,
               reverse!: 1,
               reverse!: 2,
               text!: 2,
               text!: 3,
               contenthash!: 1,
               contenthash!: 2,
               pubkey!: 1,
               pubkey!: 2,
               abi!: 2,
               abi!: 3
             ]}
  @dialyzer {:no_contracts,
             [
               resolve!: 1,
               resolve!: 2,
               resolver!: 1,
               resolver!: 2,
               reverse!: 1,
               reverse!: 2,
               text!: 2,
               text!: 3,
               contenthash!: 1,
               contenthash!: 2,
               pubkey!: 1,
               pubkey!: 2,
               abi!: 2,
               abi!: 3
             ]}

  @ens_registry "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e"
  @addr_reverse_suffix "addr.reverse"
  @zero_address <<0::160>>
  @zero_node <<0::256>>

  # --- namehash ---

  api(:namehash, "Compute the EIP-137 namehash for an ENS name.",
    params: [
      name: [kind: :value, description: "ENS name, e.g. \"vitalik.eth\""]
    ],
    returns: %{
      type: "{:ok, <<_::256>>} | {:error, term}",
      description: "32-byte keccak256 node hash per EIP-137"
    }
  )

  @spec namehash(String.t()) :: {:ok, binary()} | {:error, {:invalid_name, String.t()}}
  def namehash(name) when is_binary(name) do
    normalized = normalize_name(name)

    # After normalization, "." becomes "" — reject this rather than silently
    # returning the zero node hash. Callers who want the root node can pass "".
    if name != "" and normalized == "" do
      {:error, {:invalid_name, name}}
    else
      case validate_name(normalized) do
        :ok ->
          hash = compute_namehash(normalized)
          {:ok, hash}

        {:error, _} = error ->
          error
      end
    end
  end

  # --- namehash! ---

  api(:namehash!, "Compute the EIP-137 namehash. Raises on error.",
    params: [
      name: [kind: :value, description: "ENS name, e.g. \"vitalik.eth\""]
    ],
    returns: %{type: "<<_::256>>", description: "32-byte keccak256 node hash"}
  )

  @spec namehash!(String.t()) :: binary()
  def namehash!(name) do
    case namehash(name) do
      {:ok, hash} -> hash
      {:error, reason} -> raise "namehash failed: #{inspect(reason)}"
    end
  end

  # --- resolver ---

  api(:resolver, "Look up the resolver contract address for an ENS name.",
    params: [
      name: [kind: :value, description: "ENS name (e.g., \"vitalik.eth\")"],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout, :registry"]
    ],
    returns: %{
      type: "{:ok, String.t()} | {:error, term()}",
      description: "EIP-55 checksummed resolver address"
    }
  )

  @spec resolver(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def resolver(name, opts \\ []) do
    with {:ok, node} <- namehash(name),
         {:ok, resolver_addr} <- get_resolver(node, opts) do
      {:ok, resolver_addr}
    else
      {:error, :no_resolver} -> {:error, {:no_resolver, name}}
      error -> error
    end
  end

  # --- resolver! ---

  api(:resolver!, "Look up the resolver contract address. Raises on error.",
    params: [
      name: [kind: :value, description: "ENS name (e.g., \"vitalik.eth\")"],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout, :registry"]
    ],
    returns: %{type: "String.t()", description: "EIP-55 checksummed resolver address"}
  )

  @spec resolver!(String.t(), keyword()) :: String.t()
  def resolver!(name, opts \\ []) do
    case resolver(name, opts) do
      {:ok, addr} -> addr
      {:error, reason} -> raise "resolver lookup failed: #{inspect(reason)}"
    end
  end

  # --- resolve ---

  api(:resolve, "Resolve an ENS name to an ETH address (forward resolution).",
    params: [
      name: [kind: :value, description: "ENS name (e.g., \"vitalik.eth\")"],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout, :registry"]
    ],
    returns: %{
      type: "{:ok, String.t()} | {:error, term()}",
      description: "EIP-55 checksummed ETH address"
    }
  )

  @spec resolve(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def resolve(name, opts \\ []) do
    with_resolver(name, "addr(bytes32)", [], "(address)", opts, fn [addr_bin] ->
      if addr_bin == @zero_address do
        {:error, {:no_address, name}}
      else
        Address.checksum(addr_bin)
      end
    end)
  end

  # --- resolve! ---

  api(:resolve!, "Resolve an ENS name to an ETH address. Raises on error.",
    params: [
      name: [kind: :value, description: "ENS name (e.g., \"vitalik.eth\")"],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout, :registry"]
    ],
    returns: %{type: "String.t()", description: "EIP-55 checksummed ETH address"}
  )

  @spec resolve!(String.t(), keyword()) :: String.t()
  def resolve!(name, opts \\ []) do
    case resolve(name, opts) do
      {:ok, addr} -> addr
      {:error, reason} -> raise "resolve failed: #{inspect(reason)}"
    end
  end

  # --- reverse ---

  api(:reverse, "Reverse-resolve an ETH address to an ENS name.",
    params: [
      address: [kind: :value, description: "ETH address as 0x hex string or 20-byte binary"],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout, :registry"]
    ],
    returns: %{
      type: "{:ok, String.t()} | {:error, term()}",
      description: "ENS name (e.g., \"vitalik.eth\")"
    }
  )

  @spec reverse(String.t() | binary(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def reverse(address, opts \\ []) do
    with {:ok, reverse} <- reverse_name(address),
         {:ok, node} <- namehash(reverse),
         {:ok, resolver_addr} <- get_resolver(node, opts),
         {:ok, [name]} <-
           Contract.call(resolver_addr, "name(bytes32)", [node], "(string)", opts) do
      if name == "" do
        {:error, {:no_reverse, address}}
      else
        {:ok, name}
      end
    else
      {:error, :no_resolver} -> {:error, {:no_resolver, address}}
      error -> error
    end
  end

  # --- reverse! ---

  api(:reverse!, "Reverse-resolve an ETH address to an ENS name. Raises on error.",
    params: [
      address: [kind: :value, description: "ETH address as 0x hex string or 20-byte binary"],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout, :registry"]
    ],
    returns: %{type: "String.t()", description: "ENS name (e.g., \"vitalik.eth\")"}
  )

  @spec reverse!(String.t() | binary(), keyword()) :: String.t()
  def reverse!(address, opts \\ []) do
    case reverse(address, opts) do
      {:ok, name} -> name
      {:error, reason} -> raise "reverse failed: #{inspect(reason)}"
    end
  end

  # --- text ---

  api(:text, "Retrieve a text record from an ENS name's resolver.",
    params: [
      name: [kind: :value, description: "ENS name (e.g., \"vitalik.eth\")"],
      key: [kind: :value, description: ~s{Text record key (e.g., "avatar", "url", "com.twitter")}],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout, :registry"]
    ],
    returns: %{
      type: "{:ok, String.t()} | {:error, term()}",
      description: "Text record value"
    }
  )

  @spec text(String.t(), String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def text(name, key, opts \\ []) do
    with_resolver(name, "text(bytes32,string)", [key], "(string)", opts, fn [value] ->
      if value == "" do
        {:error, {:empty_record, {name, key}}}
      else
        {:ok, value}
      end
    end)
  end

  # --- text! ---

  api(:text!, "Retrieve a text record. Raises on error.",
    params: [
      name: [kind: :value, description: "ENS name (e.g., \"vitalik.eth\")"],
      key: [kind: :value, description: ~s{Text record key (e.g., "avatar", "url", "com.twitter")}],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout, :registry"]
    ],
    returns: %{type: "String.t()", description: "Text record value"}
  )

  @spec text!(String.t(), String.t(), keyword()) :: String.t()
  def text!(name, key, opts \\ []) do
    case text(name, key, opts) do
      {:ok, value} -> value
      {:error, reason} -> raise "text lookup failed: #{inspect(reason)}"
    end
  end

  # --- contenthash ---

  api(:contenthash, "Retrieve the contenthash record from an ENS name's resolver.",
    params: [
      name: [kind: :value, description: "ENS name (e.g., \"vitalik.eth\")"],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout, :registry"]
    ],
    returns: %{
      type: "{:ok, binary()} | {:error, term()}",
      description: "Raw contenthash bytes (ENSIP-7 encoded)"
    }
  )

  @spec contenthash(String.t(), keyword()) :: {:ok, binary()} | {:error, term()}
  def contenthash(name, opts \\ []) do
    with_resolver(name, "contenthash(bytes32)", [], "(bytes)", opts, fn [hash] ->
      if hash == <<>> do
        {:error, {:empty_record, {name, "contenthash"}}}
      else
        {:ok, hash}
      end
    end)
  end

  # --- contenthash! ---

  api(:contenthash!, "Retrieve the contenthash record. Raises on error.",
    params: [
      name: [kind: :value, description: "ENS name (e.g., \"vitalik.eth\")"],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout, :registry"]
    ],
    returns: %{type: "binary()", description: "Raw contenthash bytes"}
  )

  @spec contenthash!(String.t(), keyword()) :: binary()
  def contenthash!(name, opts \\ []) do
    case contenthash(name, opts) do
      {:ok, hash} -> hash
      {:error, reason} -> raise "contenthash lookup failed: #{inspect(reason)}"
    end
  end

  # --- pubkey ---

  api(:pubkey, "Retrieve the ECDSA public key from an ENS name's resolver.",
    params: [
      name: [kind: :value, description: "ENS name (e.g., \"vitalik.eth\")"],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout, :registry"]
    ],
    returns: %{
      type: "{:ok, {binary(), binary()}} | {:error, term()}",
      description: "Tuple of {x, y} 32-byte coordinates"
    }
  )

  @spec pubkey(String.t(), keyword()) :: {:ok, {binary(), binary()}} | {:error, term()}
  def pubkey(name, opts \\ []) do
    with_resolver(name, "pubkey(bytes32)", [], "(bytes32,bytes32)", opts, fn [x, y] ->
      zero = <<0::256>>

      if x == zero and y == zero do
        {:error, {:empty_record, {name, "pubkey"}}}
      else
        {:ok, {x, y}}
      end
    end)
  end

  # --- pubkey! ---

  api(:pubkey!, "Retrieve the ECDSA public key. Raises on error.",
    params: [
      name: [kind: :value, description: "ENS name (e.g., \"vitalik.eth\")"],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout, :registry"]
    ],
    returns: %{type: "{binary(), binary()}", description: "Tuple of {x, y} 32-byte coordinates"}
  )

  @spec pubkey!(String.t(), keyword()) :: {binary(), binary()}
  def pubkey!(name, opts \\ []) do
    case pubkey(name, opts) do
      {:ok, coords} -> coords
      {:error, reason} -> raise "pubkey lookup failed: #{inspect(reason)}"
    end
  end

  # --- abi ---

  api(:abi, "Retrieve ABI data from an ENS name's resolver (ENSIP-7).",
    params: [
      name: [kind: :value, description: "ENS name (e.g., \"vitalik.eth\")"],
      content_types: [
        kind: :value,
        description: "Bitmask of content types: 1=JSON, 2=zlib, 4=CBOR, 8=URI"
      ],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout, :registry"]
    ],
    returns: %{
      type: "{:ok, {non_neg_integer(), binary()}} | {:error, term()}",
      description: "Tuple of {content_type, abi_data}"
    }
  )

  @spec abi(String.t(), non_neg_integer(), keyword()) ::
          {:ok, {non_neg_integer(), binary()}} | {:error, term()}
  def abi(name, content_types, opts \\ []) do
    with_resolver(name, "ABI(bytes32,uint256)", [content_types], "(uint256,bytes)", opts, fn
      [ct, data] ->
        if ct == 0 do
          {:error, {:empty_record, {name, "abi"}}}
        else
          {:ok, {ct, data}}
        end
    end)
  end

  # --- abi! ---

  api(:abi!, "Retrieve ABI data. Raises on error.",
    params: [
      name: [kind: :value, description: "ENS name (e.g., \"vitalik.eth\")"],
      content_types: [
        kind: :value,
        description: "Bitmask of content types: 1=JSON, 2=zlib, 4=CBOR, 8=URI"
      ],
      opts: [kind: :value, default: [], description: "Options: :rpc_url, :timeout, :registry"]
    ],
    returns: %{type: "{non_neg_integer(), binary()}", description: "Tuple of {content_type, abi_data}"}
  )

  @spec abi!(String.t(), non_neg_integer(), keyword()) :: {non_neg_integer(), binary()}
  def abi!(name, content_types, opts \\ []) do
    case abi(name, content_types, opts) do
      {:ok, result} -> result
      {:error, reason} -> raise "abi lookup failed: #{inspect(reason)}"
    end
  end

  # --- Private helpers ---

  # Shared resolver lookup: namehash → get_resolver → Contract.call, then apply result_fn.
  # Centralizes the error mapping for :no_resolver across all resolver-based functions.
  @spec with_resolver(String.t(), String.t(), list(), String.t(), keyword(), function()) ::
          {:ok, term()} | {:error, term()}
  defp with_resolver(name, sig, extra_args, return_type, opts, result_fn) do
    with {:ok, node} <- namehash(name),
         {:ok, resolver_addr} <- get_resolver(node, opts),
         {:ok, result} <-
           Contract.call(resolver_addr, sig, [node | extra_args], return_type, opts) do
      result_fn.(result)
    else
      {:error, :no_resolver} -> {:error, {:no_resolver, name}}
      error -> error
    end
  end

  @doc false
  # Builds the reverse resolution name from an address.
  # "0xd8dA..." → "d8da6bf2...6cc2.addr.reverse" (40 lowercase hex chars, no 0x prefix)
  @spec reverse_name(String.t() | binary()) :: {:ok, String.t()} | {:error, term()}
  defp reverse_name(address) do
    with {:ok, addr_bin} <- Address.validate(address) do
      hex = addr_bin |> Hex.encode() |> String.trim_leading("0x")
      {:ok, "#{hex}.#{@addr_reverse_suffix}"}
    end
  end

  @doc false
  # Queries the ENS Registry for the resolver address of a name.
  @spec get_resolver(binary(), keyword()) :: {:ok, String.t()} | {:error, term()}
  defp get_resolver(namehash_bin, opts) do
    registry = Keyword.get(opts, :registry, @ens_registry)

    with {:ok, [resolver_bin]} <-
           Contract.call(registry, "resolver(bytes32)", [namehash_bin], "(address)", opts) do
      if resolver_bin == @zero_address do
        {:error, :no_resolver}
      else
        Address.checksum(resolver_bin)
      end
    end
  end

  @doc false
  # Lowercase and strip trailing dot for DNS-style compatibility
  defp normalize_name(name) do
    name
    |> String.downcase()
    |> String.trim_trailing(".")
  end

  @doc false
  # Validate that all labels are non-empty and ASCII-only
  defp validate_name(""), do: :ok

  defp validate_name(name) do
    labels = String.split(name, ".")

    if Enum.all?(labels, &valid_label?/1) do
      :ok
    else
      {:error, {:invalid_name, name}}
    end
  end

  @doc false
  # A valid label is non-empty, ASCII alphanumeric with hyphens only in the middle.
  defp valid_label?(""), do: false
  defp valid_label?(label), do: String.match?(label, ~r/^[a-z0-9]([a-z0-9\-]*[a-z0-9])?$/)

  @doc false
  # EIP-137 namehash: fold right over dot-separated labels with keccak256
  defp compute_namehash(""), do: @zero_node

  defp compute_namehash(name) do
    name
    |> String.split(".")
    |> Enum.reverse()
    |> Enum.reduce(@zero_node, fn label, node ->
      label_hash = Signet.Hash.keccak(label)
      Signet.Hash.keccak(node <> label_hash)
    end)
  end
end
