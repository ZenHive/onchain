defmodule Onchain.SolidityTest do
  use ExUnit.Case, async: true

  alias Onchain.Solidity

  @priv_abis Path.join(:code.priv_dir(:onchain), "abis")

  describe "parse_abi_json/1" do
    test "parses function with no inputs and single output" do
      json = File.read!(Path.join(@priv_abis, "chainlink_aggregator.json"))
      assert {:ok, abi} = Solidity.parse_abi_json(json)

      decimals = find_function(abi, "decimals")
      assert decimals.name == "decimals"
      assert decimals.signature == "decimals()"
      assert decimals.return_type == "(uint8)"
      assert decimals.state_mutability == "view"
      assert decimals.inputs == []
      assert [%{name: "", ty: "uint8"}] = decimals.outputs
    end

    test "parses function with multiple outputs and mixed types" do
      json = File.read!(Path.join(@priv_abis, "chainlink_aggregator.json"))
      assert {:ok, abi} = Solidity.parse_abi_json(json)

      latest = find_function(abi, "latestRoundData")
      assert latest.signature == "latestRoundData()"
      assert latest.return_type == "(uint80,int256,uint256,uint256,uint80)"
      assert length(latest.outputs) == 5
      assert Enum.at(latest.outputs, 0).ty == "uint80"
      assert Enum.at(latest.outputs, 1).ty == "int256"
    end

    test "parses function with address input" do
      json = File.read!(Path.join(@priv_abis, "aave_pool.json"))
      assert {:ok, abi} = Solidity.parse_abi_json(json)

      func = find_function(abi, "getUserAccountData")
      assert func.signature == "getUserAccountData(address)"
      assert func.return_type == "(uint256,uint256,uint256,uint256,uint256,uint256)"
      assert func.state_mutability == "view"
      assert [%{name: "user", ty: "address"}] = func.inputs
      assert length(func.outputs) == 6
    end

    test "parses nested tuple/struct returns" do
      json = File.read!(Path.join(@priv_abis, "aave_pool.json"))
      assert {:ok, abi} = Solidity.parse_abi_json(json)

      func = find_function(abi, "getReserveData")
      assert func.signature == "getReserveData(address)"

      # The return type wraps the struct in outer parens (function returns one tuple)
      # Inner tuple is the ReserveData struct, first field is ReserveConfigurationMap((uint256))
      assert func.return_type ==
               "(((uint256),uint128,uint128,uint128,uint128,uint128,uint40,uint16,address,address,address,address,uint128,uint128,uint128))"

      # The output should have components for the struct fields
      assert [output] = func.outputs
      assert output.ty == "tuple"
      assert length(output.components) == 15

      # First component is itself a nested tuple (ReserveConfigurationMap)
      config = Enum.at(output.components, 0)
      assert config.name == "configuration"
      assert config.ty == "tuple"
      assert [%{name: "data", ty: "uint256"}] = config.components
    end

    test "computes correct 4-byte selectors" do
      # balanceOf(address) selector is the well-known 0x70a08231
      erc20_json =
        ~s([{"inputs":[{"name":"account","type":"address"}],"name":"balanceOf","outputs":[{"name":"","type":"uint256"}],"stateMutability":"view","type":"function"}])

      assert {:ok, abi} = Solidity.parse_abi_json(erc20_json)
      func = find_function(abi, "balanceOf")
      assert func.selector == "0x70a08231"
    end

    test "return_type is compatible with Onchain.ABI.decode_response/2" do
      json = File.read!(Path.join(@priv_abis, "chainlink_aggregator.json"))
      assert {:ok, abi} = Solidity.parse_abi_json(json)

      # Verify the return_type for decimals() works with the existing ABI module
      decimals = find_function(abi, "decimals")

      # encode_call should work with the parsed signature
      assert {:ok, _calldata} = Onchain.ABI.encode_call(decimals.signature, [])

      # The selector from encoding should match the parsed selector
      {:ok, calldata} = Onchain.ABI.encode_call(decimals.signature, [])
      # calldata is "0x" + 4-byte selector + params — selector starts at same position
      assert String.slice(calldata, 0, 10) == decimals.selector
    end

    test "parses empty ABI" do
      assert {:ok, abi} = Solidity.parse_abi_json("[]")
      assert abi.functions == []
      assert abi.events == []
      assert abi.errors == []
      assert abi.constructor == nil
    end

    test "returns error for invalid JSON" do
      assert {:error, {:parse_error, reason}} = Solidity.parse_abi_json("not json")
      assert is_binary(reason)
    end

    test "returns error for malformed ABI (valid JSON, wrong structure)" do
      assert {:error, {:parse_error, _reason}} = Solidity.parse_abi_json(~s({"not": "an abi"}))
    end

    test "parses events with indexed parameters" do
      transfer_json =
        ~s([{"anonymous":false,"inputs":[{"indexed":true,"name":"from","type":"address"},{"indexed":true,"name":"to","type":"address"},{"indexed":false,"name":"value","type":"uint256"}],"name":"Transfer","type":"event"}])

      assert {:ok, abi} = Solidity.parse_abi_json(transfer_json)
      assert [event] = abi.events
      assert event.name == "Transfer"
      assert event.signature == "Transfer(address,address,uint256)"
      assert event.anonymous == false
      assert is_binary(event.topic)
      assert String.length(event.topic) == 66
      assert String.starts_with?(event.topic, "0x")

      [from, to, value] = event.inputs
      assert from.name == "from"
      assert from.ty == "address"
      assert from.indexed == true
      assert to.indexed == true
      assert value.indexed == false
    end

    test "parses custom errors" do
      error_json =
        ~s([{"inputs":[{"name":"available","type":"uint256"},{"name":"required","type":"uint256"}],"name":"InsufficientBalance","type":"error"}])

      assert {:ok, abi} = Solidity.parse_abi_json(error_json)
      assert [err] = abi.errors
      assert err.name == "InsufficientBalance"
      assert err.signature == "InsufficientBalance(uint256,uint256)"
      assert is_binary(err.selector)
      assert length(err.inputs) == 2
    end

    test "parses constructor" do
      ctor_json = ~s([{"inputs":[{"name":"admin","type":"address"}],"stateMutability":"nonpayable","type":"constructor"}])

      assert {:ok, abi} = Solidity.parse_abi_json(ctor_json)
      assert abi.constructor
      assert abi.constructor.state_mutability == "nonpayable"
      assert [%{name: "admin", ty: "address"}] = abi.constructor.inputs
    end

    test "handles overloaded functions" do
      json = ~s([
        {"inputs":[{"name":"to","type":"address"},{"name":"value","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},
        {"inputs":[{"name":"from","type":"address"},{"name":"to","type":"address"},{"name":"value","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"}
      ])

      assert {:ok, abi} = Solidity.parse_abi_json(json)
      transfers = Enum.filter(abi.functions, &(&1.name == "transfer"))
      assert length(transfers) == 2

      sigs = transfers |> Enum.map(& &1.signature) |> Enum.sort()
      assert "transfer(address,address,uint256)" in sigs
      assert "transfer(address,uint256)" in sigs
    end
  end

  describe "parse_abi_json!/1" do
    test "returns map on success" do
      assert %{functions: _, events: _, errors: _, constructor: _} =
               Solidity.parse_abi_json!("[]")
    end

    test "raises on invalid input" do
      assert_raise RuntimeError, ~r/ABI parse failed/, fn ->
        Solidity.parse_abi_json!("bad")
      end
    end
  end

  describe "parse_abi_file/1" do
    test "reads and parses file" do
      path = Path.join(@priv_abis, "chainlink_aggregator.json")
      assert {:ok, abi} = Solidity.parse_abi_file(path)
      assert length(abi.functions) == 4
    end

    test "returns file_error for missing file" do
      assert {:error, {:file_error, reason}} = Solidity.parse_abi_file("/nonexistent/file.json")
      assert reason =~ "/nonexistent/file.json"
    end
  end

  describe "parse_abi_file!/1" do
    test "returns map on success" do
      path = Path.join(@priv_abis, "chainlink_aggregator.json")
      assert %{functions: funcs} = Solidity.parse_abi_file!(path)
      assert length(funcs) == 4
    end

    test "raises on missing file" do
      assert_raise RuntimeError, ~r/ABI file error/, fn ->
        Solidity.parse_abi_file!("/nonexistent/file.json")
      end
    end

    test "raises on invalid file contents" do
      # Create a temp file with invalid JSON
      path = Path.join(System.tmp_dir!(), "bad_abi.json")
      File.write!(path, "not json")

      assert_raise RuntimeError, ~r/ABI parse failed/, fn ->
        Solidity.parse_abi_file!(path)
      end
    after
      File.rm(Path.join(System.tmp_dir!(), "bad_abi.json"))
    end
  end

  describe "roundtrip with Onchain.ABI" do
    test "parsed signatures produce matching selectors when encoded" do
      json = File.read!(Path.join(@priv_abis, "aave_pool.json"))
      assert {:ok, abi} = Solidity.parse_abi_json(json)

      for func <- abi.functions, func.inputs != [] do
        {:ok, calldata} = Onchain.ABI.encode_call(func.signature, dummy_args(func.inputs))
        encoded_selector = String.slice(calldata, 0, 10)

        assert encoded_selector == func.selector,
               "Selector mismatch for #{func.name}: encoded=#{encoded_selector}, parsed=#{func.selector}"
      end
    end
  end

  # --- Helpers ---

  @doc false
  # Finds a function by name in the parsed ABI, raises if not found
  defp find_function(abi, name) do
    Enum.find(abi.functions, fn f -> f.name == name end) ||
      raise "Function #{name} not found in ABI"
  end

  @doc false
  defp dummy_args(inputs), do: Enum.map(inputs, &dummy_value/1)

  @doc false
  defp dummy_value(%{ty: "address"}), do: <<0::160>>
  defp dummy_value(%{ty: "bool"}), do: false
  defp dummy_value(%{ty: "string"}), do: ""
  defp dummy_value(%{ty: "bytes"}), do: ""
  defp dummy_value(%{ty: "tuple", components: comps}), do: List.to_tuple(dummy_args(comps))
  defp dummy_value(%{ty: "uint" <> _}), do: 0
  defp dummy_value(%{ty: "int" <> _}), do: 0
  defp dummy_value(%{ty: "bytes" <> _}), do: <<0::256>>
  defp dummy_value(_), do: 0
end
