defmodule Onchain.RPC.RevertTest do
  # Mutates global cartouche client config; cannot run async with other RPC tests.
  use ExUnit.Case, async: false

  alias Onchain.RPC

  # The stub HTTP client below returns canned Finch responses based on a
  # response queued in the calling test's process dictionary. When no response
  # is queued it returns a benign error so any other code paths that happen to
  # hit it during the brief env-mutation window still receive a recognisable
  # `{:error, _}` from cartouche.
  defmodule StubClient do
    @moduledoc false

    @stub_key :onchain_rpc_revert_stub_response

    @spec request(Finch.Request.t(), atom(), keyword()) ::
            {:ok, Finch.Response.t()} | {:error, term()}
    def request(%Finch.Request{body: encoded_body}, _name, _opts) do
      case Process.get(@stub_key) do
        nil ->
          {:error, :stub_not_configured}

        {:revert, %{} = error_payload} ->
          json_response(encoded_body, %{"error" => Map.put_new(error_payload, "message", "execution reverted")})

        {:result, result} ->
          json_response(encoded_body, %{"result" => result})
      end
    end

    @spec queue_revert(map()) :: :ok
    def queue_revert(error_payload) when is_map(error_payload) do
      Process.put(@stub_key, {:revert, error_payload})
      :ok
    end

    @spec queue_result(term()) :: :ok
    def queue_result(result) do
      Process.put(@stub_key, {:result, result})
      :ok
    end

    defp json_response(encoded_body, extra) do
      %{"id" => id} = Jason.decode!(IO.iodata_to_binary(encoded_body))
      response = Map.merge(%{"jsonrpc" => "2.0", "id" => id}, extra)
      {:ok, %Finch.Response{status: 200, body: Jason.encode!(response), headers: []}}
    end
  end

  setup_all do
    previous_client = Application.get_env(:cartouche, :client)
    Application.put_env(:cartouche, :client, StubClient)

    on_exit(fn ->
      case previous_client do
        nil -> Application.delete_env(:cartouche, :client)
        client -> Application.put_env(:cartouche, :client, client)
      end
    end)

    :ok
  end

  @addr "0x" <> String.duplicate("ab", 20)
  @data "0x18160ddd"

  describe "eth_call/3 revert handling" do
    test "without :errors opt — error map carries raw :revert binary, hex :data mirror, no :error_abi" do
      revert_bytes = ABI.encode("InsufficientBalance(uint256,uint256)", [1_000, 500])
      hex_payload = "0x" <> Base.encode16(revert_bytes, case: :lower)

      StubClient.queue_revert(%{
        "code" => 3,
        "message" => "execution reverted",
        "data" => hex_payload
      })

      assert {:error, {:rpc_error, error_map}} =
               RPC.eth_call(@addr, @data, rpc_url: "http://stub.invalid")

      assert error_map.code == 3
      assert error_map.message == "execution reverted"
      assert error_map.revert == revert_bytes
      assert error_map.data == hex_payload
      refute Map.has_key?(error_map, :error_abi)
      refute Map.has_key?(error_map, :error_params)
    end

    test "with matching :errors opt — error map carries :error_abi + :error_params" do
      signature = "InsufficientBalance(uint256,uint256)"
      revert_bytes = ABI.encode(signature, [1_000, 500])

      StubClient.queue_revert(%{
        "code" => 3,
        "message" => "execution reverted",
        "data" => "0x" <> Base.encode16(revert_bytes, case: :lower)
      })

      assert {:error, {:rpc_error, error_map}} =
               RPC.eth_call(@addr, @data,
                 rpc_url: "http://stub.invalid",
                 errors: [signature]
               )

      assert error_map.code == 3
      assert error_map.revert == revert_bytes
      assert error_map.error_abi == signature
      assert error_map.error_params == [1_000, 500]
    end

    test "with code: 3 but no :data field from node — error map omits :revert and :data" do
      # Some nodes return `code: 3` without the `data` payload. Cartouche then
      # leaves `:revert` off the map; Onchain's `:data` mirror only fires when
      # `:revert` is set, so it stays off too. Documented in the moduledoc.
      StubClient.queue_revert(%{"code" => 3, "message" => "execution reverted"})

      assert {:error, {:rpc_error, error_map}} =
               RPC.eth_call(@addr, @data, rpc_url: "http://stub.invalid")

      assert error_map.code == 3
      assert error_map.message == "execution reverted"
      refute Map.has_key?(error_map, :revert)
      refute Map.has_key?(error_map, :data)
      refute Map.has_key?(error_map, :error_abi)
      refute Map.has_key?(error_map, :error_params)
    end

    test "successful eth_call returns the raw hex result" do
      hex_result = "0x" <> String.duplicate("00", 31) <> "2a"
      StubClient.queue_result(hex_result)

      assert {:ok, ^hex_result} = RPC.eth_call(@addr, @data, rpc_url: "http://stub.invalid")
    end

    test "eth_call!/3 returns the unwrapped hex result on success" do
      hex_result = "0x" <> String.duplicate("00", 32)
      StubClient.queue_result(hex_result)

      assert ^hex_result = RPC.eth_call!(@addr, @data, rpc_url: "http://stub.invalid")
    end

    test "with non-matching :errors opt — error map carries :revert + :data only, no decoded fields" do
      # Revert payload is for InsufficientBalance, but caller declares a
      # different custom error. cartouche fails to decode → only :revert (and
      # the Onchain-mirrored :data) is set; :error_abi / :error_params absent.
      revert_bytes = ABI.encode("InsufficientBalance(uint256,uint256)", [1_000, 500])
      hex_payload = "0x" <> Base.encode16(revert_bytes, case: :lower)

      StubClient.queue_revert(%{
        "code" => 3,
        "message" => "execution reverted",
        "data" => hex_payload
      })

      assert {:error, {:rpc_error, error_map}} =
               RPC.eth_call(@addr, @data,
                 rpc_url: "http://stub.invalid",
                 errors: ["Unauthorized()"]
               )

      assert error_map.code == 3
      assert error_map.revert == revert_bytes
      assert error_map.data == hex_payload
      refute Map.has_key?(error_map, :error_abi)
      refute Map.has_key?(error_map, :error_params)
    end
  end
end
