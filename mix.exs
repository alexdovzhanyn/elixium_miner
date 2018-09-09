defmodule Miner.Mixfile do
  use Mix.Project

  def project do
    [
      app: :elixium_miner,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: true,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {ElixiumMinerApp, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:elixium_core, "~> 0.1"},
      {:decimal, "~> 1.0"}
    ]
  end
end
