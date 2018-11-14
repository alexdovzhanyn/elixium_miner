defmodule Miner.BlockCalculator do
  use GenServer
  require IEx
  require Logger
  alias Miner.BlockCalculator.Mine
  alias Miner.Peer
  alias Elixium.Validator
  alias Elixium.Store.Ledger
  alias Elixium.Store.Utxo
  alias Elixium.Error

  def start_link(address) do
    GenServer.start_link(__MODULE__, address, name: __MODULE__)
  end

  def init(address) do
    {:ok, %{address: address}}
  end

  @doc """
    Tell the block calculator to stop mining the block it's working on. This is
    usually called when we've received a new block at the index that we're
    currently mining at; we don't want to continue mining an old block, so we
    start over on a new block.
  """
  def interrupt_mining do
    GenServer.cast(__MODULE__, :interrupt)
  end

  @doc """
    Starts the mining task to mine the next block in the chain.
  """
  def start_mining do
    GenServer.cast(__MODULE__, :start)
  end

  @doc """
    Called pretty much exclusively by the mine task to signal that it has found
    a suitable hash. This will distribute the block to known peers and start a
    task to mine the next block.
  """
  def finished_mining(block) do
    GenServer.cast(__MODULE__, {:hash_found, block})
  end

  @doc """
    Tell the block calculator to stop mining the block it's working on and start
    a new task. This is usually called when we've received a new block at the
    index that we're currently mining at; we don't want to continue mining an
    old block, so we start over on a new block.
  """
  def restart_mining do
    GenServer.cast(__MODULE__, :restart)
  end

  def handle_cast(:interrupt, state) do
    Process.exit(state.mine_task, :mine_interrupt)
    Logger.info("Interrupted mining of current block.")

    state = Map.put(state, :mine_task, nil)
    {:noreply, state}
  end

  def handle_cast(:start, state) do
    {:ok, pid} = Mine.start(state.address)

    state = Map.put(state, :mine_task, pid)
    {:noreply, state}
  end

  def handle_cast(:restart, state) do
    Process.exit(state.mine_task, :mine_interrupt)
    Logger.info("Interrupted mining of current block.")

    {:ok, pid} = Mine.start(state.address)

    state = Map.put(state, :mine_task, pid)
    {:noreply, state}
  end

  def handle_cast({:hash_found, block}, state) do
    case Validator.is_block_valid?(block, block.difficulty) do
      :ok ->
        Ledger.append_block(block)
        Utxo.update_with_transactions(block.transactions)
        Peer.distribute_block(block)
        start_mining()

      err ->
        Logger.error("Calculated hash for new block, but didn't pass validation:")

        err
        |> Error.to_string()
        |> Logger.error()

        start_mining()
    end

    {:noreply, state}
  end
end
