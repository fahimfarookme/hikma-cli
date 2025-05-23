#!/bin/bash
# Checks for runtime dependencies required by the hikma-cli project.

# Exit on errors
set -e

echo -e "Checking for hikma-cli runtime dependencies..."

# Colors for output
if [[ -f "$(dirname "$0")/colors.zsh" ]]; then
    source "$(dirname "$0")/colors.zsh"
fi

# List of required commands
REQUIRED_COMMANDS=(
    "zsh"
    "git"
    "sed"
    "grep"
)

# List of optional but recommended commands
RECOMMENDED_COMMANDS=(
    "pandoc"        # For documentation conversion
    "emacs"         # Alternative for documentation conversion
    "shellcheck"    # For code quality
    "tput"          # For colored output
    "zunit"         # For unit tests
    "bats"     # For integration tests
)

MISSING_COUNT=0

echo -e "\nRequired commands:"
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if command -v "$cmd" &>/dev/null; then
        echo -e "  ${GREEN}[✓] $cmd${RESET}"
    else
        echo -e "  ${RED}[✗] $cmd (Missing)${RESET} - Required for hikma-cli."
        MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
done

echo -e "\nRecommended commands:"
for cmd in "${RECOMMENDED_COMMANDS[@]}"; do
    if command -v "$cmd" &>/dev/null; then
        echo -e "  ${GREEN}[✓] $cmd${RESET}"
    else
        echo -e "  ${YELLOW}[!] $cmd (Missing)${RESET} - Recommended but not required."
    fi
done

if [ "$MISSING_COUNT" -gt 0 ]; then
    echo -e "\n${RED}Error: $MISSING_COUNT required dependencies missing.${RESET}"
    echo -e "Please install the missing commands and try again."
    exit 1
else
    echo -e "\n${GREEN}All required dependencies are present.${RESET}"
    exit 0
fi