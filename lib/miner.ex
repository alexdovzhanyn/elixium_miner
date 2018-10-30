defmodule Miner do
  use Application

  def start(_type, _args) do
    Elixium.Store.Ledger.initialize()
    Elixium.Store.Utxo.initialize()
    Elixium.Blockchain.initialize()
    Elixium.Pool.Orphan.initialize()
    Miner.Supervisor.start_link()
  end

end
