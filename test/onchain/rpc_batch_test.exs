defmodule Onchain.RPC.BatchTest do
  use ExUnit.Case, async: false

  alias Onchain.RPC

  defmodule StubClient do
    @moduledoc false

    @stub_key :onchain_rpc_batch_stub_response

    @spec request(Finch.Request.t(), atom(), keyword()) ::
            {:ok, Finch.Response.t()} | {:error, term()}
    def request(%Finch.Request{body: encoded_body}, _name, _opts) do
      case Process.get(@stub_key) do
        nil ->
          {:error, :stub_not_configured}

        response_fun when is_function(response_fun, 1) ->
          body = encoded_body |> IO.iodata_to_binary() |> Jason.decode!()

          {:ok,
           %Finch.Response{status: 200, body: Jason.encode!(response_fun.(body)), headers: []}}
      end
    end

    @spec queue_response((term() -> term())) :: :ok
    def queue_response(response_fun) when is_function(response_fun, 1) do
      Process.put(@stub_key, response_fun)
      :ok
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

  describe "batch/2" do
    test "sends one JSON-RPC array request and returns results in request order" do
      StubClient.queue_response(fn body ->
        assert [
                 %{"id" => 1, "jsonrpc" => "2.0", "method" => "eth_blockNumber", "params" => []},
                 %{"id" => 2, "jsonrpc" => "2.0", "method" => "eth_chainId", "params" => []}
               ] = body

        [
          %{"id" => 2, "jsonrpc" => "2.0", "result" => "0x1"},
          %{"id" => 1, "jsonrpc" => "2.0", "result" => "0x2a"}
        ]
      end)

      assert {:ok, ["0x2a", "0x1"]} =
               RPC.batch(
                 [
                   {"eth_blockNumber", []},
                   {"eth_chainId", []}
                 ],
                 rpc_url: "http://stub.invalid"
               )
    end

    test "normalizes JSON-RPC error responses" do
      StubClient.queue_response(fn _body ->
        [
          %{
            "id" => 1,
            "jsonrpc" => "2.0",
            "error" => %{"code" => -32_000, "message" => "execution reverted"}
          }
        ]
      end)

      assert {:error, {:rpc_error, %{code: -32_000, message: "execution reverted"}}} =
               RPC.batch(
                 [{"eth_call", [%{"to" => "0x" <> String.duplicate("ab", 20)}, "latest"]}],
                 rpc_url: "http://stub.invalid"
               )
    end
  end
end
