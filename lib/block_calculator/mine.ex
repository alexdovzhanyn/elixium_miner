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
    Task.start(__MODULE__, :prepare_block, [address, transactions])
  end

  def prepare_block(address, transactions) do
    Process.flag :trap_exit, true

    block =
      case Ledger.last_block() do
        :err -> Block.initialize()
        last_block -> Block.initialize(last_block)
      end

    block = Map.put(block, :transactions, transactions)

    block
    |> calculate_coinbase_amount
    |> Transaction.generate_coinbase(address)
    |> merge_block(block)
    |> mine()
  end

  def mine(block) do
    max_nonce = 18446744073709551615 + 1
    core_count = :erlang.system_info(:logical_processors)
    whole_work = div(max_nonce, core_count)
    work_rem = rem(max_nonce, core_count) - 1

    {work_partitions, _} = Enum.flat_map_reduce(1..core_count, 0, fn x, acc ->
      if acc == max_nonce do
        {:halt, acc}
      else
        if x == 1 do
          new_acc = acc + whole_work + work_rem
          {[Range.new(acc, new_acc)], new_acc}
        else
          new_acc = acc + whole_work
          {[Range.new(acc + 1, new_acc)], new_acc}
        end
      end
    end)

    Logger.info("Mining block at index #{:binary.decode_unsigned(block.index)}...")

    miners =
      work_partitions
      |> Enum.with_index()
      |> Enum.map(fn {nonce_range, cpu_number} ->
        starting_nonce =
          nonce_range
          |> Enum.at(0)
          |> :binary.encode_unsigned()
          |> Utilities.zero_pad(8)

        b = Map.put(block, :nonce, starting_nonce)
        {pid, _ref} = spawn_monitor(Block, :mine, [b, nonce_range, cpu_number])

        pid
      end)

    receive do
      {:EXIT, _, :mine_interrupt} ->
        Enum.each(miners, & Process.exit(&1, :kill))
        Process.exit(self(), :normal)
      {:DOWN, _, :process, _, :not_in_range} ->
        IO.puts "Block wasnt in nonce range"
      {:DOWN, _, :process, _, mined_block} ->
        Enum.each(miners, & Process.exit(&1, :kill))

        log_finished_block(mined_block)

        BlockCalculator.finished_mining(mined_block)
      _ -> :miner_exited
    end
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

  defp log_finished_block(block) do
    earnings =
      block.transactions
      |> Enum.at(0)
      |> Map.get(:outputs)
      |> Enum.reduce(Decimal.new(0), fn o, acc -> Decimal.add(acc, o.amount) end)

    nonce = :binary.decode_unsigned(block.nonce)
    index = :binary.decode_unsigned(block.index)

    reward =
      block.index
      |> :binary.decode_unsigned()
      |> Block.calculate_block_reward()

    block_size =
      block
      |> Elixium.BlockEncoder.encode()
      |> byte_size()

    Logger.info(
    "\e[32mFinished mining block at index #{index}\e[0m\n
    Hash: \e[34m#{block.hash}\e[0m
    Merkle: \e[34m#{block.merkle_root}\e[0m
    Nonce: \e[34m#{nonce}\e[0m    Difficulty: \e[34m#{block.difficulty}\e[0m    Block Size (Bytes): \e[34m#{block_size}\e[0m
    Transactions: \e[34m#{length(block.transactions)}\e[0m    Block Reward: \e[34m #{reward} \e[0m
    Total Earnings: \e[34m#{earnings}\e[0m
    "
    )
  end
end
