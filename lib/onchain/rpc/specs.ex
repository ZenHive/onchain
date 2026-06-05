defmodule Onchain.RPC.Specs do
  @moduledoc """
  Compile-time lookup table for the vendored Ethereum OpenRPC method specs.
  """

  @spec_path Path.expand("../../../priv/specs/openrpc-v1.0.0-beta.4.json", __DIR__)
  @external_resource @spec_path

  @raw_spec @spec_path |> File.read!() |> Jason.decode!()

  @specs_by_method_name Map.new(@raw_spec["methods"], fn method ->
                          description =
                            method["description"] ||
                              method["summary"] ||
                              ""

                          {method["name"],
                           %{
                             params: Map.get(method, "params", []),
                             returns: method["result"],
                             description: description
                           }}
                        end)

  @type method_spec :: %{
          params: [map()],
          returns: map(),
          description: String.t()
        }

  @doc "Returns all vendored OpenRPC method specs keyed by JSON-RPC method name."
  @spec all() :: %{optional(String.t()) => method_spec()}
  def all, do: @specs_by_method_name

  @doc "Looks up a vendored OpenRPC method spec by JSON-RPC method name."
  @spec lookup(String.t()) :: method_spec() | nil
  def lookup(method) when is_binary(method), do: Map.get(@specs_by_method_name, method)
end
