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

    test "accepts 20-byte raw binary address (internal callers pass binaries)" do
      addr = <<1::160>>
      result = RPC.eth_call(addr, "0x18160ddd")
      refute match?({:error, {:invalid_address, _}}, result)
    end

    test "rejects bare hex address without 0x prefix" do
      bare_addr = String.duplicate("aa", 20)
      assert {:error, {:invalid_address, ^bare_addr}} = RPC.eth_call(bare_addr, "0x18160ddd")
    end
  end

  describe "eth_call/3 block validation" do
    test "rejects invalid block value" do
      addr = "0x" <> String.duplicate("aa", 20)
      assert {:error, {:invalid_block, :foo}} = RPC.eth_call(addr, "0x18160ddd", block: :foo)
    end

    test "rejects negative integer block" do
      addr = "0x" <> String.duplicate("aa", 20)
      assert {:error, {:invalid_block, -1}} = RPC.eth_call(addr, "0x18160ddd", block: -1)
    end

    test "accepts integer block (passes input validation)" do
      addr = "0x" <> String.duplicate("aa", 20)
      result = RPC.eth_call(addr, "0x18160ddd", block: 15_000_000)
      refute match?({:error, {:invalid_block, _}}, result)
    end

    test "accepts tag block (passes input validation)" do
      addr = "0x" <> String.duplicate("aa", 20)
      result = RPC.eth_call(addr, "0x18160ddd", block: "finalized")
      refute match?({:error, {:invalid_block, _}}, result)
    end

    test "accepts hex block string (passes input validation)" do
      addr = "0x" <> String.duplicate("aa", 20)
      result = RPC.eth_call(addr, "0x18160ddd", block: "0xe4e1c0")
      refute match?({:error, {:invalid_block, _}}, result)
    end

    test "rejects invalid hex block string" do
      addr = "0x" <> String.duplicate("aa", 20)
      assert {:error, {:invalid_block, "0xZZZZ"}} = RPC.eth_call(addr, "0x18160ddd", block: "0xZZZZ")
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

  describe "get_balance/2 block validation" do
    test "rejects invalid block value" do
      addr = "0x" <> String.duplicate("aa", 20)
      assert {:error, {:invalid_block, "bogus"}} = RPC.get_balance(addr, block: "bogus")
    end

    test "accepts integer block (passes input validation)" do
      addr = "0x" <> String.duplicate("aa", 20)
      result = RPC.get_balance(addr, block: 15_000_000)
      refute match?({:error, {:invalid_block, _}}, result)
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

  describe "eth_get_logs/2 filter validation" do
    test "returns error for invalid from_block value" do
      filter = %{from_block: "bogus"}
      assert {:error, {:invalid_filter, {:fromBlock, "bogus"}}} = RPC.eth_get_logs(filter)
    end

    test "returns error for invalid to_block value" do
      filter = %{from_block: 100, to_block: :not_valid}
      assert {:error, {:invalid_filter, {:toBlock, :not_valid}}} = RPC.eth_get_logs(filter)
    end

    test "returns error for negative block number" do
      filter = %{from_block: -1}
      assert {:error, {:invalid_filter, {:fromBlock, -1}}} = RPC.eth_get_logs(filter)
    end

    test "returns error for invalid hex block string" do
      filter = %{from_block: "0xZZZZ"}
      assert {:error, {:invalid_filter, {:fromBlock, "0xZZZZ"}}} = RPC.eth_get_logs(filter)
    end

    test "accepts valid block tags" do
      # Will fail at RPC level but should pass filter validation
      filter = %{from_block: "latest", to_block: "finalized"}
      result = RPC.eth_get_logs(filter)
      refute match?({:error, {:invalid_filter, _}}, result)
    end

    test "accepts valid integer blocks" do
      filter = %{from_block: 100, to_block: 200}
      result = RPC.eth_get_logs(filter)
      refute match?({:error, {:invalid_filter, _}}, result)
    end

    test "accepts valid hex block strings" do
      filter = %{from_block: "0x64", to_block: "0xc8"}
      result = RPC.eth_get_logs(filter)
      refute match?({:error, {:invalid_filter, _}}, result)
    end
  end

  describe "eth_get_logs/2 filter key validation" do
    test "rejects JSON-RPC-style string keys (Task 56 silent-drop bug)" do
      filter = %{"fromBlock" => 100, "toBlock" => 200}
      assert {:error, {:invalid_filter_key, unknown}} = RPC.eth_get_logs(filter)
      assert unknown in ["fromBlock", "toBlock"]
    end

    test "rejects unsupported atom keys like :blockHash" do
      filter = %{from_block: 100, to_block: 200, blockHash: "0x" <> String.duplicate("ab", 32)}
      assert {:error, {:invalid_filter_key, :blockHash}} = RPC.eth_get_logs(filter)
    end

    test "rejects arbitrary unknown keys" do
      filter = %{from_block: 100, to_block: 200, foo: :bar}
      assert {:error, {:invalid_filter_key, :foo}} = RPC.eth_get_logs(filter)
    end

    test "empty filter still succeeds through key validation" do
      result = RPC.eth_get_logs(%{})
      refute match?({:error, {:invalid_filter_key, _}}, result)
    end

    test "canonical atom keys pass key validation (regression guard)" do
      filter = %{from_block: 100, to_block: 200}
      result = RPC.eth_get_logs(filter)
      refute match?({:error, {:invalid_filter_key, _}}, result)
      refute match?({:error, {:invalid_filter, _}}, result)
    end
  end

  describe "get_transaction_receipt/2 input validation" do
    test "rejects tx_hash without 0x prefix" do
      assert {:error, {:invalid_tx_hash, "abcd1234"}} = RPC.get_transaction_receipt("abcd1234")
    end

    test "rejects tx_hash with invalid hex characters" do
      assert {:error, {:invalid_tx_hash, "0xZZZZ"}} = RPC.get_transaction_receipt("0xZZZZ")
    end

    test "rejects non-binary input" do
      assert {:error, {:invalid_tx_hash, 12_345}} = RPC.get_transaction_receipt(12_345)
    end

    test "rejects too-short hex string" do
      short_hash = "0x1234"
      assert {:error, {:invalid_tx_hash, ^short_hash}} = RPC.get_transaction_receipt(short_hash)
    end

    test "rejects too-long hex string" do
      long_hash = "0x" <> String.duplicate("ab", 33)
      assert {:error, {:invalid_tx_hash, ^long_hash}} = RPC.get_transaction_receipt(long_hash)
    end

    test "accepts valid 32-byte hash (passes input validation)" do
      valid_hash = "0x" <> String.duplicate("ab", 32)
      result = RPC.get_transaction_receipt(valid_hash)
      refute match?({:error, {:invalid_tx_hash, _}}, result)
    end
  end

  describe "get_transaction_receipt!/2" do
    test "raises on invalid input" do
      assert_raise RuntimeError, ~r/get_transaction_receipt failed/, fn ->
        RPC.get_transaction_receipt!("no_prefix")
      end
    end
  end

  describe "get_transaction_count/2 input validation" do
    test "rejects address with wrong byte size" do
      short_addr = "0x" <> String.duplicate("aa", 10)
      assert {:error, {:invalid_address, ^short_addr}} = RPC.get_transaction_count(short_addr)
    end

    test "rejects invalid hex address" do
      bad_addr = "0xnotreallyhex000000000000000000000000000000"
      assert {:error, {:invalid_address, ^bad_addr}} = RPC.get_transaction_count(bad_addr)
    end

    test "rejects non-binary input" do
      assert {:error, {:invalid_address, 12_345}} = RPC.get_transaction_count(12_345)
    end

    test "accepts 20-byte raw binary address (internal callers pass binaries)" do
      addr = <<1::160>>
      result = RPC.get_transaction_count(addr)
      refute match?({:error, {:invalid_address, _}}, result)
    end
  end

  describe "get_transaction_count/2 block validation" do
    test "rejects invalid block value" do
      addr = "0x" <> String.duplicate("aa", 20)
      assert {:error, {:invalid_block, :foo}} = RPC.get_transaction_count(addr, block: :foo)
    end

    test "accepts integer block (passes input validation)" do
      addr = "0x" <> String.duplicate("aa", 20)
      result = RPC.get_transaction_count(addr, block: 15_000_000)
      refute match?({:error, {:invalid_block, _}}, result)
    end

    test "accepts tag block (passes input validation)" do
      addr = "0x" <> String.duplicate("aa", 20)
      result = RPC.get_transaction_count(addr, block: "pending")
      refute match?({:error, {:invalid_block, _}}, result)
    end
  end

  describe "get_transaction_count!/2" do
    test "raises on invalid address" do
      assert_raise RuntimeError, ~r/get_transaction_count failed/, fn ->
        RPC.get_transaction_count!("0xshort")
      end
    end
  end

  # --- eth_get_code ---

  describe "eth_get_code/2 input validation" do
    test "rejects address with wrong byte size" do
      short_addr = "0x" <> String.duplicate("aa", 10)
      assert {:error, {:invalid_address, ^short_addr}} = RPC.eth_get_code(short_addr)
    end

    test "rejects invalid hex address" do
      bad_addr = "0xnotreallyhex000000000000000000000000000000"
      assert {:error, {:invalid_address, ^bad_addr}} = RPC.eth_get_code(bad_addr)
    end

    test "rejects non-binary input" do
      assert {:error, {:invalid_address, 12_345}} = RPC.eth_get_code(12_345)
    end

    test "accepts 20-byte raw binary address (internal callers pass binaries)" do
      addr = <<1::160>>
      result = RPC.eth_get_code(addr)
      refute match?({:error, {:invalid_address, _}}, result)
    end
  end

  describe "eth_get_code/2 block validation" do
    test "rejects invalid block value" do
      addr = "0x" <> String.duplicate("aa", 20)
      assert {:error, {:invalid_block, :foo}} = RPC.eth_get_code(addr, block: :foo)
    end

    test "accepts integer block (passes input validation)" do
      addr = "0x" <> String.duplicate("aa", 20)
      result = RPC.eth_get_code(addr, block: 15_000_000)
      refute match?({:error, {:invalid_block, _}}, result)
    end

    test "accepts tag block (passes input validation)" do
      addr = "0x" <> String.duplicate("aa", 20)
      result = RPC.eth_get_code(addr, block: "finalized")
      refute match?({:error, {:invalid_block, _}}, result)
    end
  end

  describe "eth_get_code!/2" do
    test "raises on invalid address" do
      assert_raise RuntimeError, ~r/eth_get_code failed/, fn ->
        RPC.eth_get_code!("0xshort")
      end
    end
  end

  # --- get_transaction_by_hash ---

  describe "get_transaction_by_hash/2 input validation" do
    test "rejects tx_hash without 0x prefix" do
      assert {:error, {:invalid_tx_hash, "abcd1234"}} = RPC.get_transaction_by_hash("abcd1234")
    end

    test "rejects tx_hash with invalid hex characters" do
      assert {:error, {:invalid_tx_hash, "0xZZZZ"}} = RPC.get_transaction_by_hash("0xZZZZ")
    end

    test "rejects non-binary input" do
      assert {:error, {:invalid_tx_hash, 12_345}} = RPC.get_transaction_by_hash(12_345)
    end

    test "rejects too-short hex string" do
      short_hash = "0x1234"
      assert {:error, {:invalid_tx_hash, ^short_hash}} = RPC.get_transaction_by_hash(short_hash)
    end

    test "rejects too-long hex string" do
      long_hash = "0x" <> String.duplicate("ab", 33)
      assert {:error, {:invalid_tx_hash, ^long_hash}} = RPC.get_transaction_by_hash(long_hash)
    end

    test "accepts valid 32-byte hash (passes input validation)" do
      valid_hash = "0x" <> String.duplicate("ab", 32)
      result = RPC.get_transaction_by_hash(valid_hash)
      refute match?({:error, {:invalid_tx_hash, _}}, result)
    end
  end

  describe "get_transaction_by_hash!/2" do
    test "raises on invalid input" do
      assert_raise RuntimeError, ~r/get_transaction_by_hash failed/, fn ->
        RPC.get_transaction_by_hash!("no_prefix")
      end
    end
  end

  describe "eth_get_logs!/2" do
    test "raises on invalid filter" do
      assert_raise RuntimeError, ~r/eth_get_logs failed/, fn ->
        RPC.eth_get_logs!(%{from_block: "bogus"})
      end
    end
  end

  # --- call (generic JSON-RPC passthrough) ---

  describe "call/3" do
    test "returns wrapped rpc_error tuple when transport fails" do
      assert {:error, {:rpc_error, %{message: _}}} =
               RPC.call("eth_blockNumber", [], rpc_url: "http://localhost:1")
    end

    test "two-arity form (default opts) dispatches identically" do
      # No opts → no :rpc_url override → cartouche falls back to app config which
      # is unconfigured in test env, surfacing as a transport-level rpc_error.
      assert {:error, {:rpc_error, _}} = RPC.call("eth_blockNumber", [])
    end

    test "raises FunctionClauseError when method is not a binary" do
      # apply/3 defeats compile-time type checking so we can exercise the runtime guard
      assert_raise FunctionClauseError, fn ->
        # credo:disable-for-next-line Credo.Check.Refactor.Apply
        apply(RPC, :call, [:eth_blockNumber, [], [rpc_url: "http://localhost:1"]])
      end
    end

    test "raises FunctionClauseError when params is not a list" do
      assert_raise FunctionClauseError, fn ->
        # credo:disable-for-next-line Credo.Check.Refactor.Apply
        apply(RPC, :call, ["eth_blockNumber", nil, [rpc_url: "http://localhost:1"]])
      end

      assert_raise FunctionClauseError, fn ->
        # credo:disable-for-next-line Credo.Check.Refactor.Apply
        apply(RPC, :call, ["eth_blockNumber", %{}, [rpc_url: "http://localhost:1"]])
      end
    end
  end

  describe "call!/3" do
    test "raises with method-prefixed message when RPC unavailable" do
      assert_raise RuntimeError, ~r/RPC eth_blockNumber failed/, fn ->
        RPC.call!("eth_blockNumber", [], rpc_url: "http://localhost:1")
      end
    end

    test "method name is interpolated into the raise message" do
      assert_raise RuntimeError, ~r/RPC debug_traceTransaction failed/, fn ->
        RPC.call!("debug_traceTransaction", ["0x" <> String.duplicate("ab", 32)], rpc_url: "http://localhost:1")
      end
    end
  end
end
