defmodule Miner.BlockCalculator.Mine do
  use Task
  alias Miner.BlockCalculator
  alias Elixium.Blockchain
  alias Elixium.Block
  alias Elixium.Store.Ledger
  alias Elixium.Transaction
  alias Decimal, as: D
  alias Elixium.Utilities
  require Logger

  def start(address) do
    Task.start(__MODULE__, :mine, [address])
  end

  def mine(address) do
    block =
      case Ledger.last_block() do
        :err -> Block.initialize()
        last_block -> Block.initialize(last_block)
      end

    IO.puts "Difficulty: #{block.difficulty}"

    Logger.info("Mining block at index #{block.index}...")

    mined_block =
      block
      |> calculate_coinbase_amount
      |> Transaction.generate_coinbase(address)
      |> merge_block(block)
      |> Block.mine()

    IO.puts "Hash: #{mined_block.hash}"

    Logger.info("Calculated hash for block at index #{block.index}.")

    IO.puts "Took #{(DateTime.utc_now() |> DateTime.to_unix) - block.timestamp} seconds."

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
