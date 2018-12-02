defmodule Command.Usage do

  def run do
    IO.puts "
USAGE
  elixium_miner <command> --option=value

COMMANDS
  foreground          Runs miner with console output in the foreground
  start               Runs miner in background
  stop                Stops miner started by calling start
  remote_console      Opens a remote console in the context of a running miner

OPTIONS
  --address           Specifies which Elixium address to credit with rewards and block fees
  --port              What port to use when connecting to the network (defaults to 31013)
  --rpc               Enable set to strue to enable RPC JSON commands
  --rpcPort           Use specific port for RPC (defaults to 32123)
  --healthCheckPort   Specify which port to use for health check pings (defaults to 31014)
    "
  end

end
