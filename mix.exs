defmodule Dexaggregatex.MixProject do
  use Mix.Project

  def project do
    [
      app: :dexaggregatex,
      version: "0.1.0",
      elixir: "~> 1.8",
      description: desc(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [plt_add_deps: :transitive]
    ]
  end

  def application do
    [
      mod: {Dexaggregatex.Application, []},
      extra_applications: [:logger, :crypto, :runtime_tools],
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp desc() do
    "GraphQL API serving aggregated market data from decentralized exchanges."
  end

  defp package() do
    [
      licenses: ["GNU AGPLv3"]
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.4.6"},
      {:phoenix_pubsub, "~> 1.1"},
      {:phoenix_html, "~> 2.11"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:httpoison, "~> 1.5"},
      {:poison, "~> 3.1"},
      {:jason, "~> 1.1"},
      {:websockex, "~> 0.4.0"},
      {:plug_cowboy, "~> 2.0"},
      {:absinthe, "~> 1.4"},
      {:absinthe_plug, "~> 1.4"},
      {:absinthe_phoenix, "~> 1.4"},
      {:neuron, "~> 1.2.0"},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:earmark, "~> 1.2", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.19", only: [:dev], runtime: false},
      {:distillery, "~> 2.0"},
      {:edeliver, "~> 1.6"},
      {:cors_plug, "~> 2.0"}
      # How to add deps (run "mix deps.get" afterwards):
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
