defmodule ElixiumMinerApp do
  use Application
  require Logger
  alias Elixium.Store.Ledger
  alias Elixium.Store.Utxo
  alias Elixium.Blockchain
  alias Elixium.P2P.Peer

  def start(_type, _args) do
    Ledger.initialize()
    Utxo.initialize()
    chain = Blockchain.initialize()

    address =
      case Application.get_env(:elixium_miner, :address) do
        nil ->
          Logger.error("No miner address set! Please add a public key to config/config.exs!")
          Process.exit(self(), :kill)
        pkey -> pkey
      end

    comm_pid = spawn_link(Miner, :main, [chain, address, hd(chain).difficulty])

    if port = Application.get_env(:elixium_miner, :port) do
      Peer.initialize(comm_pid, port)
    else
      Peer.initialize(comm_pid)
    end

    {:ok, self()}
  end
end
