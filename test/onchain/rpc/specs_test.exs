defmodule Onchain.RPC.SpecsTest do
  use ExUnit.Case, async: true

  alias Onchain.RPC.Specs

  describe "lookup/1" do
    test "returns the parsed eth_blockNumber spec" do
      assert %{
               description: description,
               params: [],
               returns: returns
             } = Specs.lookup("eth_blockNumber")

      assert is_binary(description)
      assert description != ""
      assert is_map(returns)
    end

    test "returns nil for unknown methods" do
      assert is_nil(Specs.lookup("eth_missingMethod"))
    end
  end

  test "loads the pinned OpenRPC corpus" do
    assert 78 = map_size(Specs.all())
  end
end
