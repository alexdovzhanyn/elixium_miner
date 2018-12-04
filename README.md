# Elixium Miner
Official miner implementation for the Elixium blockchain

### How to Run

Grab the appropriate [latest release](https://github.com/ElixiumNetwork/elixium_miner/releases/latest)
and unzip it. If you don't see a release fitting your system, you will
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

Once you have your address and have the correct ports forwarded, open the run.sh file
with a text editor, and replace the address in the file with your own:

```bash
$SCRIPT_DIR/bin/elixium_miner foreground --address EX05YqbW4otW2stMc8HzE3DkrBEJodAFGAtmYfzBsWRWJsYRrrHCt
```

Next, double-click the run.sh file to run it.

#### Advanced Usage

People who are comfortable working within a terminal may prefer to create their own
run script. To see usage options, cd into the directory where the miner is extracted,
and run `./bin/elixium_miner usage`.

### Building from Source

If none of the release candidates match your system architecture, it will be
necessary to build from source. It is important to have elixir installed on your
machine, this can be done by following the [installation instructions](https://elixir-lang.org/install.html).

In order to build from source:

1. Clone this repository
2. Run `mix deps.get`
3. Run `MIX_ENV=prod mix release`

Upon successful build, a tarball containing the compiled build can be found
in `_build/prod/rel/elixium_miner/releases/<version_number>/elixium_miner.tar.gz`

![Miner Gif](https://s3-us-west-2.amazonaws.com/elixium-assets/Untitled+(1).gif)
