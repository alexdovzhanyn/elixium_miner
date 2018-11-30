defmodule GenKeypair do
  def run do
    {pub, priv} = Elixium.KeyPair.create_keypair()

    address = Elixium.KeyPair.address_from_pubkey(pub)

    base16priv = Base.encode16(priv)

    IO.puts("
      Generated Address: \e[34m#{address}\e[0m
      Private Key: \e[34m#{base16priv}\e[0m

      \e[31m\e[1mIMPORTANT\e[21m: Never share or lose your private key. Losing
      the key means losing access to all funds associated with the key.
      \e[0m\n
    ")
  end
end
