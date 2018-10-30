defmodule Miner.BlockCalculator.Mine do
  use Task
  alias Miner.BlockCalculator
  alias Elixium.Blockchain
  alias Elixium.Blockchain.Block
  alias Elixium.Store.Ledger
  alias Elixium.Transaction
  alias Decimal, as: D
  alias Elixium.Utilities
  require Logger

  def start(address) do
    Task.start(__MODULE__, :mine, [address])
  end

  def mine(address) do
    last_block = Ledger.last_block()
    block = Block.initialize(last_block)

    difficulty =
      if rem(block.index, Blockchain.diff_rebalance_offset()) == 0 do
        new_difficulty = Blockchain.recalculate_difficulty() + last_block.difficulty
        IO.puts("Difficulty recalculated! Changed from #{last_block.difficulty} to #{new_difficulty}")
        new_difficulty
      else
        last_block.difficulty
      end

    block = %{block | difficulty: difficulty}

    before = :os.system_time()

    Logger.info("Mining block at index #{block.index}...")

    mined_block =
      block
      |> calculate_coinbase_amount
      |> Transaction.generate_coinbase(address)
      |> merge_block(block)
      |> Block.mine()

    BlockCalculator.finished_mining(mined_block)
  end

  @spec calculate_coinbase_amount(Block) :: Decimal
  defp calculate_coinbase_amount(block) do
    D.add(Block.calculate_block_reward(block.index), Block.total_block_fees(block.transactions))
  end

  defp merge_block(coinbase, block) do
    new_transactions = [coinbase | block.transactions]
    txoids = Enum.map(new_transactions, & &1.id)

    Map.merge(block, %{
      transactions: new_transactions,
      merkle_root: Utilities.calculate_merkle_root(txoids)
    })
  end
end
