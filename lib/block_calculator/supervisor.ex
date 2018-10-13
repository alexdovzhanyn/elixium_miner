defmodule Miner.BlockCalculator.Supervisor do
  use Supervisor
  require Logger
  alias Miner.BlockCalculator

  def start_link(_args) do
    address =
      case Application.get_env(:elixium_miner, :address) do
        nil ->
          Logger.error("No miner address set! Please add a public key to config/config.exs!")
          Process.exit(self(), :kill)
        pkey -> pkey
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
