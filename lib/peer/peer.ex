defmodule Miner.Peer do
  use GenServer
  require Logger
  require IEx
  alias Elixium.P2P.Peer
  alias Miner.LedgerManager
  alias Miner.BlockCalculator
  alias Elixium.Store.Ledger

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_args) do
    if port = Application.get_env(:elixium_miner, :port) do
      Peer.initialize(port)
    else
      Peer.initialize()
    end

    BlockCalculator.start_mining()

    {:ok, []}
  end

  @doc """
    Sends a newly mined block to the connection handlers so that it can be
    relayed across the network.
  """
  @spec distribute_block(Elixium.Blockchain.Block) :: none
  def distribute_block(block) do
    Enum.each(Peer.connected_handlers(), &send(&1, {"BLOCK", block}))
  end

  # Handles recieved blocks
  def handle_info({block = %{type: "BLOCK"}, _caller}, state) do
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

      :gossip ->
        # For one reason or another, we want to gossip this block without
        # restarting our current block calculation. (Perhaps this is a fork block)
        Peer.gossip("BLOCK", block)
        Logger.info("Gossipped block #{block.hash} to peers.")

      :ignore -> :ignore # We already know of this block. Ignore it
      :invalid -> Logger.info("Recieved invalid block at index #{block.index}.")
    end

    {:noreply, state}
  end

  # Handles a block query request, where another peer has asked this node to send
  # all the blocks it has since a given index.
  def handle_info({block_query_request = %{type: "BLOCK_QUERY_REQUEST"}, caller}, state) do
    # TODO: This is a possible DOS vulnerability if an attacker requests a very
    # high amount of blocks. Need to figure out a better way to do this; maybe
    # we need to limit the maximum amount of blocks a peer is allowed to request.
    blocks =
      block_query_request.starting_at
      |> Range.new(Ledger.last_block().index)
      |> Enum.map(&Ledger.block_at_height/1)

    send(caller, {
      "BLOCK_QUERY_RESPONSE",
      %{blocks: blocks}
    })

    {:noreply, state}
  end

  # Handles a block query response, where we've requested new blocks and are now
  # getting a response with potentially new blocks
  def handle_info({block_query_response = %{type: "BLOCK_QUERY_RESPONSE"}, _caller}, state) do
    if length(block_query_response.blocks) > 0 do
      Logger.info("Recieved #{length(block_query_response.blocks)} new blocks from peer.")
      Enum.each(block_query_response.blocks, &LedgerManager.handle_new_block/1)

      # Restart the miner to build upon these newly received blocks
      BlockCalculator.restart_mining()
    end

    {:noreply, state}
  end

  def handle_info({transaction = %{type: "TRANSACTION"}, _caller}, state) do
    {:noreply, state}
  end

  def handle_info({:new_outbound_connection, handler_pid}, state) do
    if length(Peer.connected_handlers()) == 1 do
      # We just went from 0 connections to 1 connection. This indicates that we've
      # likely just joined the network. Let's ask our peer for new blocks, if there
      # are any.

      Logger.info("Reconnected to the network! Querying for missed blocks...")

      send(handler_pid, {
        "BLOCK_QUERY_REQUEST",
        %{starting_at: Ledger.last_block().index + 1}
      })
    end

    {:noreply, state}
  end

  def handle_info(_, state) do
    Logger.warn("Received message that isn't handled by any other case.")

    {:noreply, state}
  end

end
