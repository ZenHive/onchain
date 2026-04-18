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
end
