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

  describe "get_block_by_number/2 input validation" do
    test "rejects negative integer" do
      assert {:error, {:invalid_block_id, -1}} = RPC.get_block_by_number(-1)
    end

    test "rejects non-integer, non-string input" do
      assert {:error, {:invalid_block_id, :foo}} = RPC.get_block_by_number(:foo)
    end

    test "rejects invalid hex string" do
      assert {:error, {:invalid_block_id, "0xZZZZ"}} = RPC.get_block_by_number("0xZZZZ")
    end

    test "rejects unknown string tag" do
      assert {:error, {:invalid_block_id, "unknown_tag"}} = RPC.get_block_by_number("unknown_tag")
    end
  end

  describe "get_block_by_number!/2" do
    test "raises on invalid input" do
      assert_raise RuntimeError, ~r/get_block_by_number failed/, fn ->
        RPC.get_block_by_number!(-1)
      end
    end
  end
end
