defmodule Mix.Tasks.Onchain.ScrapeErigonMethods do
  @shortdoc "Scrapes vendored Erigon trace/ots RPC methods"

  @moduledoc """
  Scrapes Erigon trace/otterscan JSON-RPC methods from vendored Go source.
  """

  use Mix.Task

  @erigon_commit "3578acb3a63d34ca746ff03c5350584c1a4eed0f"
  @source_root Path.expand("../../../priv/specs/erigon-#{@erigon_commit}/jsonrpc", __DIR__)
  @output_path Path.expand("../../../priv/specs/erigon-methods.json", __DIR__)
  @rpc_receivers %{
    "OtterscanAPIImpl" => "ots",
    "TraceAPIImpl" => "trace"
  }

  @method_query """
  (method_declaration
    receiver: (parameter_list
      (parameter_declaration
        type: [
          (pointer_type (type_identifier) @receiver)
          (type_identifier) @receiver
        ]))
    name: (field_identifier) @method)
  """

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(args) do
    {opts, _argv, invalid} =
      OptionParser.parse(args, strict: [source: :string, output: :string])

    if invalid != [] do
      Mix.raise("invalid options: #{inspect(invalid)}")
    end

    source = Keyword.get(opts, :source, @source_root)
    output = Keyword.get(opts, :output, @output_path)

    case extract_methods(source) do
      {:ok, methods} ->
        output |> Path.dirname() |> File.mkdir_p!()
        File.write!(output, [Jason.encode_to_iodata!(methods, pretty: true), ?\n])
        Mix.shell().info("Wrote #{length(methods)} Erigon RPC methods to #{Path.relative_to_cwd(output)}")

      {:error, reason} ->
        Mix.raise("failed to scrape Erigon methods: #{inspect(reason)}")
    end
  end

  @doc false
  @spec extract_methods(Path.t()) :: {:ok, [map()]} | {:error, term()}
  def extract_methods(source_root) when is_binary(source_root) do
    with :ok <- ensure_source_root(source_root),
         :ok <- ensure_go_parser() do
      source_root
      |> go_files()
      |> Enum.flat_map(&extract_file(&1, source_root))
      |> Enum.uniq_by(& &1["method"])
      |> Enum.sort_by(& &1["method"])
      |> then(&{:ok, &1})
    end
  end

  defp ensure_source_root(source_root) do
    if File.dir?(source_root) do
      :ok
    else
      {:error, {:missing_source_root, source_root}}
    end
  end

  defp ensure_go_parser do
    unless TreeSitterLanguagePack.has_language("go") do
      _ = TreeSitterLanguagePack.download(["go"])
    end

    :ok
  end

  defp go_files(source_root) do
    source_root
    |> Path.join("**/*.go")
    |> Path.wildcard()
    |> Enum.reject(&String.ends_with?(&1, "_test.go"))
  end

  defp extract_file(path, source_root) do
    path
    |> File.read!()
    |> TreeSitterLanguagePack.extract(extraction_config())
    |> get_in(["results", "rpc_methods", "matches"])
    |> Enum.flat_map(&method_from_match(&1, path, source_root))
  end

  defp extraction_config do
    Jason.encode!(%{
      "language" => "go",
      "patterns" => %{
        "rpc_methods" => %{
          "query" => @method_query,
          "capture_output" => "Text"
        }
      }
    })
  end

  defp method_from_match(%{"captures" => captures}, path, source_root) do
    receiver = capture_text(captures, "receiver")
    go_method = capture_text(captures, "method")

    with namespace when is_binary(namespace) <- Map.get(@rpc_receivers, receiver),
         true <- exported?(go_method) do
      [
        %{
          "method" => "#{namespace}_#{lower_first(go_method)}",
          "namespace" => namespace,
          "receiver" => receiver,
          "go_method" => go_method,
          "source" => Path.relative_to(path, source_root)
        }
      ]
    else
      _ -> []
    end
  end

  defp capture_text(captures, name) do
    captures
    |> Enum.find(&(&1["name"] == name))
    |> Map.fetch!("text")
  end

  defp exported?(<<first::utf8, _rest::binary>>) do
    String.upcase(<<first::utf8>>) == <<first::utf8>>
  end

  defp exported?(_method), do: false

  defp lower_first(<<first::utf8, rest::binary>>) do
    String.downcase(<<first::utf8>>) <> rest
  end
end
