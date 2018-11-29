defmodule Miner.BlockCalculator.Mine do
  use Task
  alias Miner.BlockCalculator
  alias Elixium.Block
  alias Elixium.Store.Ledger
  alias Elixium.Transaction
  alias Decimal, as: D
  alias Elixium.Utilities
  require Logger

  def start(address, transactions) do
    Task.start(__MODULE__, :mine, [address, transactions])
  end

  def mine(address, transactions) do
    block =
      case Ledger.last_block() do
        :err -> Block.initialize()
        last_block -> Block.initialize(last_block)
      end

    block = Map.put(block, :transactions, transactions)

    Logger.info("Mining block at index #{:binary.decode_unsigned(block.index)}...")

    mined_block =
      block
      |> calculate_coinbase_amount
      |> Transaction.generate_coinbase(address)
      |> merge_block(block)
      |> Block.mine()

    log_finished_block(mined_block)

    BlockCalculator.finished_mining(mined_block)
  end

  @spec calculate_coinbase_amount(Block) :: Decimal
  defp calculate_coinbase_amount(block) do
    index = :binary.decode_unsigned(block.index)
    D.add(Block.calculate_block_reward(index), Block.total_block_fees(block.transactions))
  end

  defp merge_block(coinbase, block) do
    transactions = [coinbase | block.transactions]
    txdigests = Enum.map(transactions, &:erlang.term_to_binary/1)

    Map.merge(block, %{
      transactions: transactions,
      merkle_root: Utilities.calculate_merkle_root(txdigests)
    })
  end

  defp log_finished_block(block), do: Logger.info(
    "\e[32mFinished mining block at index #{:binary.decode_unsigned(block.index)}\e[0m\n
  Hash: \e[34m#{block.hash}\e[0m
  Merkle: \e[34m#{block.merkle_root}\e[0m
  Nonce: \e[34m#{:binary.decode_unsigned(block.nonce)}\e[0m    Difficulty: \e[34m#{block.difficulty}\e[0m    Block Size (Bytes): \e[34m #{block |> Elixium.BlockEncoder.encode() |> byte_size()}\e[0m
  Transactions: \e[34m#{length(block.transactions)}\e[0m    Block Reward: \e[34m #{Block.calculate_block_reward(:binary.decode_unsigned(block.index))} \e[0m
"
  )
end
