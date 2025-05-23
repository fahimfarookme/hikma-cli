#!/bin/zsh

# script/uninstall.zsh
# Uninstalls hikma-cli from the system.

set -e # Exit on errors

# Determine project root and script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source common environment variables
if [[ ! -f "${SRC_PROJECT_ROOT}/script/common_env.zsh" ]]; then
    echo "Error: ${SRC_PROJECT_ROOT}/script/common_env.sh not found. Installation cannot proceed." >&2
    exit 1   
fi

# shellcheck source=./common_env.sh
source "${SRC_PROJECT_ROOT}/script/common_env.zsh"

remove_hikmarc() {
    if [[ ! -f "$HIKMA_RC_FILE" ]]; then
        echo "${YELLOW}Hikma rc file ${HIKMA_RC_FILE} not found. Skipping removal.${RESET}"
        return 0
    fi

    echo "Removing hikma environment file: ${HIKMA_RC_FILE}..."
    if ! (rm -f "$HIKMA_RC_FILE"); then
        echo "${RED}Failed removing ${HIKMA_CONFIG_DIR}.${RESET}"
        return 1
    fi

    if [[ -d "$HIKMA_CONFIG_DIR" ]] && [ -z "$(ls -A "$HIKMA_CONFIG_DIR")" ]; then
        echo "Removing empty hikma config directory: ${HIKMA_CONFIG_DIR}..."
        rmdir "$HIKMA_CONFIG_DIR" || echo "${YELLOW}Could not remove ${HIKMA_CONFIG_DIR}.${RESET}"
    fi

    if [[ $? -ne 0 ]]; then
        echo "${RED}Failed removing hikma config directory: ${HIKMA_CONFIG_DIR}.${RESET}"
        return 1
    fi
}

# Function for removing given line
remove_line_from_file_if_exists() {
    local line_content="$1"
    local file_path="$2"
    local comment_header="${COMMENT_HEADER}"

    if [[ -z "$line_content" || -z "$file_path" ]]; then
        echo "${RED}Line content and file path are required${RESET}"
        return 1
    fi

    if [[ ! -f "$file_path" ]]; then
        echo "${YELLOW}File ${file_path} not found.${RESET}"
        return 0
    fi

    if ! grep -qF -- "$line_content" "$file_path"; then
        echo "${YELLOW}Line does not exist in $file_path: ${RESET}$"
        return 0
    fi
    
    if [[ ! -w "$file_path" ]]; then
        echo "${RED}Cannot write to ${file_path}. Check permissions.${RESET}"
        return 1
    fi

    if grep -vF -- "$line_content" "$file_path" | grep -vF -- "$comment_header" > "$file_path.tmp"; then
        mv "$file_path.tmp" "$file_path"
        echo "Removed line from $file_path: ${GREEN}${RESET}"
        return 0
    else
        echo "${RED}Failed to remove line from $file_path${RESET}"
        rm -f "$file_path.tmp"
        return 1
    fi
}

# Pre-flight checks
echo "${YELLOW}Starting uninstallation pre-flight checks...${RESET}"
CURRENT_USER_ID=$(id -u)
SUDO_CMD=""
if [[ "$CURRENT_USER_ID" -ne 0 ]] && [[ "$PREFIX" == "/usr/"* ]]; then
    SUDO_CMD="sudo"
fi
echo "${GREEN}Uninstallation pre-flight checks complete.${RESET}"

# --- Uninstallation Process ---
echo "${GREEN}Uninstalling ${PROJECT_NAME} from ${PREFIX}...${RESET}"
echo -n "Are you sure you want to continue? (y/N): "
read -r confirmation
if [[ "$confirmation" != "y" ]] && [[ "$confirmation" != "Y" ]]; then
    echo "${RED}Uninstallation aborted by user.${RESET}"; exit 1;
fi

if [[ -f "$WRAPPER_SCRIPT_PATH" ]]; then
    echo "Removing main executable: ${WRAPPER_SCRIPT_PATH}..."
    $SUDO_CMD rm -f "$WRAPPER_SCRIPT_PATH"
fi

if [[ -d "$TARGET_LIBEXEC_DIR" ]]; then
    echo "Removing core application directory: ${TARGET_LIBEXEC_DIR}..."
    $SUDO_CMD rm -rf "$TARGET_LIBEXEC_DIR"
fi

if [[ -d "$TARGET_SHARE_DOC_DIR" ]]; then
    echo "Removing shared documentation directory: ${TARGET_SHARE_DOC_DIR}..."
    $SUDO_CMD rm -rf "$TARGET_SHARE_DOC_DIR"
fi

# Remove man pages from multiple sections
declare -a man_sections_to_check=("man1" "man5" "man7" "man8") 
MAN_PAGE_REMOVED_FLAG=0
for section in "${man_sections_to_check[@]}"; do
    # e.g. /usr/local/share/man/man1/hikma.1
    local man_page_actual_file="${TARGET_MAN_DIR}/${section}/${MAIN_EXECUTABLE_NAME}.${section#man}"

    if [[ -f "$man_page_actual_file" ]]; then
        echo "Removing man page: ${man_page_actual_file}..."
        $SUDO_CMD rm -f "$man_page_actual_file"
        MAN_PAGE_REMOVED_FLAG=1
    fi
done
if [[ "$MAN_PAGE_REMOVED_FLAG" -eq 1 ]]; then
    echo "${GREEN}Man page(s) removed. You might need to run '${SUDO_CMD} mandb' or '${SUDO_CMD} makewhatis'.${RESET}"
fi

if [[ -f "$ZSH_COMPLETION_FILE_PATH" ]]; then
    echo "Removing zsh completion script: ${ZSH_COMPLETION_FILE_PATH}..."
    $SUDO_CMD rm -f "$ZSH_COMPLETION_FILE_PATH"
fi

# Revert shell configuration files ---
remove_hikmarc

if [[ $? -eq 0 ]]; then
    CONFIG_REVERTED_FLAG=0
    if [[ ${#SHELL_RC_FILES[@]} -gt 0 ]]; then
        for rc_file in "${SHELL_RC_FILES[@]}"; do
            remove_line_from_file_if_exists "${SOURCE_HIKMARC_LINE}" "${rc_file}"
            if [[ $? -eq 1 ]]; then CONFIG_REVERTED_FLAG=1; fi
        done
    fi
fi

echo ""
echo "${GREEN}${PROJECT_NAME} uninstallation complete!${RESET}"
echo "--------------------------------------------------"
if [[ "$CONFIG_REVERTED_FLAG" -eq 0 ]]; then
    echo "- ${YELLOW}Shell configuration entries for ${PROJECT_NAME} have been removed.${RESET}"
    echo "- ${YELLOW}Please restart your shell or run 'source ~/.zshrc' to apply the changes.${RESET}"
else
    echo "- ${YELLOW}No matching shell configuration entries for ${PROJECT_NAME} were found.${RESET}"
    echo "- ${YELLOW}You may manually review your shell config files (e.g. ~/.zshrc, ~/.bashrc).${RESET}"
fi
echo "--------------------------------------------------"

exit 0
