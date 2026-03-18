defmodule Onchain.RPC.HelpersTest do
  use ExUnit.Case, async: true

  alias Onchain.RPC.Helpers

  # --- ensure_hex_address/1 ---

  describe "ensure_hex_address/1" do
    test "accepts valid 0x-prefixed hex address" do
      addr = "0x" <> String.duplicate("aa", 20)
      assert {:ok, "0x" <> _} = Helpers.ensure_hex_address(addr)
    end

    test "accepts 20-byte binary address" do
      assert {:ok, "0x" <> _} = Helpers.ensure_hex_address(<<1::160>>)
    end

    test "accepts bare hex address without 0x prefix" do
      bare_addr = String.duplicate("aa", 20)
      assert {:ok, "0x" <> _} = Helpers.ensure_hex_address(bare_addr)
    end

    test "rejects address with wrong byte size" do
      short = "0x" <> String.duplicate("aa", 10)
      assert {:error, {:invalid_address, ^short}} = Helpers.ensure_hex_address(short)
    end

    test "rejects invalid hex characters" do
      bad = "0xZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
      assert {:error, {:invalid_address, ^bad}} = Helpers.ensure_hex_address(bad)
    end

    test "rejects non-binary input" do
      assert {:error, {:invalid_address, 12_345}} = Helpers.ensure_hex_address(12_345)
    end
  end

  # --- ensure_hex_data/1 ---

  describe "ensure_hex_data/1" do
    test "accepts valid 0x-prefixed hex data" do
      assert {:ok, "0x18160ddd"} = Helpers.ensure_hex_data("0x18160ddd")
    end

    test "accepts 0x alone (empty calldata)" do
      assert {:ok, "0x"} = Helpers.ensure_hex_data("0x")
    end

    test "rejects data without 0x prefix" do
      assert {:error, {:invalid_data, "18160ddd"}} = Helpers.ensure_hex_data("18160ddd")
    end

    test "rejects data with invalid hex characters" do
      assert {:error, {:invalid_data, "0xZZZZ"}} = Helpers.ensure_hex_data("0xZZZZ")
    end

    test "rejects non-binary input" do
      assert {:error, {:invalid_data, 42}} = Helpers.ensure_hex_data(42)
    end
  end

  # --- normalize_block/1 ---

  describe "normalize_block/1" do
    test "accepts all block tags" do
      for tag <- ~w(latest finalized pending earliest safe) do
        assert {:ok, ^tag} = Helpers.normalize_block(tag)
      end
    end

    test "converts non-negative integer to hex" do
      assert {:ok, "0x" <> _} = Helpers.normalize_block(15_000_000)
    end

    test "accepts zero" do
      assert {:ok, "0x0"} = Helpers.normalize_block(0)
    end

    test "accepts valid hex string" do
      assert {:ok, "0xe4e1c0"} = Helpers.normalize_block("0xe4e1c0")
    end

    test "rejects negative integer" do
      assert {:error, {:invalid_block, -1}} = Helpers.normalize_block(-1)
    end

    test "rejects invalid hex string" do
      assert {:error, {:invalid_block, "0xZZZZ"}} = Helpers.normalize_block("0xZZZZ")
    end

    test "rejects unknown string" do
      assert {:error, {:invalid_block, "bogus"}} = Helpers.normalize_block("bogus")
    end

    test "rejects atom" do
      assert {:error, {:invalid_block, :foo}} = Helpers.normalize_block(:foo)
    end
  end

  # --- ensure_tx_hash/1 ---

  describe "ensure_tx_hash/1" do
    test "accepts valid 32-byte hash" do
      hash = "0x" <> String.duplicate("ab", 32)
      assert {:ok, ^hash} = Helpers.ensure_tx_hash(hash)
    end

    test "rejects too-short hash" do
      short = "0x1234"
      assert {:error, {:invalid_tx_hash, ^short}} = Helpers.ensure_tx_hash(short)
    end

    test "rejects too-long hash" do
      long = "0x" <> String.duplicate("ab", 33)
      assert {:error, {:invalid_tx_hash, ^long}} = Helpers.ensure_tx_hash(long)
    end

    test "rejects invalid hex characters" do
      assert {:error, {:invalid_tx_hash, "0xZZZZ"}} = Helpers.ensure_tx_hash("0xZZZZ")
    end

    test "rejects without 0x prefix" do
      bare = String.duplicate("ab", 32)
      assert {:error, {:invalid_tx_hash, ^bare}} = Helpers.ensure_tx_hash(bare)
    end

    test "rejects non-binary input" do
      assert {:error, {:invalid_tx_hash, 12_345}} = Helpers.ensure_tx_hash(12_345)
    end
  end

  # --- to_signet_opts/1 ---

  describe "to_signet_opts/1" do
    test "renames :rpc_url to :ethereum_node" do
      opts = Helpers.to_signet_opts(rpc_url: "http://localhost:8545")
      assert Keyword.get(opts, :ethereum_node) == "http://localhost:8545"
      refute Keyword.has_key?(opts, :rpc_url)
    end

    test "applies default timeout when not specified" do
      opts = Helpers.to_signet_opts([])
      assert Keyword.get(opts, :timeout) == 30_000
    end

    test "preserves explicit timeout" do
      opts = Helpers.to_signet_opts(timeout: 5_000)
      assert Keyword.get(opts, :timeout) == 5_000
    end

    test "strips unknown options" do
      opts = Helpers.to_signet_opts(rpc_url: "http://x", block: "latest", foo: :bar)
      refute Keyword.has_key?(opts, :block)
      refute Keyword.has_key?(opts, :foo)
    end
  end

  # --- rename_key/3 ---

  describe "rename_key/3" do
    test "renames key when present" do
      assert [new: "value"] = Helpers.rename_key([old: "value"], :old, :new)
    end

    test "returns opts unchanged when key absent" do
      opts = [other: "value"]
      assert ^opts = Helpers.rename_key(opts, :missing, :new)
    end
  end
end
