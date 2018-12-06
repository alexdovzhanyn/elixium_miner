defmodule Miner.RPC do
  use GenServer
  require IEx
  require Logger

  def start_link(_args) do
    port =
      :rpcPort
      |> Elixium.Utilities.get_arg("32123")
      |> String.to_integer()

    {:ok, socket} = :gen_tcp.listen(port, packet: :http, active: true, exit_on_close: false)
    GenServer.start_link(__MODULE__, socket, name: __MODULE__)
  end

  def init(socket) do
    Process.send_after(self(), :start_accept, 1000)

    {:ok, %{listen: socket}}
  end

  def start_accept do
    GenServer.cast(__MODULE__, :start_accept)
  end

  def handle_info(:start_accept, state) do
    Logger.info("RPC listening")

    {:ok, socket} = :gen_tcp.accept(state.listen)

    state = Map.put(state, :socket, socket)
    {:noreply, state}
  end

  def handle_info({:http, socket, {:http_request, :GET, {:abs_path, path}, _}}, state) do
    data = Miner.RPC.Router.get(to_string(path))

    :gen_tcp.send(socket, "HTTP/1.1 200 OK\nAccess-Control-Allow-Origin: *\nContent-Length: #{byte_size(data)}\nContent-Type: application/json\n\n#{data}\n")

    {:noreply, state}
  end

  def handle_info({:tcp_closed, _}, state) do
    {:ok, socket} = :gen_tcp.accept(state.listen)

    state = Map.put(state, :socket, socket)
    {:noreply, state}
  end

  def handle_info(_any, state), do: {:noreply, state}
end
