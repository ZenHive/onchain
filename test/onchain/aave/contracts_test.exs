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

defmodule Onchain.Aave.Contracts.IntegrationTest do
  use ExUnit.Case, async: false

  alias Onchain.Aave.Contracts
  alias Onchain.ABI
  alias Onchain.RPC

  defp rpc_opts do
    [rpc_url: Onchain.RPCCase.rpc_url!()]
  end

  describe "on-chain address verification" do
    test "PoolAddressesProvider.getPool() matches stored :pool address" do
      {:ok, provider_addr} = Contracts.address(:pool_addresses_provider)
      {:ok, calldata} = ABI.encode_call("getPool()", [])
      {:ok, hex_result} = RPC.eth_call(provider_addr, calldata, rpc_opts())
      {:ok, [pool_addr_raw]} = ABI.decode_response("(address)", hex_result)

      {:ok, pool_on_chain} = Onchain.Address.checksum(pool_addr_raw)
      {:ok, pool_stored} = Contracts.address(:pool)

      assert Onchain.Address.equal?(pool_on_chain, pool_stored),
             "On-chain pool #{pool_on_chain} != stored #{pool_stored}"
    end

    test "PoolAddressesProvider.getPriceOracle() matches stored :oracle address" do
      {:ok, provider_addr} = Contracts.address(:pool_addresses_provider)
      {:ok, calldata} = ABI.encode_call("getPriceOracle()", [])
      {:ok, hex_result} = RPC.eth_call(provider_addr, calldata, rpc_opts())
      {:ok, [oracle_addr_raw]} = ABI.decode_response("(address)", hex_result)

      {:ok, oracle_on_chain} = Onchain.Address.checksum(oracle_addr_raw)
      {:ok, oracle_stored} = Contracts.address(:oracle)

      assert Onchain.Address.equal?(oracle_on_chain, oracle_stored),
             "On-chain oracle #{oracle_on_chain} != stored #{oracle_stored}"
    end

    @tag :integration
    test "Pool.getUserAccountData() returns position for known borrower" do
      # Active Aave V3 position with collateral + debt
      user = "0xF380B8F1e63e2BEd7CA329CA1FdDbC39B52cC0d3"
      {:ok, user_bin} = Onchain.Address.validate(user)
      {:ok, pool_addr} = Contracts.address(:pool)
      {:ok, calldata} = ABI.encode_call("getUserAccountData(address)", [user_bin])
      {:ok, hex_result} = RPC.eth_call(pool_addr, calldata, rpc_opts())

      {:ok, [collateral, debt, available, liq_threshold, ltv, health_factor]} =
        ABI.decode_response("(uint256,uint256,uint256,uint256,uint256,uint256)", hex_result)

      # All values are non-negative integers
      assert collateral > 0, "Expected collateral > 0"
      assert debt > 0, "Expected debt > 0 (active borrow position)"
      assert available >= 0
      assert liq_threshold > 0 and liq_threshold <= 10_000
      assert ltv > 0 and ltv <= 10_000
      assert health_factor > 0

      # Sanity: health factor should be > 1 (not liquidatable)
      hf_decimal = Onchain.Decimal.to_decimal(health_factor, 18)
      assert Decimal.gt?(hf_decimal, Decimal.new(1)), "Expected health factor > 1, got #{hf_decimal}"
    end

    test "UiPoolDataProvider.getReservesList(provider) returns non-empty list" do
      {:ok, ui_pool_data_provider} = Contracts.address(:ui_pool_data_provider)
      {:ok, provider_addr} = Contracts.address(:pool_addresses_provider)
      {:ok, provider_addr_bin} = Onchain.Address.validate(provider_addr)
      {:ok, calldata} = ABI.encode_call("getReservesList(address)", [provider_addr_bin])
      {:ok, hex_result} = RPC.eth_call(ui_pool_data_provider, calldata, rpc_opts())
      {:ok, [reserves]} = ABI.decode_response("(address[])", hex_result)

      assert is_list(reserves)
      assert reserves != []
      assert Enum.all?(reserves, &Onchain.Address.valid?/1)
    end
  end
end
