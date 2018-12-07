defmodule Command.Usage do

  def run do
    IO.puts "
USAGE
  elixium_miner <command>

COMMANDS
  foreground          Runs miner with console output in the foreground
  start               Runs miner in background
  stop                Stops miner started by calling start
  remote_console      Opens a remote console in the context of a running miner
  dropchain           Delete all block and utxo data
  genkey              Generate a new Elixium address keypair
    "
  end

end
