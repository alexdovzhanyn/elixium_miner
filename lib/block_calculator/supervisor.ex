defmodule Miner.BlockCalculator.Supervisor do
  use Supervisor
  require Logger
  alias Miner.BlockCalculator

  def start_link(_args) do
    address = Application.get_env(:elixium_miner, :address)

    if address == "" || address == nil do
      Logger.error("No miner address specified! Add one in config.toml")
      Process.exit(self(), :kill)
    end

    Supervisor.start_link(__MODULE__, address, name: __MODULE__)
  end

  def init(address) do
    children = [
      {BlockCalculator, address}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
