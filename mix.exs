defmodule DexAggregate.MixProject do
  use Mix.Project
  @moduledoc false

  def project do
    [
      app: :dexaggregate_elixir,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {DexAggregate.Application, []},
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 1.5"},
      {:poison, "~> 4.0"},
      {:websockex, "~> 0.4.0"},
      {:plug_cowboy, "~> 2.0"},
      {:memoize, "~> 1.3"},
	    {:absinthe, "~> 1.4"},
	    {:absinthe_plug, "~> 1.4"},
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
