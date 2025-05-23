#!/bin/zsh

# script/common_env.sh
# Defines common variables and paths for hikma-cli install/uninstall scripts.

# Assumes SRC_PROJECT_ROOT is already defined in the sourcing script.
if [[ -z "$SRC_PROJECT_ROOT" ]]; then
    echo "Error: SRC_PROJECT_ROOT is not defined before sourcing common_env.sh. Exiting." >&2
    exit 1
fi

# Project
PROJECT_NAME="hikma-cli"
MAIN_EXECUTABLE_NAME="hikma"

# Source directories in project structure
SRC_BIN_DIR="${SRC_PROJECT_ROOT}/bin"
SRC_LIB_DIR="${SRC_PROJECT_ROOT}/lib"
SRC_TEMPLATES_DIR="${SRC_PROJECT_ROOT}/template"
SRC_COMPLETION_DIR="${SRC_PROJECT_ROOT}/completion"
SRC_MAN_DIR="${SRC_PROJECT_ROOT}/man"
SRC_DOC_DIR="${SRC_PROJECT_ROOT}/doc"
SRC_SCRIPTS_DIR="${SRC_PROJECT_ROOT}/script"

# Target installation directories and files
DEFAULT_PREFIX="/usr/local"
PREFIX="${HIKMA_INSTALL_PREFIX:-${1:-$DEFAULT_PREFIX}}"
TARGET_BIN_DIR="${PREFIX}/bin"
TARGET_LIBEXEC_DIR="${PREFIX}/libexec/${PROJECT_NAME}"
TARGET_LIBEXEC_BIN_DIR="${TARGET_LIBEXEC_DIR}/bin"
TARGET_LIBEXEC_LIB_DIR="${TARGET_LIBEXEC_DIR}/lib"
TARGET_LIBEXEC_TEMPLATE_DIR="${TARGET_LIBEXEC_DIR}/template"
TARGET_SHARE_DOC_DIR="${PREFIX}/share/doc/${PROJECT_NAME}"
TARGET_MAN_DIR="${PREFIX}/share/man"
TARGET_ZSH_COMPLETION_DIR="${PREFIX}/share/zsh/site-functions"
ZSH_COMPLETION_FILE_PATH="${TARGET_ZSH_COMPLETION_DIR}/_hikma"
WRAPPER_SCRIPT_PATH="${TARGET_BIN_DIR}/${MAIN_EXECUTABLE_NAME}"

# Load Colors
if [[ -f "${SRC_SCRIPTS_DIR}/colors.zsh" ]]; then
    # shellcheck source=./colors.sh
    source "${SRC_SCRIPTS_DIR}/colors.zsh"
else
    echo "Warning: ${SRC_SCRIPTS_DIR}/colors.zsh not found. Proceeding without special colors." >&2
    GREEN=""
    YELLOW=""
    RED=""
    RESET=""
fi

# hikmarc file details
HIKMA_CONFIG_DIR="$HOME/.config/hikma"
HIKMA_RC_FILE="${HIKMA_CONFIG_DIR}/rc.zsh"

# Shell rc files where hikmarc is sourced
declare -a SHELL_RC_FILES=()
if [[ -f "$HOME/.bashrc" ]]; then SHELL_RC_FILES+=("$HOME/.bashrc"); fi
if [[ -f "$HOME/.zshrc" ]]; then SHELL_RC_FILES+=("$HOME/.zshrc"); fi

# Content for the hikmarc file
HIKMARC_PATH_EXPORT="export PATH=\"${TARGET_BIN_DIR}:\$PATH\""
HIKMARC_FPATH_ADD="fpath=(${TARGET_ZSH_COMPLETION_DIR} \$fpath)"
HIKMARC_COMPINIT_1="autoload -Uz compinit"
HIKMARC_COMPINIT_2="compinit"
COMMENT_HEADER="# Added by ${PROJECT_NAME} installer"

# Line to source hikmarc in user's shell rc
SOURCE_HIKMARC_LINE="[ -f \"${HIKMA_RC_FILE}\" ] && source \"${HIKMA_RC_FILE}\""
