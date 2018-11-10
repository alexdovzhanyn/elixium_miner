defmodule Miner do
  use Application

  def start(_type, _args) do
    Elixium.Store.Ledger.initialize()

    # TODO: Make genesis block mined rather than hard-coded
    if Elixium.Store.Ledger.empty?() do
      Elixium.Store.Ledger.append_block(Elixium.Block.initialize())
    else
      Elixium.Store.Ledger.hydrate()
    end

    Elixium.Store.Utxo.initialize()
    Elixium.Pool.Orphan.initialize()
    Miner.Supervisor.start_link()
  end

end
