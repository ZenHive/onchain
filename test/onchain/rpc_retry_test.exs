defmodule Onchain.RPC.RetryTest do
  use ExUnit.Case, async: false

  alias Onchain.RPC

  @stub_rpc_url "http://stub.invalid"
  @no_backoff_ms 0

  defmodule StubClient do
    @moduledoc false

    @stub_key :onchain_rpc_retry_stub_responses

    @type stub_response :: {:ok, Finch.Response.t()} | {:error, term()} | (map() -> {:ok, Finch.Response.t()})

    @spec request(Finch.Request.t(), atom(), keyword()) ::
            {:ok, Finch.Response.t()} | {:error, term()}
    def request(%Finch.Request{body: encoded_body}, _name, _opts) do
      case Process.get(@stub_key) do
        nil ->
          {:error, :stub_not_configured}

        [] ->
          {:error, :stub_exhausted}

        [response | remaining] ->
          Process.put(@stub_key, remaining)
          body = encoded_body |> IO.iodata_to_binary() |> Jason.decode!()
          evaluate_response(response, body)
      end
    end

    @spec queue_responses([stub_response()]) :: :ok
    def queue_responses(responses) when is_list(responses) do
      Process.put(@stub_key, responses)
      :ok
    end

    @spec evaluate_response(stub_response(), map()) :: {:ok, Finch.Response.t()} | {:error, term()}
    defp evaluate_response(response_fun, body) when is_function(response_fun, 1), do: response_fun.(body)
    defp evaluate_response(response, _body), do: response
  end

  setup do
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

  describe "retry policy" do
    test "does not retry by default" do
      StubClient.queue_responses([{:error, :closed}, rpc_success("0x1")])

      assert_rpc_error_message(
        RPC.call("eth_blockNumber", [], rpc_url: @stub_rpc_url),
        "closed"
      )
    end

    test "retries opted-in RPC errors and returns a later success" do
      StubClient.queue_responses([{:error, :closed}, rpc_success("0x2a")])

      assert {:ok, "0x2a"} =
               RPC.call("eth_blockNumber", [],
                 rpc_url: @stub_rpc_url,
                 retry: [max_retries: 1, backoff_ms: @no_backoff_ms]
               )
    end

    test "returns the final RPC error after retries are exhausted" do
      StubClient.queue_responses([{:error, :closed}, {:error, :timeout}])

      "eth_blockNumber"
      |> RPC.call([],
        rpc_url: @stub_rpc_url,
        retry: [max_retries: 1, backoff_ms: @no_backoff_ms]
      )
      |> assert_rpc_error_message("timeout")
    end

    test "does not retry JSON-RPC application errors" do
      StubClient.queue_responses([rpc_error_response(-32_000, "execution reverted"), rpc_success("0x1")])

      assert {:error, {:rpc_error, %{code: -32_000, message: "execution reverted"}}} =
               RPC.call("eth_blockNumber", [],
                 rpc_url: @stub_rpc_url,
                 retry: [max_retries: 1, backoff_ms: @no_backoff_ms]
               )
    end
  end

  defp assert_rpc_error_message(result, expected_message) do
    assert {:error, {:rpc_error, %{message: message}}} = result
    assert message =~ expected_message
  end

  defp rpc_success(result) do
    fn body ->
      {:ok,
       %Finch.Response{
         status: 200,
         headers: [],
         body: Jason.encode!(%{"id" => body["id"], "jsonrpc" => "2.0", "result" => result})
       }}
    end
  end

  defp rpc_error_response(code, message) do
    fn body ->
      {:ok,
       %Finch.Response{
         status: 200,
         headers: [],
         body:
           Jason.encode!(%{
             "id" => body["id"],
             "jsonrpc" => "2.0",
             "error" => %{"code" => code, "message" => message}
           })
       }}
    end
  end
end
