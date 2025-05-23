#!/bin/zsh

# Creates a temporary workspace directory under the test/tmp/ folder.
# Sets and exports $HIKMA_WORKSPACE.
#
# Output:
#   Echoes the created directory path.
#
# Usage:
#   ws_path=$(setup_workspace)
setup_workspace() {
  local tmp_root
  tmp_root="$(dirname "$BATS_TEST_FILENAME")/tmp"

  mkdir -p "$tmp_root"

  local test_workspace
  test_workspace="$(mktemp -d "${tmp_root}/hikma_test_ws_XXXXXX")"

  export HIKMA_WORKSPACE="$test_workspace"

  echo "$test_workspace"
}

# Deletes the test workspace directory safely and unsets $HIKMA_WORKSPACE.
#
# Arguments:
#   $1 - Path to the workspace directory to delete.
#
# Usage:
#   cleanup_workspace "$HIKMA_WORKSPACE"
cleanup_workspace() {
  local ws_path="$1"

  if [ ! -d "$ws_path" ]; then
    echo "Error: Test workspace does not exist: $ws_path" >&2
    return 1
  fi

  if [[ "$ws_path" != *"hikma_test_ws"* ]]; then
    echo "Refusing to delete non-test workspace: $ws_path" >&2
    return 1
  fi

  rm -rf "$ws_path"
  unset HIKMA_WORKSPACE
}

# Description:
#   Setup addional variables
#
# Usage:
#   setup_variables
setup_variables() {
  export ORIGINAL_PATH="$PATH"
  local project_root="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../" && pwd)"
  export PATH="${project_root}/bin:$PATH"
}

# Description:
#   Restores original $PATH and unsets test-related environment variables.
#
# Usage:
#   unset_variables
unset_variables() {
  if [ -n "$ORIGINAL_PATH" ]; then
    export PATH="$ORIGINAL_PATH"
    unset ORIGINAL_PATH
  fi
}

# Description:
#   Composite function to setup workspace and environment.
#
# Usage (in BATS):
#   setup() {
#     setup_integration_test
#   }
setup_integration_test() {
  setup_workspace
  setup_variables
}

# Description:
#   Composite function to cleanup workspace and environment.
#
# Usage (in BATS):
#   teardown() {
#     teardown_integration_test
#   }
teardown_integration_test() {
  if [ -n "$HIKMA_WORKSPACE" ]; then
    cleanup_workspace "$HIKMA_WORKSPACE"
  fi
  unset_variables
}
