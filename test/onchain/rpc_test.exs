defmodule Onchain.RPCTest do
  use ExUnit.Case, async: true

  alias Onchain.RPC

  # --- Unit tests: input validation (no network calls) ---

  describe "eth_call/3 input validation" do
    test "rejects address with wrong byte size (not 20 bytes)" do
      short_addr = "0x" <> String.duplicate("aa", 10)
      assert {:error, {:invalid_address, ^short_addr}} = RPC.eth_call(short_addr, "0x18160ddd")
    end

    test "rejects address with invalid hex characters" do
      bad_addr = "0xZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
      assert {:error, {:invalid_address, ^bad_addr}} = RPC.eth_call(bad_addr, "0x18160ddd")
    end

    test "rejects data without 0x prefix" do
      addr = "0x" <> String.duplicate("aa", 20)
      assert {:error, {:invalid_data, "18160ddd"}} = RPC.eth_call(addr, "18160ddd")
    end

    test "rejects data with invalid hex characters" do
      addr = "0x" <> String.duplicate("aa", 20)
      assert {:error, {:invalid_data, "0xZZZZ"}} = RPC.eth_call(addr, "0xZZZZ")
    end

    test "rejects non-binary address" do
      assert {:error, {:invalid_address, 12_345}} = RPC.eth_call(12_345, "0x18160ddd")
    end

    test "accepts 20-byte binary address" do
      # Will fail at RPC level (no server), but should pass input validation
      addr = <<1::160>>
      result = RPC.eth_call(addr, "0x18160ddd")
      # Should NOT be an invalid_address error
      refute match?({:error, {:invalid_address, _}}, result)
    end

    test "accepts bare hex address without 0x prefix" do
      # 40 hex chars = 20 bytes, valid address without 0x prefix
      bare_addr = String.duplicate("aa", 20)
      result = RPC.eth_call(bare_addr, "0x18160ddd")
      # Should NOT be an invalid_address error — Address.validate handles bare hex
      refute match?({:error, {:invalid_address, _}}, result)
    end
  end

  describe "get_balance/2 input validation" do
    test "rejects address with wrong byte size" do
      short_addr = "0x" <> String.duplicate("aa", 10)
      assert {:error, {:invalid_address, ^short_addr}} = RPC.get_balance(short_addr)
    end

    test "rejects invalid hex address" do
      bad_addr = "0xnotreallyhex000000000000000000000000000000"
      assert {:error, {:invalid_address, ^bad_addr}} = RPC.get_balance(bad_addr)
    end
  end

  describe "eth_send_raw_transaction/2 input validation" do
    test "rejects data without 0x prefix" do
      assert {:error, {:invalid_data, "deadbeef"}} = RPC.eth_send_raw_transaction("deadbeef")
    end

    test "rejects data with invalid hex characters" do
      assert {:error, {:invalid_data, "0xZZZZ"}} = RPC.eth_send_raw_transaction("0xZZZZ")
    end
  end

  # --- Bang variant tests (raise on invalid input) ---

  describe "eth_call!/3" do
    test "raises on invalid address" do
      assert_raise RuntimeError, ~r/eth_call failed/, fn ->
        RPC.eth_call!("0xshort", "0x18160ddd")
      end
    end

    test "raises on invalid data" do
      addr = "0x" <> String.duplicate("aa", 20)

      assert_raise RuntimeError, ~r/eth_call failed/, fn ->
        RPC.eth_call!(addr, "no_prefix")
      end
    end
  end

  describe "eth_send_raw_transaction!/2" do
    test "raises on invalid data" do
      assert_raise RuntimeError, ~r/eth_send_raw_transaction failed/, fn ->
        RPC.eth_send_raw_transaction!("no_prefix")
      end
    end
  end

  describe "get_balance!/2" do
    test "raises on invalid address" do
      assert_raise RuntimeError, ~r/get_balance failed/, fn ->
        RPC.get_balance!("0xshort")
      end
    end
  end

  describe "block_number!/1" do
    test "raises when RPC unavailable" do
      assert_raise RuntimeError, ~r/block_number failed/, fn ->
        RPC.block_number!(rpc_url: "http://localhost:1")
      end
    end
  end

  describe "chain_id!/1" do
    test "raises when RPC unavailable" do
      assert_raise RuntimeError, ~r/chain_id failed/, fn ->
        RPC.chain_id!(rpc_url: "http://localhost:1")
      end
    end
  end
end

defmodule Onchain.RPC.IntegrationTest do
  use ExUnit.Case, async: false

  alias Onchain.ABI
  alias Onchain.RPC

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
