defmodule Onchain.RPCCodegenTest do
  use ExUnit.Case, async: true

  @rpc_source Path.expand("../../lib/onchain/rpc.ex", __DIR__)
  @uniform_wrappers [
    :eth_send_raw_transaction,
    :get_balance,
    :block_number,
    :syncing,
    :chain_id,
    :get_transaction_count,
    :eth_get_code
  ]

  test "uniform RPC wrappers are declared through defrpc codegen" do
    ast =
      @rpc_source
      |> File.read!()
      |> Code.string_to_quoted!()

    assert imports_rpc_codegen?(ast)
    assert Enum.sort(@uniform_wrappers) == Enum.sort(macro_call_names(ast, :defrpc))
    assert Enum.sort(@uniform_wrappers) == Enum.sort(macro_call_names(ast, :defrpc_bang))
  end

  defp imports_rpc_codegen?(ast) do
    {_ast, imported?} =
      Macro.prewalk(ast, false, fn
        {:import, _meta, [{:__aliases__, _alias_meta, [:Onchain, :RPC, :Codegen]} | _]} = node, _acc ->
          {node, true}

        node, acc ->
          {node, acc}
      end)

    imported?
  end

  defp macro_call_names(ast, macro_name) do
    {_ast, names} =
      Macro.prewalk(ast, [], fn
        {^macro_name, _meta, [name | _]} = node, acc when is_atom(name) ->
          {node, [name | acc]}

        node, acc ->
          {node, acc}
      end)

    names
  end
end
