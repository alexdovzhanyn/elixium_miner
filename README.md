# Elixium Miner
Official miner implementation for the Elixium blockchain

### How to Run

Grab the appropriate release from the [releases](https://github.com/ElixiumNetwork/elixium_miner/releases)
section and unzip it. If you don't see a release fitting your system, you will
have to build from source.

After downloading and unzipping the correct release, open a command line window,
and navigate to the directory where you unzipped the release. You'll need an
Elixium address in order to specify where to credit block rewards. If you already
have one, skip ahead to the next section. In order to generate a key, run

```bash
./bin/elixium_miner genkey
```

which will give you output that looks like:

```bash
    Generated Address: EX05YqbW4otW2stMc8HzE3DkrBEJodAFGAtmYfzBsWRWJsYRrrHCt
    Private Key: BC4F8A54697CC24B7718837D51B4C9A37FE7BBEA0A7C451670C1FBDFA4C6B236

    IMPORTANT: Never share or lose your private key. Losing
    the key means losing access to all funds associated with the key.
```

The next step is to [port forward](https://www.pcworld.com/article/244314/how_to_forward_ports_on_your_router.html)
ports 31013, 31014, and 32123 on your router. If you don't do this, other 
nodes on the network won't be able to connect to yours.

Once you have your address and have the correct ports forwarded, you can run 
the miner by running the following (replace the address with your own):

```bash
./bin/elixium_miner foreground --address=EX05YqbW4otW2stMc8HzE3DkrBEJodAFGAtmYfzBsWRWJsYRrrHCt
```

### Running in dev mode

1. Run `mix deps.get`
2. Update `config/config.exs` with a wallet address that you own
3. Run `mix run --no-halt`

![Miner Gif](https://s3-us-west-2.amazonaws.com/elixium-assets/Untitled+(1).gif)
