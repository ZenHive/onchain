defmodule Onchain.Aave.Pool.IntegrationTest do
  use ExUnit.Case, async: false

  alias Onchain.Aave.Pool

  @moduletag :integration

  # Active Aave V3 borrower — same address used in math/contracts integration tests
  @known_borrower "0xF380B8F1e63e2BEd7CA329CA1FdDbC39B52cC0d3"

  @expected_keys [
    :total_collateral_base,
    :total_debt_base,
    :available_borrows_base,
    :current_liquidation_threshold,
    :ltv,
    :health_factor
  ]

  defp rpc_opts do
    [rpc_url: Onchain.RPCCase.rpc_url!()]
  end

  describe "get_user_account_data/2 with known borrower" do
    test "returns {:ok, map} with all 6 expected keys" do
      {:ok, data} = Pool.get_user_account_data(@known_borrower, rpc_opts())

      for key <- @expected_keys do
        assert Map.has_key?(data, key), "Missing key: #{key}"
      end

      assert map_size(data) == 6
    end

    test "all values are Decimal structs" do
      {:ok, data} = Pool.get_user_account_data(@known_borrower, rpc_opts())

      for {key, value} <- data do
        assert %Decimal{} = value, "Expected Decimal for #{key}, got #{inspect(value)}"
      end
    end

    test "active borrower has collateral > 0 and debt > 0" do
      {:ok, data} = Pool.get_user_account_data(@known_borrower, rpc_opts())

      assert Decimal.gt?(data.total_collateral_base, Decimal.new(0)),
             "Expected collateral > 0, got #{data.total_collateral_base}"

      assert Decimal.gt?(data.total_debt_base, Decimal.new(0)),
             "Expected debt > 0, got #{data.total_debt_base}"
    end

    test "health factor in sane range (1 to 100)" do
      {:ok, data} = Pool.get_user_account_data(@known_borrower, rpc_opts())

      assert Decimal.gt?(data.health_factor, Decimal.new(1)),
             "Expected health factor > 1, got #{data.health_factor}"

      assert Decimal.lt?(data.health_factor, Decimal.new(100)),
             "Expected health factor < 100, got #{data.health_factor}"
    end

    test "ltv and liquidation threshold between 0 and 1" do
      {:ok, data} = Pool.get_user_account_data(@known_borrower, rpc_opts())

      assert Decimal.gt?(data.ltv, Decimal.new(0)),
             "Expected ltv > 0, got #{data.ltv}"

      assert Decimal.lt?(data.ltv, Decimal.new(1)),
             "Expected ltv < 1, got #{data.ltv}"

      assert Decimal.gt?(data.current_liquidation_threshold, Decimal.new(0)),
             "Expected liq_threshold > 0, got #{data.current_liquidation_threshold}"

      assert Decimal.lte?(data.current_liquidation_threshold, Decimal.new(1)),
             "Expected liq_threshold <= 1, got #{data.current_liquidation_threshold}"
    end

    test "Aave invariant: liquidation threshold >= ltv" do
      {:ok, data} = Pool.get_user_account_data(@known_borrower, rpc_opts())

      assert Decimal.gte?(data.current_liquidation_threshold, data.ltv),
             "Expected liq_threshold (#{data.current_liquidation_threshold}) >= ltv (#{data.ltv})"
    end
  end

  describe "get_user_account_data/2 with binary address" do
    test "accepts 20-byte binary address" do
      {:ok, user_bin} = Onchain.Address.validate(@known_borrower)
      {:ok, data} = Pool.get_user_account_data(user_bin, rpc_opts())

      assert map_size(data) == 6
      assert Decimal.gt?(data.total_collateral_base, Decimal.new(0))
    end
  end

  describe "get_user_account_data/2 with zero-position address" do
    test "returns zero Decimals for address with no Aave position" do
      # Ethereum genesis address — extremely unlikely to have an Aave position
      zero_position = "0x0000000000000000000000000000000000000001"
      {:ok, data} = Pool.get_user_account_data(zero_position, rpc_opts())

      assert Decimal.eq?(data.total_collateral_base, Decimal.new(0)),
             "Expected collateral = 0, got #{data.total_collateral_base}"

      assert Decimal.eq?(data.total_debt_base, Decimal.new(0)),
             "Expected debt = 0, got #{data.total_debt_base}"

      assert Decimal.eq?(data.ltv, Decimal.new(0)),
             "Expected ltv = 0, got #{data.ltv}"
    end
  end

  describe "get_user_account_data!/2" do
    test "returns map directly for known borrower" do
      data = Pool.get_user_account_data!(@known_borrower, rpc_opts())

      assert is_map(data)
      assert map_size(data) == 6
      assert %Decimal{} = data.health_factor
    end
  end
end
