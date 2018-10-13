defmodule Miner.Peer do
  use GenServer
  require Logger
  alias Elixium.P2P.Peer
  alias Miner.LedgerManager
  alias Miner.BlockCalculator

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_args) do
    Peer.initialize()
    BlockCalculator.start_mining()

    {:ok, []}
  end

  def distribute_block(block) do
    Enum.each(Peer.connected_handlers(), &send(&1, {"BLOCK", block}))
  end

  def handle_info(block = %{type: "BLOCK"}, state) do
    case LedgerManager.handle_new_block(block) do
      :ok ->
        # We've received a valid block. We need to stop mining the block we're
        # currently working on and start mining the new one. We also need to gossip
        # this block to all the nodes we know of.
        Logger.info("Received valid block (#{block.hash}) at index #{block.index}.")

        Peer.gossip("BLOCK", block)
        Logger.info("Gossipped block #{block.hash} to peers.")

        # Restart the miner to build upon this newly received block
        BlockCalculator.restart_mining()


      :ignore -> :ignore # We already know of this block. Ignore it
      :invalid -> Logger.info("Recieved invalid block at index #{block.index}.")
    end

    {:noreply, state}
  end

  def handle_info(transaction = %{type: "TRANSACTION"}, state) do
    {:noreply, state}
  end

end
