defmodule Onchain.ERC721Test do
  use ExUnit.Case, async: true

  alias Onchain.ERC721

  # Valid address for param validation tests (doesn't need to be a real NFT)
  @valid_address "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D"

  describe "balance_of/3" do
    test "returns error for invalid owner address" do
      assert {:error, {:invalid_address, "not_an_address"}} =
               ERC721.balance_of(@valid_address, "not_an_address")
    end

    test "returns error for invalid contract address" do
      {:ok, owner_bin} = Onchain.Address.validate(@valid_address)

      assert {:error, {:invalid_address, "bad_contract"}} =
               ERC721.balance_of("bad_contract", owner_bin)
    end
  end

  describe "balance_of!/3" do
    test "raises on invalid owner address" do
      assert_raise RuntimeError, ~r/balance_of failed/, fn ->
        ERC721.balance_of!(@valid_address, "not_an_address")
      end
    end
  end

  describe "owner_of/3" do
    test "returns error for invalid contract address" do
      assert {:error, {:invalid_address, "bad_contract"}} =
               ERC721.owner_of("bad_contract", 1)
    end
  end

  describe "owner_of!/3" do
    test "raises on invalid contract address" do
      assert_raise RuntimeError, ~r/owner_of failed/, fn ->
        ERC721.owner_of!("bad_contract", 1)
      end
    end
  end

  describe "token_uri/3" do
    test "returns error for invalid contract address" do
      assert {:error, {:invalid_address, "bad_contract"}} =
               ERC721.token_uri("bad_contract", 1)
    end
  end

  describe "token_uri!/3" do
    test "raises on invalid contract address" do
      assert_raise RuntimeError, ~r/token_uri failed/, fn ->
        ERC721.token_uri!("bad_contract", 1)
      end
    end
  end

  describe "name/2" do
    test "returns error for invalid contract address" do
      assert {:error, {:invalid_address, "not_a_contract"}} =
               ERC721.name("not_a_contract")
    end
  end

  describe "name!/2" do
    test "raises on invalid contract address" do
      assert_raise RuntimeError, ~r/name failed/, fn ->
        ERC721.name!("not_a_contract")
      end
    end
  end

  describe "symbol/2" do
    test "returns error for invalid contract address" do
      assert {:error, {:invalid_address, "not_a_contract"}} =
               ERC721.symbol("not_a_contract")
    end
  end

  describe "symbol!/2" do
    test "raises on invalid contract address" do
      assert_raise RuntimeError, ~r/symbol failed/, fn ->
        ERC721.symbol!("not_a_contract")
      end
    end
  end

  describe "get_approved/3" do
    test "returns error for invalid contract address" do
      assert {:error, {:invalid_address, "bad_contract"}} =
               ERC721.get_approved("bad_contract", 1)
    end
  end

  describe "get_approved!/3" do
    test "raises on invalid contract address" do
      assert_raise RuntimeError, ~r/get_approved failed/, fn ->
        ERC721.get_approved!("bad_contract", 1)
      end
    end
  end

  describe "approved_for_all?/4" do
    test "returns error for invalid owner address" do
      assert {:error, {:invalid_address, "bad_owner"}} =
               ERC721.approved_for_all?(@valid_address, "bad_owner", @valid_address)
    end

    test "returns error for invalid operator address" do
      assert {:error, {:invalid_address, "bad_operator"}} =
               ERC721.approved_for_all?(@valid_address, @valid_address, "bad_operator")
    end

    test "returns error for invalid contract address" do
      {:ok, addr_bin} = Onchain.Address.validate(@valid_address)

      assert {:error, {:invalid_address, "bad_contract"}} =
               ERC721.approved_for_all?("bad_contract", addr_bin, addr_bin)
    end
  end

  describe "approved_for_all!/4" do
    test "raises on invalid owner address" do
      assert_raise RuntimeError, ~r/approved_for_all\? failed/, fn ->
        ERC721.approved_for_all!(@valid_address, "bad_owner", @valid_address)
      end
    end
  end
end
