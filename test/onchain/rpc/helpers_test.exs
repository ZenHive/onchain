defmodule Onchain.RPC.HelpersTest do
  use ExUnit.Case, async: true

  alias Onchain.RPC.Helpers

  describe "maybe_put_revert_data_hex/1" do
    test "adds :data as 0x hex when :revert binary present and :data absent" do
      revert = <<8, 195, 121, 160, 0x01>>
      map = %{code: 3, message: "execution reverted", revert: revert}

      assert %{code: 3, message: "execution reverted", revert: ^revert, data: "0x08c379a001"} =
               Helpers.maybe_put_revert_data_hex(map)
    end

    test "does not overwrite existing :data" do
      map = %{code: 3, message: "x", revert: <<1>>, data: "0xabcd"}

      assert %{data: "0xabcd"} = Helpers.maybe_put_revert_data_hex(map)
    end

    test "leaves map unchanged when :revert absent" do
      map = %{code: -32_603, message: "internal error"}

      assert ^map = Helpers.maybe_put_revert_data_hex(map)
    end

    test "empty revert binary encodes to 0x" do
      map = %{code: 3, message: "execution reverted", revert: <<>>}

      assert %{data: "0x"} = Helpers.maybe_put_revert_data_hex(map)
    end
  end
end
