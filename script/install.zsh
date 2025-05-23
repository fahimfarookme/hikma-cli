#!/bin/zsh

# script/install.zsh
# Installs hikma-cli to the system using a wrapper script.
# Attempts to update shell configuration files for PATH and fpath.
#
# The target installation structure would be (assuming prefix=/usr/local)
# /usr/local/
# ├── bin/
# │   └── hikma # Main executable (wrapper script)
# │
# ├── libexec/
# │   └── hikma-cli/ 
# │       ├── bin/
# │       │   └── ...
# │       ├── lib/
# │       │   ├── ...
# │       │   ├── ...
# │       └── templates/
# │           ├── ...
# │           ├── ...
# │
# ├── share/
# │   ├── doc/
# │   │   └── hikma-cli/
# │   │       ├── ...
# │   │       ├── ...
# │   │
# │   ├── man/
# │   │   └── man1/
# │   │       └── hikma.1
# │   │
# │   └── zsh/
# │       └── site-functions/
# │           └── _hikma

set -e # Exit on errors

# Determine project root and script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source common environment variables
if [[ ! -f "${SRC_PROJECT_ROOT}/script/common_env.zsh" ]]; then
    echo "Error: ${SRC_PROJECT_ROOT}/script/common_env.zsh not found. Installation cannot proceed." >&2
    exit 1   
fi

# shellcheck source=./common_env.sh
source "${SRC_PROJECT_ROOT}/script/common_env.zsh"

# Function to create hikmarc
create_hikmarc() {
    # Create the directory for hikmarc if it doesn't exist (e.g., ~/.config/hikma)
    # This should be done as the user, not with sudo, as it's in $HOME

    if [[ -d "${HIKMA_CONFIG_DIR}" ]] && [[ -f "${HIKMA_RC_FILE}" ]]; then
        echo "${YELLOW}${HIKMA_CONFIG_DIR} already exist. Creating backup...${RESET}"
        mv "${HIKMA_CONFIG_DIR}" "${HIKMA_CONFIG_DIR}.back.$(date "+%Y-%m-%d-%H:%M:%S")"
    fi

    mkdir -p "${HIKMA_CONFIG_DIR}"
    if [[  $? -ne 0 ]] || [[ ! -w "${HIKMA_CONFIG_DIR}" ]]; then
        echo "${RED}Cannot create ${HIKMA_CONFIG_DIR}. Please ensure you have permissions.${RESET}"
        return 1;
    fi
    
    cat > "${HIKMA_RC_FILE}" << EOF
# Shell configuration for ${PROJECT_NAME}
${HIKMARC_PATH_EXPORT}

# zsh completions
if [ -n "\$ZSH_VERSION" ]; then
    ${HIKMARC_FPATH_ADD}

    if ! whence compinit >/dev/null 2>&1 && ! (declare -f compinit >/dev/null 2>&1) ; then
        ${HIKMARC_COMPINIT_1}
        ${HIKMARC_COMPINIT_2}
    fi
fi
EOF

    if [[ $? -ne 0 ]]; then
        echo "${RED}Could not create ${HIKMA_RC_FILE}.${RESET}"
        return 1
    fi

    chmod +x "${HIKMA_RC_FILE}"
    return 0
}

# Function to add a line to a file if it doesn't already exist
add_line_to_file_if_not_exists() {
    local line_content="$1" # The actual content of the line to add
    local file_path="$2"
    local comment_header="${COMMENT_HEADER}"

    if [[ -z "$line_content" || -z "$file_path" ]]; then
        echo "${RED}Line content and file path are required${RESET}"
        return 1
    fi

    if [[ ! -f "$file_path" ]]; then
        echo "${RED}Configuration file ${file_path} not found.${RESET}"
        return 1
    fi

    if grep -qF -- "$line_content" "$file_path"; then
        echo "${YELLOW}Line already exists in $file_path.${RESET}$"
        return 0
    fi

    if [[ ! -w "$file_path" ]]; then
        echo "${RED}Cannot write to ${file_path}. Check permissions.${RESET}"
        return 1
    fi

    {
        # Add a newline before our block if the file is not empty and doesn't end with a newline
        if [[ -s "$file_path" ]] && [[ "$(tail -c1 "$file_path"; echo x)" != $'\nx' ]]; then
            echo
        fi
        echo "$comment_header"
        echo "$line_content"
    } >> "$file_path"

    if [[ $? -eq 0 ]]; then
        echo "Updated $file_path."
        return 0
    else
        echo "${RED}Failed to add line to $file_path${RESET}"
        return 1
    fi
}

