defmodule Onchain.ERC20Test do
  use ExUnit.Case, async: false

  alias Onchain.ERC20

  # Valid address for param validation tests (doesn't need to be a real token)
  @valid_address "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
  @approve_selector <<0x09, 0x5E, 0xA7, 0xB3>>
  @transfer_selector <<0xA9, 0x05, 0x9C, 0xBB>>
  @trace_timeout_ms 1_000

  describe "balance_of/3" do
    test "returns error for invalid holder address" do
      assert {:error, {:invalid_address, "not_an_address"}} =
               ERC20.balance_of(@valid_address, "not_an_address")
    end

    test "returns error for invalid token address" do
      {:ok, holder_bin} = Onchain.Address.validate(@valid_address)

      assert {:error, {:invalid_address, "bad_token"}} =
               ERC20.balance_of("bad_token", holder_bin)
    end
  end

  describe "balance_of!/3" do
    test "raises on invalid holder address" do
      assert_raise RuntimeError, ~r/balance_of failed/, fn ->
        ERC20.balance_of!(@valid_address, "not_an_address")
      end
    end
  end

  describe "allowance/4" do
    test "returns error for invalid owner address" do
      assert {:error, {:invalid_address, "bad_owner"}} =
               ERC20.allowance(@valid_address, "bad_owner", @valid_address)
    end

    test "returns error for invalid spender address" do
      assert {:error, {:invalid_address, "bad_spender"}} =
               ERC20.allowance(@valid_address, @valid_address, "bad_spender")
    end

    test "returns error for invalid token address" do
      {:ok, addr_bin} = Onchain.Address.validate(@valid_address)

      assert {:error, {:invalid_address, "bad_token"}} =
               ERC20.allowance("bad_token", addr_bin, addr_bin)
    end
  end

  describe "allowance!/4" do
    test "raises on invalid owner address" do
      assert_raise RuntimeError, ~r/allowance failed/, fn ->
        ERC20.allowance!(@valid_address, "bad_owner", @valid_address)
      end
    end
  end

  describe "decimals/2" do
    test "returns error for invalid token address" do
      assert {:error, {:invalid_address, "not_a_token"}} =
               ERC20.decimals("not_a_token")
    end
  end

  describe "decimals!/2" do
    test "raises on invalid token address" do
      assert_raise RuntimeError, ~r/decimals failed/, fn ->
        ERC20.decimals!("not_a_token")
      end
    end
  end

  describe "symbol/2" do
    test "returns error for invalid token address" do
      assert {:error, {:invalid_address, "not_a_token"}} =
               ERC20.symbol("not_a_token")
    end
  end

  describe "symbol!/2" do
    test "raises on invalid token address" do
      assert_raise RuntimeError, ~r/symbol failed/, fn ->
        ERC20.symbol!("not_a_token")
      end
    end
  end

  describe "approve/4" do
    test "returns error for invalid spender address" do
      assert {:error, {:invalid_address, "bad_spender"}} =
               ERC20.approve(@valid_address, "bad_spender", 1_000_000, [])
    end

    test "returns error for invalid token address (missing opts hits first)" do
      {:ok, addr_bin} = Onchain.Address.validate(@valid_address)

      # Token address validation happens inside Signer.send_transaction (after :private_key check),
      # so with empty opts, :missing_option fires first
      assert {:error, {:missing_option, :private_key}} =
               ERC20.approve("bad_token", addr_bin, 1_000_000, [])
    end
  end

  describe "approve!/4" do
    test "raises on invalid spender address" do
      assert_raise RuntimeError, ~r/approve failed/, fn ->
        ERC20.approve!(@valid_address, "bad_spender", 1_000_000, [])
      end
    end
  end

  describe "transfer/4" do
    test "returns error for invalid recipient address" do
      assert {:error, {:invalid_address, "bad_to"}} =
               ERC20.transfer(@valid_address, "bad_to", 1_000_000, [])
    end

    test "returns error for invalid token address (missing opts hits first)" do
      {:ok, addr_bin} = Onchain.Address.validate(@valid_address)

      # Token address validation happens inside Signer.send_transaction (after :private_key check),
      # so with empty opts, :missing_option fires first
      assert {:error, {:missing_option, :private_key}} =
               ERC20.transfer("bad_token", addr_bin, 1_000_000, [])
    end
  end

  describe "transfer!/4" do
    test "raises on invalid recipient address" do
      assert_raise RuntimeError, ~r/transfer failed/, fn ->
        ERC20.transfer!(@valid_address, "bad_to", 1_000_000, [])
      end
    end
  end

  describe "approve/transfer ABI selector verification" do
    test "wrappers pass distinct ERC-20 selectors to Signer.send_transaction/3" do
      approve_calldata =
        capture_signer_calldata(fn ->
          assert {:error, {:missing_option, :private_key}} =
                   ERC20.approve(@valid_address, @valid_address, 100, [])
        end)

      transfer_calldata =
        capture_signer_calldata(fn ->
          assert {:error, {:missing_option, :private_key}} =
                   ERC20.transfer(@valid_address, @valid_address, 100, [])
        end)

      <<approve_selector::binary-size(4), approve_args::binary>> = approve_calldata
      <<transfer_selector::binary-size(4), transfer_args::binary>> = transfer_calldata

      assert approve_selector == @approve_selector
      assert transfer_selector == @transfer_selector
      refute approve_selector == transfer_selector
      assert approve_args == transfer_args
    end
  end

  @doc false
  # Traces the wrapper's downstream Signer call so tests can assert on the
  # actual calldata argument passed to send_transaction/3.
  defp capture_signer_calldata(fun) do
    parent = self()

    handler = fn msg, state ->
      send(parent, {:dbg_trace, msg})
      state
    end

    Code.prepend_path(runtime_tools_ebin!())
    # credo:disable-for-next-line Credo.Check.Refactor.Apply
    apply(:dbg, :tracer, [:process, {handler, nil}])
    # credo:disable-for-next-line Credo.Check.Refactor.Apply
    apply(:dbg, :p, [self(), [:call]])
    # credo:disable-for-next-line Credo.Check.Refactor.Apply
    apply(:dbg, :tpl, [Onchain.Signer, :send_transaction, :x])

    try do
      fun.()
      receive_signer_calldata()
    after
      # credo:disable-for-next-line Credo.Check.Refactor.Apply
      apply(:dbg, :stop_clear, [])
      drain_dbg_messages()
    end
  end

  @doc false
  # Waits for the traced Signer.send_transaction/3 call and returns its calldata arg.
  defp receive_signer_calldata do
    receive do
      {:dbg_trace, {:trace, _pid, :call, {Onchain.Signer, :send_transaction, [_token, calldata, _opts]}}} ->
        calldata

      {:dbg_trace, _other} ->
        receive_signer_calldata()
    after
      @trace_timeout_ms ->
        flunk("Expected traced call to Onchain.Signer.send_transaction/3")
    end
  end

  @doc false
  # Clears any buffered dbg trace messages so later tests start cleanly.
  defp drain_dbg_messages do
    receive do
      {:dbg_trace, _message} -> drain_dbg_messages()
    after
      0 -> :ok
    end
  end

  @doc false
  # Finds the OTP runtime_tools ebin path so mix test can load :dbg on demand.
  defp runtime_tools_ebin! do
    root_dir = List.to_string(:code.root_dir())

    case Path.wildcard(Path.join([root_dir, "lib", "runtime_tools-*", "ebin"])) do
      [ebin | _rest] ->
        ebin

      [] ->
        flunk("Could not locate OTP runtime_tools ebin path for :dbg tracing")
    end
  end
end
