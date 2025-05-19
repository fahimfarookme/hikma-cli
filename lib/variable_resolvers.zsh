#!/bin/zsh

# Variable resolver functions (configured in config) does not accept any arguments

load_config

# Internal helper: extracts relative path components from the current directory
# TODO - don't return resource, but error code. Let caller to decide
_parse_path() {
    local current_dir=$(pwd)
    local default_category="${configs[hikma.categories.fallback]:-resources}"
    
    # Not in workspace
    if [[ ! "$current_dir" =~ ^"${hikma_workspace}" ]]; then
        log_message "$current_dir is not in hikma_workspace" "warn"
        echo "$default_category::"
        return 0
    fi
    
    # Extract relative path from workspace
    local rel_path="${current_dir#${hikma_workspace}/}"
    
    # In workspace root
    if [[ -z "$rel_path" || "$rel_path" == "/" ]]; then
        log_message "At workspace root, using default category" "debug"
        echo "$default_category::"
        return 0
    fi
    
    local category=$(echo "$rel_path" | cut -d '/' -f1)
    local concern=$(echo "$rel_path" | cut -d '/' -f2)
    
    if [[ -z "$category" ]]; then
        log_message "Invalid category directory: $rel_path" "warn"
        category="$default_category"
    fi
    
    echo "${category}:${concern}:${rel_path}"
    return 0
}

# Get the current category
# $1: (Optional) Result string from _parse_path
get_current_category() {
    local result="${1:-$(_parse_path)}"
    echo "${result%%:*}"
}

# Get the current concern
# $1: (Optional) Result string from _parse_path
get_current_concern() {
    local result="${1:-$(_parse_path)}"
    local concern="${result#*:}"
    echo "${concern%%:*}"
}

# Get the current context as category/concern or just category
get_current_context() {
    local result="${1:-$(_parse_path)}"
    local category=$(get_current_category "$result")
    local concern=$(get_current_concern "$result")
    
    if [[ -z "$concern" ]]; then
        echo "$category"
    else
        echo "${category}/${concern}"
    fi
}

# Get the current dir
get_current_dir() {
    echo "$(pwd)"
}

# Get current date and time
get_date_time() {
    date +"%Y-%m-%d %H:%M:%S"
    return 0
}

# Get current date
get_date() {
    date +"%Y-%m-%d"
    return 0
}

# Get the default template dir
get_default_template_dir() {
    echo "${hikma_script_root}/template"
}


# Substitute variables in a string
# $1: Template string with placeholders
# $2: Associative array name for custom vars (optional)
substitute_variables() {
    local template="$1"
    
    # Create unified variable values array
    local -A all_vars
    
    # Step 1: Collect prebuilt variables from config
    for key in "${(@k)configs}"; do
        if [[ "$key" =~ ^hikma\.variables\.(.+)$ ]]; then
            local var_name="${match[1]}"
            local func_name="${configs[$key]}"
            
            # Skip if variable doesn't appear in template
            [[ "$template" != *"{{$var_name}}"* ]] && continue
            
            # If function name is empty
            [[ -z "$func_name" ]] && {
                log_message "No function defined for variable $var_name" "error"
                return ${hikma_code_illegal_state}
            }
            
            # If function doesn't exist
            (( ! $+functions[$func_name] )) && {
                log_message "Function $func_name for variable $var_name not found" "error"
                return ${hikma_code_illegal_state}
            }
            
            # Function exists and variable is used - calculate and store value
            all_vars[$var_name]="$($func_name)"
        fi
    done
    
    # Step 2: Add additional variables if provided
    if [[ -n "$2" ]]; then
        eval "local -A additional_vars=(\"\${(@kv)$2[@]}\")"
        
        for var_name in "${(@k)additional_vars}"; do
            all_vars[$var_name]="${additional_vars[$var_name]}"
        done
    fi
    
    # Step 3: Perform all substitutions in a single pass
    local result="$template"
    for var_name in "${(@k)all_vars}"; do
        result="${result//\{\{$var_name\}\}/${all_vars[$var_name]}}"
    done
    
    echo "$result"
    return 0
}
