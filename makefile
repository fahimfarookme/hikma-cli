# Makefile for hikma-cli

# --- Core Configuration Variables ---

# Project metadata
PROJECT_NAME := hikma-cli
VERSION_FILE := version
VERSION := $(shell cat $(VERSION_FILE) 2>/dev/null || echo "0.1.0")

# Installation directories
PREFIX ?= /usr/local                             # Base installation directory (can be overridden)
BINDIR ?= $(PREFIX)/bin                          # Executable location
LIBDIR ?= $(PREFIX)/lib/$(PROJECT_NAME)          # Library scripts
DATADIR ?= $(PREFIX)/share/$(PROJECT_NAME)       # Data files
DOCDIR ?= $(PREFIX)/share/doc/$(PROJECT_NAME)    # Documentation
MANDIR ?= $(PREFIX)/share/man                    # Man pages
COMPLETIONSDIR ?= $(PREFIX)/share/zsh/site-functions  # ZSH completions

# Project directory structure
BIN_DIR := bin
LIB_DIR := lib
DOC_DIR := doc
TEMPLATES_DIR := template
COMPLETION_DIR := completion
SCRIPTS_DIR := script
TEST_DIR := test
MAN_DIR := man

# Source files for processing
HIKMA_SCRIPT := $(BIN_DIR)/hikma.zsh
LIB_FILES := $(wildcard $(LIB_DIR)/*.zsh)
ALL_ZSH_SCRIPTS := $(HIKMA_SCRIPT) $(LIB_FILES) $(wildcard $(TEST_DIR)/*.zsh)

# Documentation source files
ORG_README := $(DOC_DIR)/readme.org
GENERATED_README := readme.md
ORG_MANPAGE := $(DOC_DIR)/manpage.org
GENERATED_MANPAGE := $(MAN_DIR)/man1/hikma.1

# Supporting scripts
COLORS_SCRIPT := $(SCRIPTS_DIR)/colors.zsh
INSTALL_SCRIPT := $(SCRIPTS_DIR)/install.zsh
UNINSTALL_SCRIPT := $(SCRIPTS_DIR)/uninstall.zsh
CHECK_DEPS_SCRIPT := $(SCRIPTS_DIR)/check_deps.zsh
HELP_FILE := $(SCRIPTS_DIR)/help.txt

# Packaging variables
PACKAGE_DIR := dist/$(PROJECT_NAME)-$(VERSION)
PACKAGE_TGZ := $(PACKAGE_DIR).tar.gz

# Tools and commands
SHELL := /bin/bash
ZSH := zsh
SHELLCHECK := shellcheck
TAR := tar
INSTALL := install
SED := sed
MKDIR := mkdir -p
PANDOC := pandoc
ZUNIT := zunit
BATS := bats

# Color definitions
GREEN := $(shell tput setaf 2)
YELLOW := $(shell tput setaf 3)
RED := $(shell tput setaf 1)
RESET := $(shell tput sgr0)

# --- Phony Targets Declaration ---
# Prevents conflicts with files of the same name and improves performance
.PHONY: all \
        help \
        check-deps \
        lint \
        docs \
        test \
        package \
        install \
        uninstall \
        clean \
        install-bin \
        install-lib \
        install-data \
        install-docs \
        install-man \
        install-completions \
        readme \
        manpage \
        test-unit \
        test-integration \
        bump-version

# --- Default Target ---
# The default when running 'make' with no arguments
all: check-deps lint docs test package
	@echo -e "$(GREEN)All tasks completed successfully.$(RESET)"

# --- Help Target ---
# Displays available targets and their descriptions
help:
	@sed -e 's|$$(PROJECT_NAME)|$(PROJECT_NAME)|g' \
	     -e 's|$$(VERSION)|$(VERSION)|g' \
	     -e 's|$$(PREFIX)|$(PREFIX)|g' \
	     -e 's|$$(PACKAGE_TGZ)|$(PACKAGE_TGZ)|g' \
	     -e 's|$$(GREEN)|$(GREEN)|g' \
	     -e 's|$$(YELLOW)|$(YELLOW)|g' \
	     -e 's|$$(RED)|$(RED)|g' \
	     -e 's|$$(RESET)|$(RESET)|g' \
	     $(HELP_FILE)

# --- Dependency Checking ---
check-deps:
	@echo -e "$(YELLOW)Checking dependencies...$(RESET)"

	@if [ ! -f "$(CHECK_DEPS_SCRIPT)" ]; then \
		echo "$(RED)Install script $(INSTALL_SCRIPT) not found."; \
		exit 1; \
	fi

	@if [ ! -x "$(CHECK_DEPS_SCRIPT)" ]; then \
		echo "Setting executable permission on $(CHECK_DEPS_SCRIPT)" && \
		chmod +x "$(CHECK_DEPS_SCRIPT)"; \
	fi

	@$(CHECK_DEPS_SCRIPT)

# --- Linting ---
lint:
	@echo -e "$(YELLOW)Linting shell scripts...$(RESET)"
	@# Check zsh syntax
	@for script in $(ALL_ZSH_SCRIPTS); do \
		echo "Checking syntax: $$script"; \
		$(ZSH) -n "$$script" || exit 1; \
	done

	@# Run shellcheck if available
	@if command -v $(SHELLCHECK) >/dev/null 2>&1; then \
		echo "Running shellcheck..."; \
		$(SHELLCHECK) --shell=bash $(ALL_ZSH_SCRIPTS) || exit 1; \
		echo -e "$(GREEN)Shellcheck passed.$(RESET)"; \
	else \
		echo -e "$(YELLOW)shellcheck not found. Skipping additional linting.$(RESET)"; \
	fi

# --- Documentation Generation ---
# Converts org-mode docs to other formats
docs: docs-readme docs-man

# Generate README.md from org-mode
docs-readme: $(ORG_README)
	@echo -e "$(YELLOW)Generating readme from org-mode...$(RESET)"
	@if [ ! -f "$(ORG_README)" ]; then \
		echo -e "$(RED)Error: $(ORG_README) not found!$(RESET)"; \
		exit 1; \
	fi

	@if command -v $(PANDOC) >/dev/null 2>&1; then \
		$(PANDOC) -f org -t gfm -o $(GENERATED_README) $(ORG_README); \
		echo -e "$(GREEN)$(GENERATED_README) generated with Pandoc.$(RESET)"; \
	else \
		echo -e "$(RED)Pandoc not found for org-mode conversion.$(RESET)"; \
		exit 1; \
	fi

# Generate man page from org-mode
docs-man: $(ORG_MANPAGE)
	@echo -e "$(YELLOW)Generating man page from org-mode...$(RESET)"
	@if [ ! -f "$(ORG_MANPAGE)" ]; then \
		echo -e "$(YELLOW)Warning: $(ORG_MANPAGE) not found. Skipping man page generation.$(RESET)"; \
		exit 0; \
	fi

	@$(MKDIR) $(MAN_DIR)/man1

	@if command -v $(PANDOC) >/dev/null 2>&1; then \
		$(PANDOC) -f org -t man -o $(GENERATED_MANPAGE) $(ORG_MANPAGE); \
		echo -e "$(GREEN)Man page generated with Pandoc.$(RESET)"; \
	else \
		echo -e "$(RED)Pandoc not found for org-mode conversion.$(RESET)"; \
		exit 1; \
	fi

# --- Testing ---
# Runs unit and integration tests
test: test-unit test-integration

# Run unit tests
test-unit:
	@echo -e "$(YELLOW)Running unit tests...$(RESET)"
	@if [ ! -d "$(TEST_DIR)/unit" ]; then \
		echo -e "$(RED)Error: Test directory $(TEST_DIR)/unit not found!$(RESET)"; \
		exit 1; \
	fi
	
	@if [ "! $$(ls -A $(TEST_DIR)/unit 2>/dev/null)" ]; then \
		echo -e "$(YELLOW)No unit tests found in $(TEST_DIR)/unit/ directory.$(RESET)"; \
		exit 0; \
	fi;

	zsh -c '$(ZUNIT) run' || exit $$?
	@echo -e "$(GREEN)Unit tests passed.$(RESET)"


# Run integration tests
test-integration:
	@echo -e "$(YELLOW)Running unit tests...$(RESET)"

	@if [ ! -d "$(TEST_DIR)/integration" ]; then \
		echo -e "$(RED)Error: Test directory $(TEST_DIR)/integration not found!$(RESET)"; \
		exit 1; \
	fi

	@if [ "! $$(ls -A $(TEST_DIR)/integration 2>/dev/null)" ]; then \
		echo -e "$(YELLOW)No integration tests found in $(TEST_DIR)/integration/ directory.$(RESET)"; \
		exit 0; \
	fi;

	@for test in $(TEST_DIR)/integration/*.bats; do \
		echo "Running $$test"; \
		zsh -c "$(BATS) --tap --output $(TEST_DIR)/integration/_output $$test" || exit 1; \
	done
	@echo -e "$(GREEN)Integration tests passed.$(RESET)"


# --- Packaging ---
# Creates distributable archive
package: docs
	@echo -e "$(YELLOW)Creating package $(PACKAGE_TGZ)...$(RESET)"

	@# Create a clean package directory
	@rm -rf $(PACKAGE_DIR)
	@$(MKDIR) $(PACKAGE_DIR)

	@# Copy project files
	@cp -r $(BIN_DIR) $(LIB_DIR) $(TEMPLATES_DIR) $(DOC_DIR) $(SCRIPTS_DIR) $(PACKAGE_DIR)/

	@# Copy documentation files
	@cp $(GENERATED_README) $(VERSION_FILE) $(PACKAGE_DIR)/ 2>/dev/null || true
	@# Include man pages if generated
	@if [ -d "$(MAN_DIR)" ]; then cp -r $(MAN_DIR) $(PACKAGE_DIR)/; fi

	@# Include completion files if available
	@if [ -d "$(COMPLETION_DIR)" ]; then cp -r $(COMPLETION_DIR) $(PACKAGE_DIR)/; fi

	@# Create the tarball
	@$(TAR) -czf $(PACKAGE_TGZ) $(PACKAGE_DIR)
	@rm -rf $(PACKAGE_DIR)

	@echo -e "$(GREEN)Package created: $(PACKAGE_TGZ)$(RESET)"

# --- Installation ---
# Delegates to install.sh script
install: docs check-deps
	@echo -e "$(YELLOW)Installing $(PROJECT_NAME)...$(RESET)"

	@if [ ! -f "$(INSTALL_SCRIPT)" ]; then \
		echo "$(RED)Install script $(INSTALL_SCRIPT) not found."; \
		exit 1; \
	fi

	@if [ ! -x "$(INSTALL_SCRIPT)" ]; then \
		echo "Setting executable permission on $(INSTALL_SCRIPT)" && \
		chmod +x "$(INSTALL_SCRIPT)"; \
	fi

	@$(INSTALL_SCRIPT)

# --- Uninstallation ---
# Removes installed files
uninstall:
	@echo -e "$(YELLOW)Uninstalling $(PROJECT_NAME)...$(RESET)"

	@if [ ! -f "$(UNINSTALL_SCRIPT)" ]; then \
		echo "$(RED)Uninstall script $(UNINSTALL_SCRIPT) not found."; \
		exit 1; \
	fi

	@if [ ! -x "$(UNINSTALL_SCRIPT)" ]; then \
		echo "Setting executable permission on $(UNINSTALL_SCRIPT)" && \
		chmod +x "$(UNINSTALL_SCRIPT)"; \
	fi

	@$(UNINSTALL_SCRIPT)

# --- Cleanup ---
# Removes temporary and generated files
clean:
	@echo -e "$(YELLOW)Cleaning project...$(RESET)"
	@rm -rf dist $(PACKAGE_DIR)
	@rm -f $(GENERATED_README)
	@rm -rf $(MAN_DIR)
	@echo -e "$(GREEN)Clean complete.$(RESET)"

# --- Version Management ---
# Increments version number and creates git tag
bump-version:
	@echo -e "$(YELLOW)Current version: $(VERSION)$(RESET)"
	@read -p "Enter new version: " new_version; \
	if [ -z "$$new_version" ]; then \
		echo -e "$(RED)No version entered. Aborting.$(RESET)"; \
		exit 1; \
	fi; \
	echo "$$new_version" > $(VERSION_FILE); \
	echo -e "$(GREEN)Version updated to $$new_version$(RESET)"; \
	if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then \
		git add $(VERSION_FILE); \
		git commit -m "Bump version to $$new_version"; \
		git tag "v$$new_version"; \
		echo -e "$(GREEN)Git commit and tag created.$(RESET)"; \
	fi