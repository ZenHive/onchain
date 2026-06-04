defmodule Onchain.MixProject do
  use Mix.Project

  @version "0.6.0"
  @source_url "https://github.com/ZenHive/onchain"

  def project do
    [
      app: :onchain,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      deps: deps(),
      dialyzer: dialyzer(),
      description: description(),
      package: package(),
      docs: docs(),
      source_url: @source_url
    ]
  end

  def cli do
    [
      preferred_envs: [
        "test.json": :test,
        "dialyzer.json": :dev
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:cartouche, "~> 0.2.2"},
      {:decimal, "~> 3.1.1"},
      {:descripex, "~> 0.7.0"},
      {:jason, "~> 1.4"},
      {:zen_websocket, "~> 0.4.2"},

      # Dev/test tooling
      {:tidewave, "~> 0.5.6", only: :dev},
      {:bandit, "~> 1.0", only: :dev},
      {:ex_unit_json, "~> 0.5.0", only: [:dev, :test], runtime: false},
      {:dialyzer_json, "~> 0.2.0", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.23.0", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.14.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false},
      {:ex_dna, "~> 1.3", only: [:dev, :test], runtime: false},
      {:ex_ast, "~> 0.12.0", only: [:dev, :test], runtime: false},
      {:reach, "~> 2.7.1", only: [:dev, :test], runtime: false},
      {:boxart, "~> 0.3.3", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    "Shared Ethereum/blockchain library for read (eth_call) and write (transaction signing) operations using cartouche."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "Onchain",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp aliases do
    [
      tidewave: [
        "run --no-halt -e 'Agent.start(fn -> Bandit.start_link(plug: Tidewave, port: 4007) end)'"
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp dialyzer do
    [
      # OOM mitigation: skip transitive deps (default is :app_tree).
      # Tidewave/bandit's HTTP stack (plug, finch, mint, gun, cowlib, etc.)
      # is not in lib/'s call graph and bloats PLT to ~800 modules.
      plt_add_deps: :apps_direct,
      plt_add_apps: [:mix, :hieroglyph],
      plt_local_path: "priv/plts",
      plt_core_path: "priv/plts"
    ]
  end
end
