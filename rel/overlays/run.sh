#!/bin/bash
resize -s 50 150
stty rows 50
stty cols 150

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"

$SCRIPT_DIR/bin/elixium_miner foreground --address=EX054sbR7BtpfuwpyFvDwWd27ffUhwrRvSeQHgW27cbDz5YyUM2Ue
