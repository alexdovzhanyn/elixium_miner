defmodule Miner.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    port =
      :port
      |> Util.get_arg("-1")
      |> String.to_integer()
      |> case do
           -1 -> nil
           p -> p
         end

    children = [
      {Elixium.Node.Supervisor, [:"Elixir.Miner.PeerRouter", port]},
      Miner.BlockCalculator.Supervisor,
      Miner.PeerRouter.Supervisor
    ]

    children =
      if Util.get_arg(:rpc) do
        [Miner.RPC.Supervisor | children]
      else
        children
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end