# Pre-flight checks
echo "${YELLOW}Starting pre-flight checks...${RESET}"
if [[ ! -d "$SRC_BIN_DIR" ]] || [[ ! -f "$SRC_BIN_DIR/hikma.zsh" ]] || [[ ! -f "$SRC_BIN_DIR/command_template.txt" ]]; then
    echo "${RED}Error: Essential source files/directories not found. Ensure script is run from 'script/' dir.${RESET}"
    exit 1
fi

CURRENT_USER_ID=$(id -u)
if [[ "$CURRENT_USER_ID" -eq 0 ]] && [[ "$PREFIX" == "/usr/local" ]]; then
    echo "${YELLOW}Warning: Running as root. Files will be installed system-wide to /usr/local.${RESET}"
fi

# Attempt to create PREFIX, if it does not exist
if [[ ! -d "$PREFIX" ]]; then
    echo "Creating ${YELLOW}${PREFIX}${RESET} prefix..."
    if [[ "$CURRENT_USER_ID" -ne 0 ]] && [[ "$PREFIX" == "/usr/"* ]]; then
        sudo mkdir -p "$PREFIX" || { echo "${RED}Failed to create ${PREFIX} with sudo.${RESET}"; exit 1; }
    else
        mkdir -p "$PREFIX" || { echo "${RED}Failed to create ${PREFIX}.${RESET}"; exit 1; }
    fi
fi

# Check writability of PREFIX
if [[ ! -w "$PREFIX" ]]; then
    echo "${RED}Install directory '${PREFIX}' not writable. Try with sudo.${RESET}"; 
    exit 1;
fi
echo "${GREEN}Pre-flight checks passed.${RESET}"


# Installation process
echo "${GREEN}Installing ${PROJECT_NAME} to ${PREFIX}...${RESET}"
SUDO_CMD=""
if [[ "$CURRENT_USER_ID" -ne 0 ]] && [[ "$PREFIX" == "/usr/"* ]]; then
    SUDO_CMD="sudo"
fi

# 1. Create all target directories
echo "Creating target directories..."
$SUDO_CMD mkdir -p "${TARGET_BIN_DIR}"
$SUDO_CMD mkdir -p "${TARGET_LIBEXEC_BIN_DIR}"
$SUDO_CMD mkdir -p "${TARGET_LIBEXEC_LIB_DIR}"
$SUDO_CMD mkdir -p "${TARGET_LIBEXEC_TEMPLATE_DIR}"
$SUDO_CMD mkdir -p "${TARGET_SHARE_DOC_DIR}"
$SUDO_CMD mkdir -p "${TARGET_ZSH_COMPLETION_DIR}"

# 2. Install core application files to TARGET_LIBEXEC_DIR
echo "Installing core application files to ${TARGET_LIBEXEC_DIR}..."
$SUDO_CMD cp -r "${SRC_BIN_DIR}/." "${TARGET_LIBEXEC_BIN_DIR}/"

# Verify critical files.
if [[ ! -f "${TARGET_LIBEXEC_BIN_DIR}/hikma.zsh" ]] || [[ ! -f "${TARGET_LIBEXEC_BIN_DIR}/command_template.txt" ]]; then
    echo "${RED}Error: hikma.zsh or command_template.txt was not copied to ${TARGET_LIBEXEC_BIN_DIR}. Installation cannot proceed.${RESET}"
    exit 1
fi
$SUDO_CMD chmod +x "${TARGET_LIBEXEC_BIN_DIR}/hikma.zsh"

# Copy library files
if [[ -d "${SRC_LIB_DIR}" ]] && [[ -n "$(ls -A "${SRC_LIB_DIR}")" ]]; then
    $SUDO_CMD cp -r "${SRC_LIB_DIR}/." "${TARGET_LIBEXEC_LIB_DIR}/"
else
    echo "${YELLOW}Warning: Source library directory '${SRC_LIB_DIR}' is empty or not found. Skipping libs.${RESET}"
fi

# Copy templates
if [[ -d "${SRC_TEMPLATES_DIR}" ]] && [[ -n "$(ls -A "${SRC_TEMPLATES_DIR}")" ]]; then
    $SUDO_CMD cp -r "${SRC_TEMPLATES_DIR}/." "${TARGET_LIBEXEC_TEMPLATE_DIR}/"
else
    echo "${YELLOW}Warning: Source templates directory '${SRC_TEMPLATES_DIR}' is empty or not found. Skipping templates.${RESET}"
fi

# 3. Create and install the wrapper script to TARGET_BIN_DIR
echo "Creating wrapper script at ${WRAPPER_SCRIPT_PATH}..."
WRAPPER_CONTENT="#!/bin/zsh
# Wrapper script for ${PROJECT_NAME}
export HIKMA_SCRIPT_ROOT=\"${TARGET_LIBEXEC_DIR}\"
exec \"\${HIKMA_SCRIPT_ROOT}/bin/hikma.zsh\" \"\$@\"
"
# Write wrapper script
echo "$WRAPPER_CONTENT" | $SUDO_CMD tee "${WRAPPER_SCRIPT_PATH}" > /dev/null
$SUDO_CMD chmod +x "${WRAPPER_SCRIPT_PATH}"

