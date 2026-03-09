defmodule Onchain.SignerIntegrationTest do
  use ExUnit.Case, async: false

  alias Onchain.RPC
  alias Onchain.Signer

  @moduletag :integration

  @sepolia_chain_id 11_155_111

  describe "address_from_key/1 with real Sepolia key" do
    test "derives a valid checksummed address" do
      key = Onchain.SignerCase.signer_key!()
      assert {:ok, address} = Signer.address_from_key(key)
      assert String.starts_with?(address, "0x")
      assert String.length(address) == 42
      # Verify mixed case (checksummed)
      refute address == String.downcase(address)
    end
  end

  describe "nonce fetch for derived address" do
    test "gets transaction count from Sepolia RPC" do
      rpc_url = Onchain.SignerCase.sepolia_rpc_url!()
      address = Onchain.SignerCase.signer_address!()

      assert {:ok, nonce} = RPC.get_transaction_count(address, rpc_url: rpc_url)
      assert is_integer(nonce) and nonce >= 0
    end
  end

  describe "self-transfer on Sepolia" do
    @tag :sepolia_send
    test "sends 0 ETH to self and gets receipt with status 1" do
      key = Onchain.SignerCase.signer_key!()
      rpc_url = Onchain.SignerCase.sepolia_rpc_url!()
      address = Onchain.SignerCase.signer_address!()

      # Fetch current nonce
      {:ok, nonce} = RPC.get_transaction_count(address, rpc_url: rpc_url, block: "pending")

      # Send 0 ETH to self
      assert {:ok, tx_hash} =
               Signer.send_transaction(address, <<>>,
                 private_key: key,
                 nonce: nonce,
                 chain_id: @sepolia_chain_id,
                 rpc_url: rpc_url,
                 gas_limit: 21_000,
                 max_fee_per_gas: {10, :gwei},
                 max_priority_fee_per_gas: {1, :gwei},
                 value: 0
               )

      assert String.starts_with?(tx_hash, "0x")

      # Wait for receipt
      assert {:ok, receipt} =
               Onchain.SignerCase.wait_for_receipt(tx_hash, rpc_url: rpc_url)

      assert receipt.status == 1
      assert receipt.from == address
    end
  end
end
