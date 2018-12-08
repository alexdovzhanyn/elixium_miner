#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"

$SCRIPT_DIR/bin/elixium_miner foreground
