defmodule Command.DropChain do
  def run do
    sure? =
      "\nAre you sure? \e[31mThis can not be undone.\e[0m [Ny] "
      |> IO.gets()
      |> String.trim()

    if sure? == "Y" || sure? == "y" || sure? == "yes" do
      IO.puts("Deleting all chain data...")

      Exleveldb.destroy(".chaindata")
      Exleveldb.destroy(".utxo")

      IO.puts "Done."

    else
      IO.puts "Not dropping chain."
    end

    IO.puts ""
  end
end
