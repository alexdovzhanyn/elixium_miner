defmodule Miner.BlockCalculator.Supervisor do
  use Supervisor
  require Logger
  alias Miner.BlockCalculator

  def start_link(_args) do
    address = Elixium.Utilities.get_arg(:address)

    Supervisor.start_link(__MODULE__, address, name: __MODULE__)
  end

  def init(address) do
    children = [
      {BlockCalculator, address}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
