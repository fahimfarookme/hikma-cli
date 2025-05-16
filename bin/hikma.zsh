#!/bin/zsh

# Absolute directory path of the script root directory
declare -gx hikma_script_root="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")/.." && pwd)"

declare -Agx command_template

# Load modules with dependency management
load_modules() {
    local lib_dir="${hikma_script_root}/lib"
    
    # Define ordered dependencies
    local -a ordered_deps=(
        "${lib_dir}/error.zsh"
        "${lib_dir}/commons.zsh"
    )

    # Lookup associative array
    local -A dependent_modules=()
    
    # First, load all dependent modules in order
    for module in "${ordered_deps[@]}"; do
        if [[ -f "$module" ]]; then
            source "$module"
            if [[ $? -ne 0 ]]; then
                log_message "Failed to load module: $module" "error"
                return ${hikma_code_fatal}
            fi
            dependent_modules[$module]=$module
            log_message "Loaded dependent module: $module" "INFO"
        else
            log_message "Dependent module not found: $module" "error"
            return ${hikma_code_fatal}
        fi
    done
    
    # Then load all remaining modules with O(1) lookup
    for module in "${lib_dir}"/*.zsh; do
        # Skip if already loaded (O(1) lookup)
        if [[ -z "${dependent_modules[$module]}" ]]; then
            source "$module"
            if [[ $? -ne 0 ]]; then
                log_message "Failed to load module: $module" "error"
                return ${hikma_code_fatal}
            fi
            log_message "Loaded module: $module" "INFO"
        fi
    done
}

# Load command templates from file
load_command_templates() {
    if (( ${#command_template[@]} <= 0 )); then
        log_message "Comman template already populated" "warn"
        return 1
    fi

    local template_file="${hikma_script_root}/bin/command_template.txt"
        
    if [[ -f "${template_file}" ]]; then
        local line_num=0
        while IFS= read -r line || [[ -n "$line" ]]; do
            ((line_num++))
            
            # Skip empty lines and comments
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            
            # Parse template line: pattern:handler_function:capture_var_names
            local parts=("${(@s/:/)line}")
            
            if [[ ${#parts[@]} -lt 2 ]]; then
                log_message "Invalid template format at line $line_num: $line" "error"
                return ${hikma_code_fatal}
            fi
            
            local pattern="${parts[1]}"

            # Store template
            command_template[$pattern]="${parts[1]}"
            command_template["${pattern}__h__"]="${parts[2]}"
        done < "${template_file}"
        
        log_message "Loaded command templates from $template_file" "INFO"
    else
        log_message "Command templates file not found: $template_file. Using default templates." "error"
        return ${hikma_code_fatal}
    fi
}


# Process command based on matched pattern
process_command() {
    if (( ${#command_template[@]} > 0 )); then
        log_message "Comman template not populated" "error"
        return ${hikma_code_illegal_state}
    fi

    local num_args=$#
    # Get all arguments except the last one
    local cmd_args=("${@:1:$((num_args-1))}")
    # Combine them into a string
    local cmd_line="${cmd_args[*]}"
    
    # Match command against patterns
    for key val in "${(@kv)command_template}"; do
        if [[ "$cmd_line" =~ $key ]]; then
            # Get handler details

            local handler_function=$command_template["${key}__h__"]
            
            # Get captures from regex match
            local -a captures=("${match[@]}")

            # Execute handler with captured arguments
            "$handler_function" "${captures[@]}"

            return $?
        fi
    done
    
    log_message "Invalid command - ${cmd_line}. See help" "error"
    return ${hikma_code_wrong_usage}
}

main() {
    load_modules
    
    if [[ $# -eq 0 ]]; then
        log_message "Wrong command usage." "error"
        show_help
        return ${hikma_code_wrong_usage}
    fi
    
    # Load command templates
    load_command_templates
    
    # Process the command
    process_command "$@"

    # Exit with exit code of last command
    exit $?
}

# Execute the main function with all arguments
main "$@"

