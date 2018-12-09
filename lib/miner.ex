defmodule Miner do
  use Application

  def start(_type, _args) do
    print_ascii_header()
    Elixium.Store.Ledger.initialize()
    
    if !Elixium.Store.Ledger.empty?() do
      Elixium.Store.Ledger.hydrate()
    end

    Elixium.Store.Utxo.initialize()
    Elixium.Store.Oracle.start_link(Elixium.Store.Utxo)
    Elixium.Pool.Orphan.initialize()
    Miner.Supervisor.start_link()
  end

  def print_ascii_header do
    IO.puts "\e[34m
    EEEEEEEEEEEEEEEEEEEEEElllllll   iiii                        iiii
    E::::::::::::::::::::El:::::l  i::::i                      i::::i
    E::::::::::::::::::::El:::::l   iiii                        iiii
    EE::::::EEEEEEEEE::::El:::::l
      E:::::E       EEEEEE l::::l iiiiiii xxxxxxx      xxxxxxxiiiiiii uuuuuu    uuuuuu     mmmmmmm    mmmmmmm
      E:::::E              l::::l i:::::i  x:::::x    x:::::x i:::::i u::::u    u::::u   mm:::::::m  m:::::::mm
      E::::::EEEEEEEEEE    l::::l  i::::i   x:::::x  x:::::x   i::::i u::::u    u::::u  m::::::::::mm::::::::::m
      E:::::::::::::::E    l::::l  i::::i    x:::::xx:::::x    i::::i u::::u    u::::u  m::::::::::::::::::::::m
      E:::::::::::::::E    l::::l  i::::i     x::::::::::x     i::::i u::::u    u::::u  m:::::mmm::::::mmm:::::m
      E::::::EEEEEEEEEE    l::::l  i::::i      x::::::::x      i::::i u::::u    u::::u  m::::m   m::::m   m::::m
      E:::::E              l::::l  i::::i      x::::::::x      i::::i u::::u    u::::u  m::::m   m::::m   m::::m
      E:::::E       EEEEEE l::::l  i::::i     x::::::::::x     i::::i u:::::uuuu:::::u  m::::m   m::::m   m::::m
    EE::::::EEEEEEEE:::::El::::::li::::::i   x:::::xx:::::x   i::::::iu:::::::::::::::uum::::m   m::::m   m::::m
    E::::::::::::::::::::El::::::li::::::i  x:::::x  x:::::x  i::::::i u:::::::::::::::um::::m   m::::m   m::::m
    E::::::::::::::::::::El::::::li::::::i x:::::x    x:::::x i::::::i  uu::::::::uu:::um::::m   m::::m   m::::m
    EEEEEEEEEEEEEEEEEEEEEElllllllliiiiiiiixxxxxxx      xxxxxxxiiiiiiii    uuuuuuuu  uuuummmmmm   mmmmmm   mmmmmm
    \e[32m
    Elixium Core Version #{Application.spec(:elixium_core, :vsn)}       Miner version #{Application.spec(:elixium_miner, :vsn)}
    \e[0m
    \n
    "

  end

end
