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

      case block do
        :none -> "Block #{block} not found."
        block -> Poison.encode!(block)
      end

    rescue
      ArgumentError -> "Please provide an integer block index."
    end
  end

  def get("/block_by_hash/" <> hash) do
    hash
    |> Ledger.retrieve_block()
    |> Poison.encode!()
  end

  def get("/latest_block") do
    Ledger.last_block()
    |> Poison.encode!()
  end

  def get("/last_n_blocks/" <> count) do
    try do
      count
      |> String.to_integer()
      |> Ledger.last_n_blocks()
      |> Poison.encode!()
    rescue
      ArgumentError -> "Please provide an integer"
    end
  end

  def get(_), do: "404"

end
