defmodule Onchain.Aave.ContractsTest do
  use ExUnit.Case, async: true

  alias Onchain.Aave.Contracts

  @known_contracts [:pool_addresses_provider, :pool, :oracle, :ui_pool_data_provider]

  describe "address/1" do
    test "returns checksummed address for each known contract" do
      for key <- @known_contracts do
        assert {:ok, addr} = Contracts.address(key)
        assert String.starts_with?(addr, "0x")
        assert String.length(addr) == 42
      end
    end

    test "pool returns expected address" do
      assert {:ok, "0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2"} = Contracts.address(:pool)
    end

    test "pool_addresses_provider returns expected address" do
      assert {:ok, "0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e"} =
               Contracts.address(:pool_addresses_provider)
    end

    test "oracle returns expected address" do
      assert {:ok, "0x54586bE62E3c3580375aE3723C145253060Ca0C2"} = Contracts.address(:oracle)
    end

    test "ui_pool_data_provider returns expected address" do
      assert {:ok, "0x56b7A1012765C285afAC8b8F25C69Bf10ccfE978"} =
               Contracts.address(:ui_pool_data_provider)
    end

    test "returns error for unknown contract" do
      assert {:error, {:unknown_contract, :nonexistent}} = Contracts.address(:nonexistent)
    end

    test "all returned addresses are valid checksummed" do
      for key <- @known_contracts do
        {:ok, addr} = Contracts.address(key)
        assert Onchain.Address.valid?(addr)
        # Verify checksumming is idempotent
        assert {:ok, ^addr} = Onchain.Address.checksum(addr)
      end
    end
  end

  describe "address/2 with network option" do
    test "explicit network: :ethereum works" do
      assert {:ok, _addr} = Contracts.address(:pool, network: :ethereum)
    end

    test "unsupported network returns error" do
      assert {:error, {:unsupported_network, :polygon}} =
               Contracts.address(:pool, network: :polygon)
    end
  end

  describe "address!/1" do
    test "returns address directly" do
      assert "0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2" = Contracts.address!(:pool)
    end

    test "raises on unknown contract" do
      assert_raise RuntimeError, ~r/address lookup failed/, fn ->
        Contracts.address!(:nonexistent)
      end
    end

    test "raises on unsupported network" do
      assert_raise RuntimeError, ~r/address lookup failed/, fn ->
        Contracts.address!(:pool, network: :polygon)
      end
    end
  end

  describe "networks/0" do
    test "returns list containing :ethereum" do
      assert [:ethereum] = Contracts.networks()
    end
  end

  describe "contracts/0" do
    test "returns all 4 contract keys" do
      assert {:ok, keys} = Contracts.contracts()
      assert length(keys) == 4

      for key <- @known_contracts do
        assert key in keys
      end
    end
  end

  describe "contracts/1 with network option" do
    test "explicit network: :ethereum works" do
      assert {:ok, keys} = Contracts.contracts(network: :ethereum)
      assert length(keys) == 4
    end

    test "unsupported network returns error" do
      assert {:error, {:unsupported_network, :polygon}} = Contracts.contracts(network: :polygon)
    end
  end
end
