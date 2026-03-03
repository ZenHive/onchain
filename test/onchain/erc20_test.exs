defmodule Onchain.ERC20Test do
  use ExUnit.Case, async: true

  alias Onchain.ERC20

  # Valid address for param validation tests (doesn't need to be a real token)
  @valid_address "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"

  describe "balance_of/3" do
    test "returns error for invalid holder address" do
      assert {:error, {:invalid_address, "not_an_address"}} =
               ERC20.balance_of(@valid_address, "not_an_address")
    end

    test "returns error for invalid token address" do
      {:ok, holder_bin} = Onchain.Address.validate(@valid_address)

      assert {:error, {:invalid_address, "bad_token"}} =
               ERC20.balance_of("bad_token", holder_bin)
    end
  end

  describe "balance_of!/3" do
    test "raises on invalid holder address" do
      assert_raise RuntimeError, ~r/balance_of failed/, fn ->
        ERC20.balance_of!(@valid_address, "not_an_address")
      end
    end
  end

  describe "allowance/4" do
    test "returns error for invalid owner address" do
      assert {:error, {:invalid_address, "bad_owner"}} =
               ERC20.allowance(@valid_address, "bad_owner", @valid_address)
    end

    test "returns error for invalid spender address" do
      assert {:error, {:invalid_address, "bad_spender"}} =
               ERC20.allowance(@valid_address, @valid_address, "bad_spender")
    end

    test "returns error for invalid token address" do
      {:ok, addr_bin} = Onchain.Address.validate(@valid_address)

      assert {:error, {:invalid_address, "bad_token"}} =
               ERC20.allowance("bad_token", addr_bin, addr_bin)
    end
  end

  describe "allowance!/4" do
    test "raises on invalid owner address" do
      assert_raise RuntimeError, ~r/allowance failed/, fn ->
        ERC20.allowance!(@valid_address, "bad_owner", @valid_address)
      end
    end
  end

  describe "decimals/2" do
    test "returns error for invalid token address" do
      assert {:error, {:invalid_address, "not_a_token"}} =
               ERC20.decimals("not_a_token")
    end
  end

  describe "decimals!/2" do
    test "raises on invalid token address" do
      assert_raise RuntimeError, ~r/decimals failed/, fn ->
        ERC20.decimals!("not_a_token")
      end
    end
  end

  describe "symbol/2" do
    test "returns error for invalid token address" do
      assert {:error, {:invalid_address, "not_a_token"}} =
               ERC20.symbol("not_a_token")
    end
  end

  describe "symbol!/2" do
    test "raises on invalid token address" do
      assert_raise RuntimeError, ~r/symbol failed/, fn ->
        ERC20.symbol!("not_a_token")
      end
    end
  end
end
