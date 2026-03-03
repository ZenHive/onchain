defmodule Onchain.Aave.MathTest do
  use ExUnit.Case, async: true

  alias Onchain.Aave.Math

  describe "to_usd/1" do
    test "converts oracle price (10^8 scale)" do
      # ETH at ~$2,500
      assert Decimal.eq?(Math.to_usd(250_000_000_000), Decimal.new("2500"))
    end

    test "converts fractional USD value" do
      assert Decimal.eq?(Math.to_usd(123_456_789), Decimal.new("1.23456789"))
    end

    test "zero returns zero" do
      assert Decimal.eq?(Math.to_usd(0), Decimal.new(0))
    end

    test "large uint256-scale value" do
      # ~$1 trillion in Aave base currency units
      large = 100_000_000_000_000_000_000
      result = Math.to_usd(large)
      assert Decimal.eq?(result, Decimal.new("1000000000000"))
    end

    test "raises on non-integer input" do
      assert_raise FunctionClauseError, fn -> apply(Math, :to_usd, [1.5]) end
      assert_raise FunctionClauseError, fn -> apply(Math, :to_usd, ["123"]) end
    end
  end

  describe "to_ltv/1" do
    test "converts 80% LTV (8000 basis points)" do
      assert Decimal.eq?(Math.to_ltv(8000), Decimal.new("0.8"))
    end

    test "converts 100% (10000 basis points)" do
      assert Decimal.eq?(Math.to_ltv(10_000), Decimal.new(1))
    end

    test "converts typical liquidation threshold (8250 = 82.5%)" do
      assert Decimal.eq?(Math.to_ltv(8250), Decimal.new("0.825"))
    end

    test "zero returns zero" do
      assert Decimal.eq?(Math.to_ltv(0), Decimal.new(0))
    end

    test "raises on non-integer input" do
      assert_raise FunctionClauseError, fn -> apply(Math, :to_ltv, [0.8]) end
    end
  end

  describe "to_health_factor/1" do
    test "converts 1.5 health factor" do
      raw = 1_500_000_000_000_000_000
      assert Decimal.eq?(Math.to_health_factor(raw), Decimal.new("1.5"))
    end

    test "converts exactly 1.0 (liquidation boundary)" do
      raw = 1_000_000_000_000_000_000
      assert Decimal.eq?(Math.to_health_factor(raw), Decimal.new(1))
    end

    test "converts health factor > 10" do
      raw = 10_500_000_000_000_000_000
      assert Decimal.eq?(Math.to_health_factor(raw), Decimal.new("10.5"))
    end

    test "zero returns zero" do
      assert Decimal.eq?(Math.to_health_factor(0), Decimal.new(0))
    end

    test "raises on non-integer input" do
      assert_raise FunctionClauseError, fn -> apply(Math, :to_health_factor, [1.5]) end
    end
  end

  describe "to_ray/1" do
    test "converts 10% annual rate" do
      # 10^26 = 0.1 in ray
      raw = 100_000_000_000_000_000_000_000_000
      assert Decimal.eq?(Math.to_ray(raw), Decimal.new("0.1"))
    end

    test "converts 1 ray (10^27)" do
      raw = 1_000_000_000_000_000_000_000_000_000
      assert Decimal.eq?(Math.to_ray(raw), Decimal.new(1))
    end

    test "converts typical borrow rate (~3.5%)" do
      raw = 35_000_000_000_000_000_000_000_000
      assert Decimal.eq?(Math.to_ray(raw), Decimal.new("0.035"))
    end

    test "zero returns zero" do
      assert Decimal.eq?(Math.to_ray(0), Decimal.new(0))
    end

    test "raises on non-integer input" do
      assert_raise FunctionClauseError, fn -> apply(Math, :to_ray, [%Decimal{}]) end
    end
  end

  describe "to_wad/1" do
    test "converts 1 wad (10^18)" do
      raw = 1_000_000_000_000_000_000
      assert Decimal.eq?(Math.to_wad(raw), Decimal.new(1))
    end

    test "converts fractional wad" do
      raw = 500_000_000_000_000_000
      assert Decimal.eq?(Math.to_wad(raw), Decimal.new("0.5"))
    end

    test "zero returns zero" do
      assert Decimal.eq?(Math.to_wad(0), Decimal.new(0))
    end

    test "raises on non-integer input" do
      assert_raise FunctionClauseError, fn -> apply(Math, :to_wad, ["1"]) end
    end
  end

  describe "consistency" do
    test "to_health_factor and to_wad produce same result for same input" do
      input = 2_500_000_000_000_000_000
      assert Decimal.eq?(Math.to_health_factor(input), Math.to_wad(input))
    end

    test "to_health_factor and to_wad produce same result for zero" do
      assert Decimal.eq?(Math.to_health_factor(0), Math.to_wad(0))
    end
  end
end

defmodule Onchain.Aave.Math.IntegrationTest do
  use ExUnit.Case, async: false

  alias Onchain.Aave.Contracts
  alias Onchain.Aave.Math
  alias Onchain.ABI
  alias Onchain.RPC

  defp rpc_opts do
    [rpc_url: Onchain.RPCCase.rpc_url!()]
  end

  describe "getUserAccountData math" do
    test "to_usd and to_health_factor produce sane values for live position" do
      user = "0xF380B8F1e63e2BEd7CA329CA1FdDbC39B52cC0d3"
      {:ok, user_bin} = Onchain.Address.validate(user)
      {:ok, pool_addr} = Contracts.address(:pool)
      {:ok, calldata} = ABI.encode_call("getUserAccountData(address)", [user_bin])
      {:ok, hex_result} = RPC.eth_call(pool_addr, calldata, rpc_opts())

      {:ok, [collateral, debt, _available, _liq_threshold, _ltv, health_factor]} =
        ABI.decode_response("(uint256,uint256,uint256,uint256,uint256,uint256)", hex_result)

      collateral_usd = Math.to_usd(collateral)
      debt_usd = Math.to_usd(debt)
      hf = Math.to_health_factor(health_factor)

      # Collateral and debt should be positive Decimals
      assert Decimal.gt?(collateral_usd, Decimal.new(0)),
             "Expected collateral > 0, got #{collateral_usd}"

      assert Decimal.gt?(debt_usd, Decimal.new(0)),
             "Expected debt > 0, got #{debt_usd}"

      # Health factor should be > 1 (not liquidatable) and < 100 (sane range)
      assert Decimal.gt?(hf, Decimal.new(1)),
             "Expected health factor > 1, got #{hf}"

      assert Decimal.lt?(hf, Decimal.new(100)),
             "Expected health factor < 100, got #{hf}"
    end
  end

  describe "oracle price math" do
    test "getAssetPrice for WETH returns reasonable USD price" do
      # WETH address on Ethereum mainnet
      weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
      {:ok, weth_bin} = Onchain.Address.validate(weth)
      {:ok, oracle_addr} = Contracts.address(:oracle)
      {:ok, calldata} = ABI.encode_call("getAssetPrice(address)", [weth_bin])
      {:ok, hex_result} = RPC.eth_call(oracle_addr, calldata, rpc_opts())
      {:ok, [raw_price]} = ABI.decode_response("(uint256)", hex_result)

      price = Math.to_usd(raw_price)

      # ETH price should be between $100 and $100,000
      assert Decimal.gt?(price, Decimal.new(100)),
             "Expected ETH price > $100, got $#{price}"

      assert Decimal.lt?(price, Decimal.new(100_000)),
             "Expected ETH price < $100,000, got $#{price}"
    end
  end
end
