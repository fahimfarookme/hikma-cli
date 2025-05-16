#!/bin/zsh

declare -g config_file_name=".hikma_config"
declare -g config_template_file="$(get_script_dir)/templates/hikma_root/${config_file_name}"
[[ -z "${hikma_workspace+x}" ]] && declare -gx hikma_workspace="$(pwd)"

validate_initialized() {
    local workspace=$1

    # Check if we are already in a HIKMA repository
    if [[ -f "${workspace}/${config_file_name}" ]]; then
        log_message "Hikma repository is already initialized in this directory." "warn"
        return ${hikma_code_illegal_state}
    fi

    return 0
}

create_dirs() {
    local workspace=$1

    declare -A configs
    read_props_to_array "${config_template_file}" configs

    local root_template="$(get_script_dir)/templates/hikma_root"
    if [[ ! -d "$root_template" ]]; then
        log_message "Missing root template at ${root_template}" "error"
        return ${hikma_code_illegal_state}
    fi
    
    cp -r "${root_template}/." "${workspace}"

    local categories="${configs[hikma.categories]}"
    if [[ ! -n "${categories}" ]]; then
        log_message "Missing categories in hikma.categories." "error"
        return ${hikma_code_illegal_state}
    fi

    # Create the basic category directories
    categories=(${(s:,:)"${categories}"})

    # Create directories for each category
    for category in "${categories[@]}"; do
        # Trim any whitespace from category name
        category=$(echo "$category" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Create the directory
        mkdir -p "${workspace}/${category}"
        log_message "Created directory: $category" "INFO"
    done
}

init_git() {
    local workspace=$1

    declare -A configs
    read_props_to_array "${config_template_file}" configs

    (
        cd "${workspace}"
        if [[ ! -d ".git" ]]; then
            git init
        fi

        git add .
        git commit -m "${configs[hikma.commit_msg.root_init]}"
    )
}


set_hikma_root_env() {
    local workspace=$1
    
    local user_config_files=(
        "$HOME/.bashrc"
        "$HOME/.zshrc"
    )
    local var_name="hikma_workspace"
    local export_line="export ${var_name}=\"${workspace}\""
    local grep_pattern="export ${var_name}=" # Pattern to check for existing line


    # Update user configuration files
    for config_file in "${user_config_files[@]}"; do
        # Skip if file doesn't exist
        if [[ ! -f "$config_file" ]]; then
            continue
        fi

        # Check if any line defining hikma_workspace already exists
        # The grep_pattern is defined earlier as "export hikma_workspace="
        if ! grep -q -- "export ${var_name}=" "$config_file"; then
            echo "export ${var_name}=\"${workspace}\"" >> "$config_file"
        fi
    done

    return 0
}

# Initialize the hikma_workspace directory structure at the current directory
# This function sets up the core directory structure and .hikma_config file
handle_init() {
    [[ -z "${hikma_workspace+x}" ]] && hikma_workspace=$(pwd)

    validate_initialized "${hikma_workspace}" || return $?
    create_dirs "${hikma_workspace}" || return $?
    init_git "${hikma_workspace}" || return $?
    set_hikma_root_env "${hikma_workspace}" || return $?
}

