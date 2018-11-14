defmodule Miner.LedgerManager do
  alias Elixium.Store.Ledger
  alias Elixium.Validator
  alias Elixium.Blockchain
  alias Elixium.Block
  alias Elixium.Pool.Orphan
  alias Elixium.Store.Utxo
  require Logger

  @moduledoc """
    Handles high level decision logic for forking, saving, and relaying blocks.
  """

  @doc """
    Decide what to do when we've received a new block. All block persistence
    logic is handled internally; this returns an atom describing what the peer
    handler should do with this block.
  """
  @spec handle_new_block(Block) :: :ok | :gossip | :ignore | :invalid | {:missing_blocks, list}
  def handle_new_block(block) do
    # Check if we've already received a block at this index. If we have,
    # diff it against the one we've stored. If we haven't, check to see
    # if this index is the next index in the chain. In the case that its
    # not, we've likely found a new longest chain, so we need to evaluate
    # whether or not we want to switch to that chain
    case Ledger.block_at_height(block.index) do
      :none ->
        last_block = Ledger.last_block()

        # Will only match if the block we received is building directly
        # on the block that we have as the last block in our chain
        if block.index == last_block.index + 1 && block.previous_hash == last_block.hash do
          # If this block is positioned as the next block in the chain,
          # validate it as such
          validate_new_block(last_block, block)
        else
          # Otherwise, check if it's a fork and whether we need to swap to
          # a fork chain
          evaluate_chain_swap(block)
        end

      stored_block -> handle_possible_fork(block, stored_block)
    end
  end

  # Checks whether a block is valid as the next block in the chain. If it is,
  # adds the block to the chain.
  @spec validate_new_block(Block, Block) :: :ok | :invalid
  defp validate_new_block(last_block, block) do
    # Recalculate target difficulty if necessary
    difficulty =
      if rem(block.index, Application.get_env(:elixium_core, :diff_rebalance_offset)) == 0 do
        new_difficulty = Blockchain.recalculate_difficulty() + last_block.difficulty
        IO.puts("Difficulty recalculated! Changed from #{last_block.difficulty} to #{new_difficulty}")
        new_difficulty
      else
        last_block.difficulty
      end

    case Validator.is_block_valid?(block, difficulty) do
      :ok ->
        # Save the block to our chain since its valid
        Ledger.append_block(block)
        Utxo.update_with_transactions(block.transactions)
        :ok
      _err -> :invalid
    end
  end

  # Checks whether a given block is a valid fork of an existing block. Doesn't
  # modify the chain, only updates the orphan block pool and decides whether
  # the peer should gossip about this block.
  @spec handle_possible_fork(Block, Block) :: :gossip | :ignore
  defp handle_possible_fork(block, existing_block) do
    Logger.info("Already have a block with index #{existing_block.index}. Performing block diff...")

    case Block.diff_header(existing_block, block) do
      [] ->
        # There is no difference between these blocks. We'll ignore this newly
        # recieved block.
        Logger.info("Same block")
        :ignore
      _diff ->
        Logger.warn("Fork block received! Checking existing orphan pool...")

        # TODO: Should this look at previous_hash as well?
        if Ledger.last_block().index == block.index do
          # This block is a fork of the current latest block in the pool. Add it
          # to our orphan pool and tell the peer to gossip the block.
          Logger.warn("Received fork of current block.")
          Orphan.add(block)
          :gossip
        else
          # Check the orphan pool for blocks at the previous height whose hash this
          # orphan block references as a previous_hash
          check_orphan_pool_for_ancestors(block)
        end
    end
  end

  # Checks the orphan pool for blocks with a common previous index or previous_hash
  @spec check_orphan_pool_for_ancestors(Block) :: :gossip | :ignore
  defp check_orphan_pool_for_ancestors(block) do
    case Orphan.blocks_at_height(block.index - 1) do
      [] ->
        # We don't know of any ORPHAN blocks that this block might be referencing.
        # Perhaps this is a fork of a block that we've accepted as canonical
        # into our chain?
        case Ledger.retrieve_block(block.previous_hash) do
          :not_found ->
            # If this block doesn't reference and blocks that we know of, we can not
            # build a chain using this block -- we can't validate this block at all.
            # Our only option is to drop the block. Realistically we shouldn't ever
            # get into this situation unless a malicious actor has sent us a fake block.
            Logger.warn("Received orphan block with no reference to a known block. Dropping orphan")
            :ignore
          _canonical_block ->
            # This block is a fork of a canonical block.
            Logger.warn("Fork of canonical block received")
            Orphan.add(block)
            :gossip
        end

      _orphan_blocks ->
        # This block might be a fork of a block that we have stored in our
        # orphan pool.

        # TODO: Expand this logic. Right now we're adding this block to the
        # orphan pool irrespective of whether or not it has an ancestor in the
        # pool. We should check before we add.
        Logger.warn("Possibly extension of existing fork")
        Orphan.add(block)
        :gossip
    end
  end

  # Try to rebuild a fork chain based on this block and it's ancestors in the
  # orphan pool. If we're successful, validate and try to swap to the new chain.
  # Otherwise, just ignore this block.
  @spec evaluate_chain_swap(Block) :: :ok | :ignore | {:missing_blocks, list}
  defp evaluate_chain_swap(block) do
    # Rebuild the chain backwards until reaching a point where we agree on the
    # same blocks as the fork does.
    case rebuild_fork_chain(block) do
      {:missing_blocks, fork_chain} ->
        # We don't have anything that this block can reference as a previous
        # block, let's save the block as an orphan and see if we can request
        # some more blocks.
        Orphan.add(block)
        {:missing_blocks, fork_chain}
      {fork_chain, fork_source} ->
        # Calculate the difficulty that we were looking for at the time of the
        # fork. First, we need to find the start of the last epoch
        start_of_last_epoch = fork_source.index - rem(fork_source.index, Application.get_env(:elixium_core, :diff_rebalance_offset))

        difficulty =
          if start_of_last_epoch >= Application.get_env(:elixium_core, :diff_rebalance_offset) do
            end_of_prev_epoch = Ledger.block_at_height(start_of_last_epoch)
            beginning_of_prev_epoch = Ledger.block_at_height(start_of_last_epoch - Application.get_env(:elixium_core, :diff_rebalance_offset))
            Blockchain.recalculate_difficulty(beginning_of_prev_epoch, end_of_prev_epoch)
          else
            fork_source.difficulty
          end

          current_utxos_in_pool = Utxo.retrieve_all_utxos()

          # Blocks which need to be reversed. (Everything from the block after
          # the fork source to the current block)
          blocks_to_reverse =
            fork_source.index + 1
            |> Range.new(Ledger.last_block().index)
            |> Enum.map(&Ledger.block_at_height/1)

          # Find transaction inputs that need to be reversed
          # TODO: We're looping over blocks_to_reverse twice here (once to parse
          # inputs and once for outputs). We can likely do this in the same loop.
          all_canonical_transaction_inputs_since_fork =
            Enum.flat_map(blocks_to_reverse, &parse_transaction_inputs/1)

          canon_output_txoids =
            blocks_to_reverse
            |> Enum.flat_map(&parse_transaction_outputs/1)
            |> Enum.map(& &1.txoid)

          # Pool at the time of fork is basically just current pool plus all inputs
          # used in canon chain since fork, minus all outputs created in after fork
          # (this will also remove inputs that were created as outputs and used in
          # the fork)
          pool =
            current_utxos_in_pool ++ all_canonical_transaction_inputs_since_fork
            |> Enum.filter(&(!Enum.member?(canon_output_txoids, &1.txoid)))

          # Traverse the fork chain, making sure each block is valid within its own
          # context.
          {_, final_contextual_pool, _difficulty, _fork_chain, validation_results} =
            fork_chain
            |> Enum.scan({fork_source, pool, difficulty, fork_chain, []}, &validate_in_context/2)
            |> List.last()

          # Ensure that every block passed validation
          if Enum.all?(validation_results, & &1) do
            Logger.info("Candidate fork chain valid. Switching.")

            # Add everything in final_contextual_pool that is not also in current_utxos_in_pool
            Enum.each(final_contextual_pool -- current_utxos_in_pool, &Utxo.add_utxo/1)

            # Remove everything in current_utxos_in_pool that is not also in final_contextual_pool
            current_utxos_in_pool -- final_contextual_pool
            |> Enum.map(& &1.txoid)
            |> Enum.each(&Utxo.remove_utxo/1)

            # Drop canon chain blocks from the ledger, add them to the orphan pool
            # in case the chain gets revived by another miner
            Enum.each(blocks_to_reverse, fn blk ->
              Orphan.add(blk)
              Ledger.drop_block(blk)
            end)

            # Remove fork chain from orphan pool; now it becomes the canon chain,
            # so we add its blocks to the ledger
            Enum.each(fork_chain, fn blk ->
              Ledger.append_block(blk)
              Orphan.remove(blk)
            end)

            :ok
          else
            Logger.info("Evaluated candidate fork chain. Not viable for switch.")
            :ignore
          end

      _ -> :ignore
    end
  end

  # Recursively loops through the orphan pool to build a fork chain as long as
  # we can, based on a given block.
  @spec rebuild_fork_chain(list) :: list | {:missing_blocks, list}
  defp rebuild_fork_chain(chain) when is_list(chain) do
    case Orphan.blocks_at_height(hd(chain).index - 1) do
      [] ->
        Logger.warn("Tried rebuilding fork chain, but was unable to find an ancestor.")
        {:missing_blocks, chain}
      orphan_blocks ->
        orphan_blocks
        |> Enum.filter(fn {_, block} -> block.hash == hd(chain).previous_hash end)
        |> Enum.find_value(fn {_, candidate_orphan} ->
          # Check if we agree on a previous_hash
          case Ledger.retrieve_block(candidate_orphan.previous_hash) do
            # We need to dig deeper...
            :not_found -> rebuild_fork_chain([candidate_orphan | chain])
            # We found the source of this fork. Return the chain we've accumulated
            fork_source -> {[candidate_orphan | chain], fork_source}
          end
        end)
    end
  end

  defp rebuild_fork_chain(block), do: rebuild_fork_chain([block])

  # Return a list of all transaction inputs for every transaction in this block
  @spec parse_transaction_inputs(Block) :: list
  defp parse_transaction_inputs(block) do
    block.transactions
    |> Enum.flat_map(&(&1.inputs))
    |> Enum.map(&(Map.delete(&1, :signature)))
  end

  @spec parse_transaction_outputs(Block) :: list
  defp parse_transaction_outputs(block), do: Enum.flat_map(block.transactions, &(&1.outputs))

  # Validates a given block in the context of the values passed in. This function
  # is primarily meant to be used as an accumulator for Enum.scan. The provided
  # pool will be used as the utxo pool, the provided chain will be used as a
  # faux canonical chain. Results is an array of blocks that have been previously
  # validated using this function.
  @spec validate_in_context(Block, {Block, list, number, list, list}) :: {Block, list, number, list, list}
  defp validate_in_context(block, {last, pool, difficulty, chain, results}) do
    difficulty =
      if rem(block.index, Application.get_env(:elixium_core, :diff_rebalance_offset)) == 0 do
        # Check first to see if the beginning of this epoch was within the fork.
        # If not, get the epoch start block from the canonical chain
        epoch_start =
          case Enum.find(chain, & &1.index == block.index - Application.get_env(:elixium_core, :diff_rebalance_offset)) do
            nil -> Ledger.block_at_height(block.index - Application.get_env(:elixium_core, :diff_rebalance_offset))
            block -> block
          end

        Blockchain.recalculate_difficulty(epoch_start, block) + last.difficulty
      else
        difficulty
      end

    valid = :ok == Validator.is_block_valid?(block, difficulty, last, &(pool_check(pool, &1)))

    # Update the contextual utxo pool by removing spent inputs and adding
    # unspent outputs from this block. The following block will use the updated
    # contextual pool for utxo validation
    updated_pool =
      if valid do
        # Get a list of this blocks inputs (now that we've deemed it valid)
        block_input_txoids =
          block
          |> parse_transaction_inputs()
          |> Enum.map(& &1.txoid)

        # Get a list of the outputs this block produced
        block_outputs = parse_transaction_outputs(block)

        # Remove all the outputs that were both created and used within this same
        # block
        Enum.filter(pool ++ block_outputs, &(!Enum.member?(block_input_txoids, &1.txoid)))
      else
        pool
      end

    {block, updated_pool, difficulty, chain, [valid | results]}
  end

  # Function that gets passed to Validator.is_block_valid?/3, telling it how to
  # evaluate the pool. We're doing this because by default, the validator uses
  # the canonical UTXO pool for validation, but when we're processing a potential
  # fork, we won't have the same exact UTXO pool, so we reconstruct one based on
  # the fork chain. We then use this pool to verify the existence of a particular
  # UTXO in the fork chain.
  @spec pool_check(list, map) :: true | false
  defp pool_check(pool, utxo) do
    case Enum.find(pool, false, & &1.txoid == utxo.txoid) do
      false -> false
      txo_in_pool -> utxo.amount == txo_in_pool.amount && utxo.addr == txo_in_pool.addr
    end
  end

end
