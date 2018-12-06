defmodule Miner.Mixfile do
  use Mix.Project

  def project do
    [
      app: :elixium_miner,
      version: "1.0.8",
      elixir: "~> 1.7",
      start_permanent: true,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Miner, []},
      extra_applications: [
        :ssl,
        :logger,
        :inets,
        :crypto,
        :elixium_core
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:elixium_core, "~> 0.4"},
      {:decimal, "~> 1.0"},
      {:poison, "~> 3.1"},
      {:distillery, "~> 2.0"}
    ]
  end
end
