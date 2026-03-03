defmodule Onchain.RPC.IntegrationTest do
  use ExUnit.Case, async: false

  alias Onchain.ABI
  alias Onchain.RPC

  @moduletag :integration

  @weth_address "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
  @zero_address "0x0000000000000000000000000000000000000000"

  # EOA with known activity (Vitalik's address)
  @eoa_address "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"

  defp rpc_opts do
    [rpc_url: Onchain.RPCCase.rpc_url!()]
  end

  describe "block_number/1" do
    test "returns current block number as positive integer" do
      assert {:ok, block} = RPC.block_number(rpc_opts())
      assert is_integer(block)
      assert block > 0
    end
  end

  describe "chain_id/1" do
    test "returns mainnet chain ID" do
      assert {:ok, 1} = RPC.chain_id(rpc_opts())
    end
  end

  describe "get_balance/2" do
    test "returns balance for zero address as non-negative integer" do
      assert {:ok, balance} = RPC.get_balance(@zero_address, rpc_opts())
      assert is_integer(balance)
      assert balance >= 0
    end
  end

  describe "eth_call/3" do
    test "WETH totalSupply returns non-empty hex" do
      {:ok, calldata} = ABI.encode_call("totalSupply()", [])
      assert {:ok, hex_result} = RPC.eth_call(@weth_address, calldata, rpc_opts())
      assert is_binary(hex_result)
      assert String.starts_with?(hex_result, "0x")
      # totalSupply returns data, not just "0x"
      assert byte_size(hex_result) > 2
    end

    test "call to EOA returns 0x (not an error)" do
      {:ok, calldata} = ABI.encode_call("totalSupply()", [])
      assert {:ok, "0x"} = RPC.eth_call(@eoa_address, calldata, rpc_opts())
    end
  end

  describe "get_block_by_number/2" do
    test "fetches a known block and returns raw map" do
      assert {:ok, block} = RPC.get_block_by_number(20_000_000, rpc_opts())
      assert is_map(block)
      assert block["number"] == "0x1312d00"
      assert is_binary(block["timestamp"])
      assert is_binary(block["hash"])
    end

    test "accepts 'latest' tag" do
      assert {:ok, block} = RPC.get_block_by_number("latest", rpc_opts())
      assert is_map(block)
      assert is_binary(block["number"])
    end

    test "accepts 'finalized' tag" do
      assert {:ok, block} = RPC.get_block_by_number("finalized", rpc_opts())
      assert is_map(block)
      assert is_binary(block["number"])
    end

    test "accepts hex block number" do
      assert {:ok, block} = RPC.get_block_by_number("0x1312d00", rpc_opts())
      assert block["number"] == "0x1312d00"
    end
  end

  describe "pipeline: ABI.encode_call → RPC.eth_call → ABI.decode_response" do
    test "WETH totalSupply roundtrip returns decoded integer > 0" do
      {:ok, calldata} = ABI.encode_call("totalSupply()", [])
      {:ok, hex_result} = RPC.eth_call(@weth_address, calldata, rpc_opts())
      {:ok, [total_supply]} = ABI.decode_response("(uint256)", hex_result)

      assert is_integer(total_supply)
      assert total_supply > 0
    end
  end
end