# 4. Install documentation (README.md, source .org docs)
echo "Installing documentation to ${TARGET_SHARE_DOC_DIR}..."
# Check for README.md (uppercase is more common)
if [[ -f "${SRC_PROJECT_ROOT}/readme.md" ]]; then
    $SUDO_CMD cp "${SRC_PROJECT_ROOT}/readme.md" "${TARGET_SHARE_DOC_DIR}/"
else
    echo "${YELLOW}Warning: README.md or readme.md not found in project root. Skipping.${RESET}"
fi

if [[ -d "${SRC_DOC_DIR}" ]] && [[ -n "$(ls -A "${SRC_DOC_DIR}")" ]]; then
    $SUDO_CMD cp -r "${SRC_DOC_DIR}/." "${TARGET_SHARE_DOC_DIR}/"
else
    echo "${YELLOW}Warning: Source documentation directory '${SRC_DOC_DIR}' is empty or not found. Skipping source docs.${RESET}"
fi

# 5. Install man pages
if [[ -d "${SRC_MAN_DIR}" ]] && [[ -n "$(ls -A "${SRC_MAN_DIR}" 2>/dev/null)" ]]; then
    echo "Installing man pages..."
    for section_dir in $(find "${SRC_MAN_DIR}" -mindepth 1 -maxdepth 1 -type d); do
        section_name=$(basename "$section_dir") # e.g., man1
        TARGET_MAN_SECTION_DIR="${TARGET_MAN_DIR}/${section_name}"
        
        echo "Creating directory (if needed): ${TARGET_MAN_SECTION_DIR}"
        $SUDO_CMD mkdir -p "${TARGET_MAN_SECTION_DIR}"
        
        echo "Copying man pages from ${section_dir} to ${TARGET_MAN_SECTION_DIR}..."
        if ls "${section_dir}/"* >/dev/null 2>&1; then
             $SUDO_CMD cp -p "${section_dir}/"* "${TARGET_MAN_SECTION_DIR}/"
        else
            echo "${YELLOW}No files found in ${section_dir} to install.${RESET}"
        fi
    done
    echo "Man pages installed. You might need to run '${SUDO_CMD} mandb' or '${SUDO_CMD} makewhatis' to update the man database."
else
    echo "${YELLOW}Warning: Man page source directory '${SRC_MAN_DIR}' is empty or not found. Skipping man page installation.${RESET}"
fi

# 6. Install Shell Completions
if [[ -d "${SRC_COMPLETION_DIR}" ]] && [[ -f "${SRC_COMPLETION_DIR}/_hikma" ]]; then
    echo "Installing zsh completion script to ${TARGET_ZSH_COMPLETION_DIR}..."
    $SUDO_CMD cp "${SRC_COMPLETION_DIR}/_hikma" "${ZSH_COMPLETION_FILE_PATH}"
else
    echo "${YELLOW}Warning: Zsh completion script '_hikma' not found in '${SRC_COMPLETION_DIR}'. Skipping completion installation.${RESET}"
fi

# 7. Create hikmarc file and update shell configurations
create_hikmarc

if [[ $? -eq 0 ]]; then
    UPDATED_SHELL_RC=0
    if [[ ${#SHELL_RC_FILES[@]} -gt 0 ]]; then
        for rc_file in "${SHELL_RC_FILES[@]}"; do
            add_line_to_file_if_not_exists "$SOURCE_HIKMARC_LINE" "$rc_file"
            if [[ $? -eq 1 ]]; then UPDATED_SHELL_RC=1; fi
        done
    fi
fi


echo ""
echo "${GREEN}${PROJECT_NAME} installation complete!${RESET}"
echo "--------------------------------------------------"
echo "  Executable:   ${GREEN}${WRAPPER_SCRIPT_PATH}${RESET}"
echo "  Core files:   ${TARGET_LIBEXEC_DIR}"
echo "  hikmarc:      ${HIKMA_RC_FILE}"
echo ""
if [[ "$UPDATED_SHELL_RC" -eq 0 ]] || [[ -f "${HIKMA_RC_FILE}" ]]; then
    echo "- ${YELLOW}Your shell configuration files (e.g. ~/.zshrc, ~/.bashrc) may have been updated.${RESET}"
else
    echo "- Manually source ${HIKMA_RC_FILE} from your .zshrc/ .bashrc:"
    echo "  e.g.   ${SOURCE_HIKMARC_LINE}"
fi
echo ""
echo "${GREEN}Run '${MAIN_EXECUTABLE_NAME} help' to get started.${RESET}"
echo "--------------------------------------------------"

exit 0
