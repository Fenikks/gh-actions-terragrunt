#!/bin/bash

source /usr/local/actions.sh

debug
setup
init

enable_workflow_commands
if ! (cd "$INPUT_PATH" && terraform validate -json | convert_validate_report "$INPUT_PATH" ); then
  disable_workflow_commands
  (cd "$INPUT_PATH" && terraform validate)
else
  disable_workflow_commands
  echo -e "\033[1;32mSuccess!\033[0m The configuration is valid"
fi
