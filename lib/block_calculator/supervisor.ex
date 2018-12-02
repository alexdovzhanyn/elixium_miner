defmodule Miner.BlockCalculator.Supervisor do
  use Supervisor
  require Logger
  alias Miner.BlockCalculator

  def start_link(_args) do
    address = Util.get_arg(:address)

    Supervisor.start_link(__MODULE__, address, name: __MODULE__)
  end

  def init(address) do
    children = [
      {BlockCalculator, address}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def get_miner_address do
    "--address=" <> address =
      :init.get_plain_arguments()
      |> Enum.find(& String.starts_with?(List.to_string(&1), "--address="))
      |> List.to_string()

    address
  end

end
