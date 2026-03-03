defmodule Onchain.Aave.PoolTest do
  use ExUnit.Case, async: true

  alias Onchain.Aave.Pool

  describe "get_user_account_data/2" do
    test "returns error for invalid address" do
      assert {:error, {:invalid_address, "not_an_address"}} =
               Pool.get_user_account_data("not_an_address")
    end

    test "returns error for unsupported network" do
      # Valid address, but unsupported network
      valid_addr = "0xF380B8F1e63e2BEd7CA329CA1FdDbC39B52cC0d3"

      assert {:error, {:unsupported_network, :polygon}} =
               Pool.get_user_account_data(valid_addr, network: :polygon)
    end
  end

  describe "get_user_account_data!/2" do
    test "raises on invalid address" do
      assert_raise RuntimeError, ~r/get_user_account_data failed.*invalid_address/, fn ->
        Pool.get_user_account_data!("bad_address")
      end
    end

    test "raises on unsupported network" do
      valid_addr = "0xF380B8F1e63e2BEd7CA329CA1FdDbC39B52cC0d3"

      assert_raise RuntimeError, ~r/get_user_account_data failed.*unsupported_network/, fn ->
        Pool.get_user_account_data!(valid_addr, network: :polygon)
      end
    end
  end
end
