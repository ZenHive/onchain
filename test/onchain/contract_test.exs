defmodule Onchain.ContractTest do
  use ExUnit.Case, async: true

  alias Onchain.Contract

  describe "call/5" do
    test "returns error for invalid address" do
      assert {:error, {:invalid_address, "not_an_address"}} =
               Contract.call("not_an_address", "balanceOf(address)", [], "(uint256)")
    end

    test "returns error for empty string address" do
      assert {:error, {:invalid_address, ""}} =
               Contract.call("", "balanceOf(address)", [], "(uint256)")
    end

    test "returns error for malformed ABI signature" do
      valid_addr = "0x" <> String.duplicate("ab", 20)

      assert {:error, {:encode_error, _}} =
               Contract.call(valid_addr, "not a valid signature!!!", [], "(uint256)")
    end
  end

  describe "call!/5" do
    test "raises on invalid address" do
      assert_raise RuntimeError, ~r/contract call failed.*invalid_address/, fn ->
        Contract.call!("bad_address", "balanceOf(address)", [], "(uint256)")
      end
    end
  end
end
