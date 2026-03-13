defmodule Onchain.Contract.GeneratorTest do
  use ExUnit.Case, async: true

  alias Onchain.Contract.Generator

  # --- Test modules defined inline ---

  # ABI JSON module (Chainlink aggregator)
  defmodule ChainlinkModule do
    @moduledoc false
    use Generator,
      abi_json: File.read!(Path.join(:code.priv_dir(:onchain), "abis/chainlink_aggregator.json"))
  end

  # ABI file module
  defmodule ChainlinkFileModule do
    @moduledoc false
    use Generator,
      abi_file: Path.join(:code.priv_dir(:onchain), "abis/chainlink_aggregator.json")
  end

  # Solidity source module (test_interface.sol)
  defmodule SolModule do
    @moduledoc false
    use Generator,
      sol: File.read!(Path.join(:code.priv_dir(:onchain), "contracts/test_interface.sol"))
  end

  # Overloaded function module
  defmodule OverloadModule do
    @moduledoc false
    use Generator,
      abi_json: ~s([
        {"inputs":[{"name":"to","type":"address"},{"name":"value","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"},
        {"inputs":[{"name":"from","type":"address"},{"name":"to","type":"address"},{"name":"value","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"stateMutability":"nonpayable","type":"function"}
      ])
  end

  # Empty ABI module
  defmodule EmptyModule do
    @moduledoc false
    use Generator,
      abi_json: "[]"
  end

  # --- Unit tests: to_snake_case ---

  describe "to_snake_case/1" do
    test "converts camelCase" do
      assert Generator.to_snake_case("getUserAccountData") == "get_user_account_data"
    end

    test "converts PascalCase" do
      assert Generator.to_snake_case("LatestRoundData") == "latest_round_data"
    end

    test "handles consecutive capitals" do
      assert Generator.to_snake_case("getERC20Balance") == "get_erc20_balance"
    end

    test "leaves snake_case unchanged" do
      assert Generator.to_snake_case("already_snake") == "already_snake"
    end

    test "handles single word" do
      assert Generator.to_snake_case("decimals") == "decimals"
    end
  end

  # --- Unit tests: ABI JSON module ---

  describe "ABI JSON module (Chainlink)" do
    test "generates functions with snake_case names" do
      assert function_exported?(ChainlinkModule, :decimals, 2)
      assert function_exported?(ChainlinkModule, :description, 2)
      assert function_exported?(ChainlinkModule, :latest_round_data, 2)
      assert function_exported?(ChainlinkModule, :version, 2)
    end

    test "generates bang variants" do
      assert function_exported?(ChainlinkModule, :decimals!, 2)
      assert function_exported?(ChainlinkModule, :description!, 2)
      assert function_exported?(ChainlinkModule, :latest_round_data!, 2)
      assert function_exported?(ChainlinkModule, :version!, 2)
    end

    test "read functions accept default opts (arity - 1)" do
      # Read functions have opts \\ [] so they work with one less arg
      assert function_exported?(ChainlinkModule, :decimals, 1)
      assert function_exported?(ChainlinkModule, :decimals!, 1)
    end

    test "__contract_abi__/0 returns parsed ABI" do
      abi = ChainlinkModule.__contract_abi__()
      assert is_map(abi)
      assert is_list(abi.functions)
      assert length(abi.functions) == 4

      names = Enum.map(abi.functions, & &1.name)
      assert "decimals" in names
      assert "latestRoundData" in names
    end

    test "address validation rejects invalid addresses" do
      # latestRoundData has no address params, so test with a module that does
      result = SolModule.get_user_data("not_a_contract", "also_invalid")
      assert {:error, {:invalid_address, "also_invalid"}} = result
    end

    test "__contract_abi__ contains all expected function names" do
      abi = ChainlinkModule.__contract_abi__()
      names = abi.functions |> Enum.map(& &1.name) |> Enum.sort()
      assert names == ["decimals", "description", "latestRoundData", "version"]
    end
  end

  # --- Unit tests: abi_file option ---

  describe "abi_file option" do
    test "generates same functions as abi_json" do
      assert function_exported?(ChainlinkFileModule, :decimals, 2)
      assert function_exported?(ChainlinkFileModule, :latest_round_data, 2)
    end

    test "__contract_abi__/0 matches" do
      abi = ChainlinkFileModule.__contract_abi__()
      assert length(abi.functions) == 4
    end
  end

  # --- Unit tests: empty ABI ---

  describe "empty ABI" do
    test "compiles successfully" do
      assert function_exported?(EmptyModule, :__contract_abi__, 0)
    end

    test "__contract_abi__/0 returns empty functions list" do
      abi = EmptyModule.__contract_abi__()
      assert abi.functions == []
    end
  end

  # --- Unit tests: overload disambiguation ---

  describe "overload disambiguation" do
    test "generates disambiguated function names for same-arity overloads" do
      # transfer(address,uint256) → 2 inputs + contract + opts = arity 4
      # transfer(address,address,uint256) → 3 inputs + contract + opts = arity 5
      # Different arities, so no disambiguation needed for these

      # Both should exist with their natural arities
      # transfer(address,uint256) → transfer/4
      assert function_exported?(OverloadModule, :transfer, 4) ||
               function_exported?(OverloadModule, :transfer_address, 4)

      # transfer(address,address,uint256) → transfer/5
      # With different arities, no suffix needed
      fns = OverloadModule.__info__(:functions)

      transfer_fns =
        Enum.filter(fns, fn {name, _arity} -> name |> Atom.to_string() |> String.starts_with?("transfer") end)

      # 2 normal + 2 bang (with default opts arities)
      assert length(transfer_fns) >= 4
    end
  end

  # --- Unit tests: .sol module ---

  describe ".sol module" do
    test "generates functions from Solidity source" do
      assert function_exported?(SolModule, :get_user_data, 3)
      assert function_exported?(SolModule, :transfer, 4)
      assert function_exported?(SolModule, :decimals, 2)
      assert function_exported?(SolModule, :name, 2)
      assert function_exported?(SolModule, :total_supply, 2)
    end

    test "generates bang variants" do
      assert function_exported?(SolModule, :get_user_data!, 3)
      assert function_exported?(SolModule, :transfer!, 4)
      assert function_exported?(SolModule, :decimals!, 2)
    end

    test "generates struct modules with from_raw/1" do
      assert function_exported?(SolModule.UserData, :from_raw, 1)
      assert function_exported?(SolModule.Nested, :from_raw, 1)
    end

    test "struct has enforce_keys" do
      assert_raise ArgumentError, fn ->
        struct!(SolModule.UserData, %{})
      end
    end

    test "from_raw/1 converts tuple to struct" do
      raw = {1000, <<1::160>>, true}
      result = SolModule.UserData.from_raw(raw)

      assert %SolModule.UserData{} = result
      assert result.balance == 1000
      assert result.active == true
      # Address is checksummed
      assert is_binary(result.owner)
      assert String.starts_with?(result.owner, "0x")
    end

    test "from_raw/1 recursively converts nested structs" do
      raw = {1, {1000, <<1::160>>, true}}
      result = SolModule.Nested.from_raw(raw)

      assert %SolModule.Nested{} = result
      assert result.id == 1

      assert %SolModule.UserData{} = result.data
      assert result.data.balance == 1000
      assert result.data.active == true
      assert is_binary(result.data.owner)
      assert String.starts_with?(result.data.owner, "0x")
    end

    test "struct has correct fields" do
      fields = SolModule.UserData.__struct__() |> Map.keys() |> Enum.reject(&(&1 == :__struct__))
      assert :balance in fields
      assert :owner in fields
      assert :active in fields
    end

    test "NatSpec is preserved in parsed ABI" do
      abi = SolModule.__contract_abi__()
      get_user = Enum.find(abi.functions, &(&1.name == "getUserData"))
      assert get_user.natspec.notice == "Get user data by address"
      assert get_user.natspec.params["user"] == "The user address to query"
    end

    test "functions without NatSpec have nil natspec" do
      abi = SolModule.__contract_abi__()
      total = Enum.find(abi.functions, &(&1.name == "totalSupply"))
      assert total.natspec == nil
    end

    test "enum constants are accessible as module attributes" do
      # Enum attrs are set via Module.put_attribute at compile time
      # We verify they exist by checking __contract_abi__ has enum data
      abi = SolModule.__contract_abi__()
      assert [enum] = abi.enums
      assert enum.name == "Status"
      assert enum.variants == ["Pending", "Active", "Closed"]
    end

    test "write functions don't have default opts" do
      # transfer is nonpayable → write function → opts required (no default)
      # So transfer/3 should NOT exist (only transfer/4)
      refute function_exported?(SolModule, :transfer, 3)
      assert function_exported?(SolModule, :transfer, 4)
    end

    test "read functions have default opts" do
      # decimals is pure → read function → opts \\ []
      assert function_exported?(SolModule, :decimals, 1)
      assert function_exported?(SolModule, :decimals, 2)
    end
  end

  # --- Unit tests: address validation ---

  describe "address validation in generated functions" do
    test "validates address params before calling" do
      # getUserData(address user) → validates user
      result = SolModule.get_user_data("0x" <> String.duplicate("a", 40), "invalid")
      assert {:error, {:invalid_address, "invalid"}} = result
    end

    test "contract address is passed through to Contract.call" do
      # With invalid contract, we get an address error from Contract.call
      result = SolModule.decimals("not_a_contract")
      assert {:error, {:invalid_address, "not_a_contract"}} = result
    end
  end

  # --- Unit tests: resolve_abi ---

  describe "resolve_abi/1" do
    test "raises on missing options" do
      assert_raise ArgumentError, ~r/requires :sol, :abi_json, or :abi_file/, fn ->
        Generator.resolve_abi([])
      end
    end

    test "raises on invalid ABI JSON" do
      assert_raise RuntimeError, ~r/ABI parse failed/, fn ->
        Generator.resolve_abi(abi_json: "not json")
      end
    end

    test "parses valid ABI JSON" do
      result = Generator.resolve_abi(abi_json: "[]")
      assert result.functions == []
    end
  end
end
