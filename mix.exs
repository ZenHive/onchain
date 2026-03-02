defmodule Onchain.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/titofranco/onchain"

  def project do
    [
      app: :onchain,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
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
      extra_applications: [:logger],
      mod: {Onchain.Application, []}
    ]
  end

  defp deps do
    [
      {:signet, "~> 1.6"},
      {:decimal, "~> 2.0"},
      {:descripex, "~> 0.4"},

      # Dev/test tooling
      {:tidewave, "~> 0.5", only: :dev},
      {:bandit, "~> 1.0", only: :dev},
      {:ex_unit_json, "~> 0.4", only: [:dev, :test], runtime: false},
      {:dialyzer_json, "~> 0.1", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.22", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.39", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Shared Ethereum/blockchain library for read (eth_call) and write (transaction signing) operations using signet."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "Onchain",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix],
      plt_local_path: "_build/dialyzer",
      plt_core_path: "_build/dialyzer"
    ]
  end
end
