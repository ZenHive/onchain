defmodule Onchain.Aave.UiPoolDataProvider.IntegrationTest do
  use ExUnit.Case, async: false

  alias Onchain.Aave.Types.AggregatedReserveData
  alias Onchain.Aave.Types.BaseCurrencyInfo
  alias Onchain.Aave.Types.UserReserveData
  alias Onchain.Aave.UiPoolDataProvider

  @moduletag :integration

  # Active Aave V3 borrower — same address used in pool integration tests
  @known_borrower "0xF380B8F1e63e2BEd7CA329CA1FdDbC39B52cC0d3"

  defp rpc_opts do
    [rpc_url: Onchain.RPCCase.rpc_url!()]
  end

  # --- get_reserves_list ---

  describe "get_reserves_list/1" do
    test "returns non-empty list of checksummed addresses" do
      {:ok, addresses} = UiPoolDataProvider.get_reserves_list(rpc_opts())

      assert is_list(addresses)
      assert addresses != []

      # All addresses should be checksummed 0x strings
      Enum.each(addresses, fn addr ->
        assert String.starts_with?(addr, "0x")
        assert String.length(addr) == 42
      end)
    end

    test "includes known tokens (WETH, USDC)" do
      {:ok, addresses} = UiPoolDataProvider.get_reserves_list(rpc_opts())

      weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
      usdc = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"

      assert weth in addresses, "Expected WETH in reserves list"
      assert usdc in addresses, "Expected USDC in reserves list"
    end
  end

  describe "get_reserves_list!/1" do
    test "returns list directly" do
      addresses = UiPoolDataProvider.get_reserves_list!(rpc_opts())

      assert is_list(addresses)
      assert addresses != []
    end
  end

  # --- get_reserves_data ---

  describe "get_reserves_data/1" do
    test "returns {reserves, base_currency_info} tuple" do
      {:ok, {reserves, base}} = UiPoolDataProvider.get_reserves_data(rpc_opts())

      assert is_list(reserves)
      assert reserves != []
      assert %BaseCurrencyInfo{} = base
    end

    test "reserves are AggregatedReserveData structs with correct types" do
      {:ok, {reserves, _base}} = UiPoolDataProvider.get_reserves_data(rpc_opts())

      first = hd(reserves)
      assert %AggregatedReserveData{} = first

      # Identity
      assert is_binary(first.underlying_asset)
      assert String.starts_with?(first.underlying_asset, "0x")
      assert is_binary(first.name)
      assert is_binary(first.symbol)
      assert is_integer(first.decimals)

      # Risk params are Decimal
      assert %Decimal{} = first.base_ltv_as_collateral
      assert %Decimal{} = first.reserve_liquidation_threshold
      assert %Decimal{} = first.reserve_liquidation_bonus
      assert %Decimal{} = first.reserve_factor

      # Flags
      assert is_boolean(first.usage_as_collateral_enabled)
      assert is_boolean(first.borrowing_enabled)
      assert is_boolean(first.is_active)
      assert is_boolean(first.is_frozen)

      # Rates are Decimal
      assert %Decimal{} = first.liquidity_rate
      assert %Decimal{} = first.variable_borrow_rate

      # Addresses are checksummed strings
      assert String.starts_with?(first.a_token_address, "0x")
      assert String.starts_with?(first.variable_debt_token_address, "0x")
      assert String.starts_with?(first.price_oracle, "0x")

      # Amounts are raw integers
      assert is_integer(first.available_liquidity)
      assert is_integer(first.total_scaled_variable_debt)
      assert is_integer(first.price_in_market_reference_currency)
    end

    test "WETH reserve has sane risk parameters" do
      {:ok, {reserves, _base}} = UiPoolDataProvider.get_reserves_data(rpc_opts())

      weth =
        Enum.find(reserves, fn r -> r.symbol == "WETH" end)

      assert weth != nil, "WETH not found in reserves"

      # LTV between 0 and 1
      assert Decimal.gt?(weth.base_ltv_as_collateral, Decimal.new("0"))
      assert Decimal.lt?(weth.base_ltv_as_collateral, Decimal.new("1"))

      # Liquidation threshold > LTV
      assert Decimal.gte?(weth.reserve_liquidation_threshold, weth.base_ltv_as_collateral)

      # Liquidation bonus > 1 (e.g. 1.05 = 5% bonus)
      assert Decimal.gt?(weth.reserve_liquidation_bonus, Decimal.new("1"))

      # Active and not frozen
      assert weth.is_active == true
      assert weth.is_frozen == false
    end

    test "base currency info has sane values" do
      {:ok, {_reserves, base}} = UiPoolDataProvider.get_reserves_data(rpc_opts())

      assert %BaseCurrencyInfo{} = base
      # Aave uses 10^8 as base currency unit
      assert base.market_reference_currency_unit == 100_000_000
      # USD price should be 1.0 (market ref = USD)
      assert Decimal.eq?(base.market_reference_currency_price_in_usd, Decimal.new("1"))
      # ETH price should be > $100 and < $100,000
      assert Decimal.gt?(base.network_base_token_price_in_usd, Decimal.new("100"))
      assert Decimal.lt?(base.network_base_token_price_in_usd, Decimal.new("100000"))
      assert base.network_base_token_price_decimals == 8
    end
  end

  describe "get_reserves_data!/1" do
    test "returns tuple directly" do
      {reserves, base} = UiPoolDataProvider.get_reserves_data!(rpc_opts())

      assert is_list(reserves)
      assert %BaseCurrencyInfo{} = base
    end
  end

  # --- get_user_reserves_data ---

  describe "get_user_reserves_data/2 with known borrower" do
    test "returns {user_reserves, e_mode_id} tuple" do
      {:ok, {user_reserves, e_mode_id}} =
        UiPoolDataProvider.get_user_reserves_data(@known_borrower, rpc_opts())

      assert is_list(user_reserves)
      assert user_reserves != []
      assert is_integer(e_mode_id)
    end

    test "user reserves are UserReserveData structs" do
      {:ok, {user_reserves, _e_mode}} =
        UiPoolDataProvider.get_user_reserves_data(@known_borrower, rpc_opts())

      first = hd(user_reserves)
      assert %UserReserveData{} = first
      assert is_binary(first.underlying_asset)
      assert String.starts_with?(first.underlying_asset, "0x")
      assert is_integer(first.scaled_a_token_balance)
      assert is_boolean(first.usage_as_collateral_enabled_on_user)
      assert is_integer(first.scaled_variable_debt)
    end

    test "known borrower has at least one non-zero position" do
      {:ok, {user_reserves, _e_mode}} =
        UiPoolDataProvider.get_user_reserves_data(@known_borrower, rpc_opts())

      active =
        Enum.filter(user_reserves, fn r ->
          r.scaled_a_token_balance > 0 or r.scaled_variable_debt > 0
        end)

      assert active != [], "Expected at least one active position for known borrower"
    end
  end

  describe "get_user_reserves_data/2 with binary address" do
    test "accepts 20-byte binary address" do
      {:ok, user_bin} = Onchain.Address.validate(@known_borrower)

      {:ok, {user_reserves, _e_mode}} =
        UiPoolDataProvider.get_user_reserves_data(user_bin, rpc_opts())

      assert is_list(user_reserves)
      assert user_reserves != []
    end
  end

  describe "get_user_reserves_data!/2" do
    test "returns tuple directly" do
      {user_reserves, e_mode_id} =
        UiPoolDataProvider.get_user_reserves_data!(@known_borrower, rpc_opts())

      assert is_list(user_reserves)
      assert is_integer(e_mode_id)
    end
  end
end
