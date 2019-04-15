defmodule Miner.RPC.Router do
  alias Elixium.Store.Ledger

  def get("/") do
    "ROOT ROUTE"
  end

  def get("/block_at_height/" <> index) do
    try do
      block =
        index
        |> String.to_integer()
        |> Ledger.block_at_height()
        |> nonbinary_block()

      case block do
        :none -> "Block #{block} not found."
        block -> Poison.encode!(block)
      end

    rescue
      ArgumentError -> "Please provide an integer block index."
    end
  end

  def get("/block_by_hash/" <> hash) do
    case Ledger.retrieve_block(hash) do
      :none -> "Not found"
      block ->
        block
        |> nonbinary_block()
        |> Poison.encode!()
    end
  end

  def get("/latest_block") do
    Ledger.last_block()
    |> nonbinary_block()
    |> Poison.encode!()
  end

  def get("/last_n_blocks/" <> count) do
    try do
      count
      |> String.to_integer()
      |> Ledger.last_n_blocks()
      |> Enum.map(&nonbinary_block/1)
      |> Poison.encode!()
    rescue
      ArgumentError -> "Please provide an integer"
    end
  end

  def get("/connected_nodes") do
    Pico.Client.SharedState.connections()
    |> Enum.map(fn {_, ip} -> ip end)
    |> Poison.encode!()
  end

  def get(_), do: "404"

  @doc """
    Converts binary data within a block to its non-binary equivalent
  """
  def nonbinary_block(block) do
    b = %{
      block |
      nonce: :binary.decode_unsigned(block.nonce),
      version: :binary.decode_unsigned(block.version),
      index: :binary.decode_unsigned(block.index)
    }

    transactions = Enum.map(block.transactions, fn tx ->
      tx =
        if Map.has_key?(tx, :sigs) do
          sigs = Enum.map(tx.sigs, fn {addr, sig} -> [addr, Base.encode64(sig)] end)

          Map.put(tx, :sigs, sigs)
        else
          tx
        end

      Map.put(tx, :size, tx |> :erlang.term_to_binary |> byte_size)
    end)

    b = Map.put(b, :transactions, transactions)

    b = Map.put(b, :size, Elixium.BlockEncoder.encode(block) |> byte_size)

    Map.put(b, :reward, Elixium.Block.calculate_block_reward(b.index))
  end

end
