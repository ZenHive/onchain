defmodule Onchain.SubscriptionTest do
  use ExUnit.Case, async: true

  alias Onchain.Subscription

  @fake_client %ZenWebsocket.Client{
    gun_pid: nil,
    stream_ref: nil,
    state: :disconnected,
    url: nil,
    monitor_ref: nil,
    server_pid: nil
  }

  describe "subscribe/3 type validation" do
    test "rejects invalid subscription type" do
      {:ok, agent} = Agent.start_link(fn -> %{} end)
      on_exit(fn -> if Process.alive?(agent), do: Agent.stop(agent) end)

      sub = %Subscription{client: @fake_client, agent: agent, handler: fn _ -> :ok end}

      assert {:error, {:invalid_subscription_type, :invalid}} = Subscription.subscribe(sub, :invalid)
      assert {:error, {:invalid_subscription_type, "newHeads"}} = Subscription.subscribe(sub, "newHeads")
    end
  end

  describe "connect!/2" do
    test "raises on connection failure" do
      assert_raise RuntimeError, ~r/Subscription connect failed/, fn ->
        Subscription.connect!("ws://localhost:1", retry_count: 0, timeout: 100)
      end
    end
  end

  describe "close/1" do
    test "stops the agent and returns :ok" do
      {:ok, agent} = Agent.start_link(fn -> %{} end)

      sub = %Subscription{client: @fake_client, agent: agent, handler: fn _ -> :ok end}

      assert :ok = Subscription.close(sub)
      refute Process.alive?(agent)
    end

    test "handles already-stopped agent gracefully" do
      {:ok, agent} = Agent.start_link(fn -> %{} end)
      Agent.stop(agent)

      sub = %Subscription{client: @fake_client, agent: agent, handler: fn _ -> :ok end}

      assert :ok = Subscription.close(sub)
    end
  end

  # zen_websocket 0.4.x delivers JSON text frames as decoded maps to the handler.
  # These tests pin the dispatch path to the new contract.
  describe "build_internal_handler/2 — zen_websocket 0.4.x contract" do
    setup do
      {:ok, agent} = Agent.start_link(fn -> %{} end)
      on_exit(fn -> if Process.alive?(agent), do: Agent.stop(agent) end)

      caller = self()
      handler = fn event -> send(caller, {:event, event}) end

      internal = Subscription.build_internal_handler(agent, handler)

      {:ok, agent: agent, internal: internal}
    end

    test "dispatches :new_heads notification when message is a decoded map", ctx do
      Agent.update(ctx.agent, &Map.put(&1, "0xsub_heads", :new_heads))

      ctx.internal.(
        {:message,
         %{
           "method" => "eth_subscription",
           "params" => %{
             "subscription" => "0xsub_heads",
             "result" => %{
               "number" => "0x10",
               "hash" => "0xhash",
               "parentHash" => "0xparent",
               "timestamp" => "0x65",
               "miner" => "0x0000000000000000000000000000000000000001",
               "gasLimit" => "0x1c9c380",
               "gasUsed" => "0x5208",
               "baseFeePerGas" => "0x7",
               "logsBloom" => "0x00",
               "transactionsRoot" => "0xtxroot",
               "stateRoot" => "0xstateroot",
               "receiptsRoot" => "0xrcptroot"
             }
           }
         }}
      )

      assert_receive {:event, {:new_heads, "0xsub_heads", head}}, 100
      assert head.number == 16
      assert head.hash == "0xhash"
      assert head.timestamp == 101
    end

    test "dispatches :pending_transactions notification (string hash)", ctx do
      Agent.update(ctx.agent, &Map.put(&1, "0xsub_pending", :pending_transactions))
      hash = "0x" <> String.duplicate("a", 64)

      ctx.internal.(
        {:message,
         %{
           "method" => "eth_subscription",
           "params" => %{"subscription" => "0xsub_pending", "result" => hash}
         }}
      )

      assert_receive {:event, {:pending_transactions, "0xsub_pending", ^hash}}, 100
    end

    test "dispatches :logs notification", ctx do
      Agent.update(ctx.agent, &Map.put(&1, "0xsub_logs", {:logs, %{}}))

      ctx.internal.(
        {:message,
         %{
           "method" => "eth_subscription",
           "params" => %{
             "subscription" => "0xsub_logs",
             "result" => %{
               "address" => "0x0000000000000000000000000000000000000002",
               "topics" => ["0xtopic1"],
               "data" => "0xdeadbeef",
               "blockNumber" => "0x10",
               "transactionHash" => "0xtxhash",
               "logIndex" => "0x0",
               "transactionIndex" => "0x0",
               "removed" => false
             }
           }
         }}
      )

      assert_receive {:event, {:logs, "0xsub_logs", log}}, 100
      assert log.block_number == 16
      assert log.topics == ["0xtopic1"]
      refute log.removed
    end

    test "dispatches {:parse_error, sub_id, {:invalid_head, _}} on malformed :new_heads result", ctx do
      Agent.update(ctx.agent, &Map.put(&1, "0xsub_heads", :new_heads))

      ctx.internal.(
        {:message,
         %{
           "method" => "eth_subscription",
           "params" => %{"subscription" => "0xsub_heads", "result" => "not a map"}
         }}
      )

      assert_receive {:event, {:parse_error, "0xsub_heads", {:invalid_head, "not a map"}}}, 100
    end

    test "dispatches {:parse_error, sub_id, {:invalid_log, _}} on malformed :logs result", ctx do
      Agent.update(ctx.agent, &Map.put(&1, "0xsub_logs", {:logs, %{}}))

      ctx.internal.(
        {:message,
         %{
           "method" => "eth_subscription",
           "params" => %{"subscription" => "0xsub_logs", "result" => "not a map"}
         }}
      )

      assert_receive {:event, {:parse_error, "0xsub_logs", {:invalid_log, "not a map"}}}, 100
    end

    test "silently drops notification for unknown subscription_id", ctx do
      ctx.internal.(
        {:message,
         %{
           "method" => "eth_subscription",
           "params" => %{"subscription" => "0xunknown", "result" => %{}}
         }}
      )

      refute_receive {:event, _}, 50
    end

    test "ignores non-JSON text frames", ctx do
      ctx.internal.({:message, "not json"})
      refute_receive {:event, _}, 50
    end

    test "ignores binary frames", ctx do
      ctx.internal.({:binary, <<1, 2, 3>>})
      refute_receive {:event, _}, 50
    end

    test "ignores unmatched_response", ctx do
      ctx.internal.({:unmatched_response, %{"id" => 99, "result" => "late"}})
      refute_receive {:event, _}, 50
    end

    test "does not crash on protocol_error", ctx do
      assert :ok = ctx.internal.({:protocol_error, :badframe})
      refute_receive {:event, _}, 50
    end

    test "ignores unknown handler tuples", ctx do
      assert :ok = ctx.internal.({:wat, :unexpected})
      refute_receive {:event, _}, 50
    end
  end
end
