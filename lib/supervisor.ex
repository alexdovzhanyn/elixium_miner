defmodule Miner.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    children = [
      {Elixium.Node.Supervisor, [:"Elixir.Miner.PeerRouter"]},
      Miner.BlockCalculator.Supervisor,
      Miner.PeerRouter.Supervisor
    ]

    children =
      if Application.get_env(:elixium_miner, :rpc) do
        [Miner.RPC.Supervisor | children]
      else
        children
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end
