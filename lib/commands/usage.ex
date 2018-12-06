defmodule Command.Usage do

  def run do
    IO.puts "
USAGE
  elixium_miner <command> --option value

COMMANDS
  foreground          Runs miner with console output in the foreground
  start               Runs miner in background
  stop                Stops miner started by calling start
  remote_console      Opens a remote console in the context of a running miner
  dropchain           Delete all block and utxo data
  genkey              Generate a new Elixium address keypair

OPTIONS
  --address           Specifies which Elixium address to credit with rewards and block fees
  --port              What port to use when connecting to the network (defaults to 31013)
  --rpc               Enable RPC JSON commands
  --rpcPort           Use specific port for RPC (defaults to 32123)
  --maxHandlers       Specify the maximum amount of inbound & outbound connections
    "
  end

end
