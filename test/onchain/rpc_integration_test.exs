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

  # --- Bang variant integration tests ---

  describe "block_number!/1" do
    test "returns block number directly" do
      block = RPC.block_number!(rpc_opts())
      assert is_integer(block)
      assert block > 0
    end
  end

  describe "chain_id!/1" do
    test "returns chain ID directly" do
      assert 1 == RPC.chain_id!(rpc_opts())
    end
  end

  describe "get_balance!/2" do
    test "returns balance directly" do
      balance = RPC.get_balance!(@zero_address, rpc_opts())
      assert is_integer(balance)
      assert balance >= 0
    end
  end

  describe "eth_call!/3" do
    test "returns hex result directly" do
      {:ok, calldata} = ABI.encode_call("totalSupply()", [])
      hex = RPC.eth_call!(@weth_address, calldata, rpc_opts())
      assert is_binary(hex)
      assert String.starts_with?(hex, "0x")
    end
  end

  describe "get_block_by_number!/2" do
    test "returns block map directly" do
      block = RPC.get_block_by_number!(20_000_000, rpc_opts())
      assert is_map(block)
      assert block["number"] == "0x1312d00"
    end
  end

  describe "get_transaction_count!/2" do
    test "returns nonce directly" do
      nonce = RPC.get_transaction_count!(@eoa_address, rpc_opts())
      assert is_integer(nonce)
      assert nonce > 0
    end
  end

  describe "eth_get_code!/2" do
    test "returns code directly for contract" do
      code = RPC.eth_get_code!(@weth_address, rpc_opts())
      assert is_binary(code)
      assert String.starts_with?(code, "0x")
      assert byte_size(code) > 2
    end
  end

  describe "eth_get_logs!/2" do
    test "returns logs directly for valid filter" do
      logs = RPC.eth_get_logs!(%{from_block: 20_000_000, to_block: 20_000_000}, rpc_opts())
      assert is_list(logs)
    end
  end

  # --- call (generic JSON-RPC passthrough) ---

  # Aave V3 Pool on mainnet — OpenZeppelin TransparentUpgradeableProxy (EIP-1967).
  # USDC's FiatTokenProxy uses the older zeppelinos slot, NOT EIP-1967, so the
  # EIP-1967 implementation slot legitimately reads zero on it.
  @aave_v3_pool_proxy "0x87870bca3f3fd6335c3f4ce8392d69350b4fa4e2"
  # EIP-1967 implementation slot: keccak256("eip1967.proxy.implementation") - 1
  @eip1967_impl_slot "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"

  describe "call/3" do
    test "eth_getStorageAt returns the EIP-1967 implementation slot for a known proxy" do
      assert {:ok, slot_value} =
               RPC.call(
                 "eth_getStorageAt",
                 [@aave_v3_pool_proxy, @eip1967_impl_slot, "latest"],
                 rpc_opts()
               )

      # Storage slots are 32 bytes → 0x + 64 hex chars.
      assert is_binary(slot_value)
      assert String.starts_with?(slot_value, "0x")
      assert byte_size(slot_value) == 66

      # Lower 20 bytes = implementation address; should be non-zero for a live proxy.
      <<"0x", _padding::binary-size(24), addr_hex::binary-size(40)>> = slot_value
      refute addr_hex == String.duplicate("0", 40)
    end

    test "eth_chainId returns raw 0x-hex string (no decoding applied)" do
      # call/3 deliberately does NOT decode — proves the no-decode semantics by
      # comparing against the typed wrapper which DOES decode to integer.
      assert {:ok, "0x1"} = RPC.call("eth_chainId", [], rpc_opts())
      assert {:ok, 1} = RPC.chain_id(rpc_opts())
    end
  end

  describe "call!/3" do
    test "returns raw result directly" do
      assert "0x1" == RPC.call!("eth_chainId", [], rpc_opts())
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
