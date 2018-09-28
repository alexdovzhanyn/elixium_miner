defmodule Miner do
  alias Elixium.Blockchain
  alias Elixium.Blockchain.Block
  alias Elixium.Validator
  alias Elixium.Transaction
  alias Elixium.Utilities
  alias Elixium.Store.Ledger
  alias Elixium.Error
  alias Elixium.Pool.Orphan
  alias Elixium.P2P.Peer
  alias Decimal, as: D
  require Logger

  @index_space 10
  @nonce_space 10
  @elapsed_space 10

  def main(address, transaction_pool \\ []) do
    {:message_queue_len, queue} = Process.info(self(), :message_queue_len)

    transaction_pool =
      if queue > 0 do
        receive do
          block = %{type: "BLOCK"} ->
            # Check if we've already received a block at this index. If we have,
            # diff it against the one we've stored.
            case Ledger.block_at_height(block.index) do
              :none -> evaluate_new_block(block)
              stored_block -> handle_possible_fork(block, stored_block)
            end
          transaction = %{type: "TRANSACTION"} ->
            # Don't re-validate and re-send a transaction we've already received.
            # This eliminates looping issues where nodes pass the same transaction
            # back and forth.
            if !Enum.member?(transaction_pool, transaction) && Validator.valid_transaction?(transaction) do
              Logger.info("Received valid transaction #{transaction.id}. Forwarding to peers.")
              Peer.gossip("TRANSACTION", transaction)

              [transaction | transaction_pool]
            end
          _ -> IO.puts "no match"
        end
      else
        transaction_pool
      end

    # Wait until we're connected to at least one peer
    await_peer_connection()

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

    IO.write("Mining block #{block.index}...\r")

    before = :os.system_time()

    # TODO: move into own process that can get killed if a new block arrives
    block =
      block
      |> calculate_coinbase_amount
      |> Transaction.generate_coinbase(address)
      |> merge_block(block)
      |> Block.mine()

    blue = "\e[34m"
    clear = "\e[0m"
    elapsed = (:os.system_time() - before) / 1_000_000_000

    index_str = "#{blue}Index:#{clear} #{String.pad_trailing(inspect(block.index), @index_space)}"
    hash_str = "#{blue}Hash:#{clear} #{block.hash}"
    nonce_str = "#{blue}Nonce:#{clear} #{String.pad_trailing(inspect(block.nonce), @nonce_space)}"

    elapsed_str =
      "#{blue}Elapsed (s):#{clear} #{String.pad_trailing(inspect(elapsed), @elapsed_space)}"

    hashrate_str = "#{blue}Hashrate (H/s):#{clear} #{round(block.nonce / elapsed)}"

    IO.puts("#{index_str} #{hash_str} #{nonce_str} #{elapsed_str} #{hashrate_str}")

    case Validator.is_block_valid?(block, difficulty) do
      :ok ->
        Blockchain.add_block(block)
        distribute_block(block)
        main(address, transaction_pool)

      err ->
        IO.puts(Error.to_string(err))
        main(address, transaction_pool)
    end
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

  defp distribute_block(block) do
    Enum.each(Peer.connected_handlers(), &send(&1, {"BLOCK", block}))
  end

  defp await_peer_connection do
    case :pg2.which_groups() do
      [] -> await_peer_connection()
      [:p2p_handlers] ->
        if length(Peer.connected_handlers()) == 0 do
          await_peer_connection()
        end
    end
  end

  @spec evaluate_new_block(Block) :: none
  defp evaluate_new_block(block) do
    last_block = Ledger.last_block()

    difficulty =
      if rem(block.index, Blockchain.diff_rebalance_offset()) == 0 do
        new_difficulty = Blockchain.recalculate_difficulty() + last_block.difficulty
        IO.puts("Difficulty recalculated! Changed from #{last_block.difficulty} to #{new_difficulty}")
        new_difficulty
      else
        last_block.difficulty
      end

    case Validator.is_block_valid?(block, difficulty) do
      :ok ->
        Logger.info("Block #{block.index} valid.")
        Blockchain.add_block(block)
        Peer.gossip("BLOCK", block)
      err -> Logger.info("Block #{block.index} invalid!")
    end
  end

  @spec handle_possible_fork(Block, Block) :: none
  defp handle_possible_fork(block, existing_block) do
    Logger.info("Already have block with index #{existing_block.index}. Performing block diff...")

    case Block.diff_header(existing_block, block) do
      # If there is no diff, just skip the block
      [] -> :no_diff
      diff ->
        Logger.warn("Fork block received! Checking existing orphan pool...")

        # Is this a fork of the most recent block? If it is, we don't have an orphan
        # chain to build on...
        if Ledger.last_block().index == block.index do
          # TODO: validate orphan block in context of its chain state before adding it
          Logger.warn("Received fork of current block")
          Orphan.add(block)
        else
          # Check the orphan pool for blocks at the previous height whose hash this
          # orphan block references as a previous_hash
          case Orphan.blocks_at_height(block.index - 1) do
            [] ->
              # We don't know of any ORPHAN blocks that this block might be referencing.
              # Perhaps this is a fork of a block that we've accepted as canonical into our
              # chain?
              case Ledger.retrieve_block(block.previous_hash) do
                :not_found ->
                  # If this block doesn't reference and blocks that we know of, we can not
                  # build a chain using this block -- we can't validate this block at all.
                  # Our only option is to drop the block. Realistically we shouldn't ever
                  # get into this situation unless a malicious actor has sent us a fake block.
                  Logger.warn("Received orphan block with no reference to a known block. Dropping orphan")
                canonical_block ->
                  # This block is a fork of a canonical block.
                  # TODO: Validate this fork in context of the chain state at this point in time
                  Logger.warn("Fork of canonical block received")
                  Orphan.add(block)
              end
            orphan_blocks ->
              # This block might be a fork of a block that we have stored in our
              # orphan pool
              Logger.warn("Possibly extension of existing fork")
          end
        end
    end
  end
end
