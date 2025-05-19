#!/bin/zsh

declare -gA configs
read_props_to_array "${hikma_workspace}/.hikma_config" configs

declare -gA item_types=(${(s:,:)"${configs[hikma.item_types]}"})

# Helper function to validate item_types
validate_item_type() {
    local item_type="$1"

    if ! is_in_array "${item_type}" "${(@)item_types}"; then
        log_message "Invalid item_type '${item_type}'. See hikma.item_types for valid item_types." "error"
        return ${hikma_code_wrong_input}
    fi
}


# Get the location for a specific item from configuration
# $1: item_type - email, meeting, journal, index-note, concept-note, task
get_item_location() {
    local item_type="$1"
    validate_item_type "${item_type}"
    
    # Get location template from configuration
    local location_key="hikma.item_types.dir.${item_type}"
    local location_template="${configs[$location_key]}"
    
    if [[ -z "$location_template" ]]; then
        log_message "Location not defined for $item_type (${location_key})" "error"
        return ${hikma_code_illegal_state}
    fi
    
    # Process the location template, replacing variables
    local location=$(substitute_variables "${location_template}")
    
    echo "${location}"
    return 0
}

# Get the full directory path for a specific item type
# $1: item_type - Type of item
# $2: Additional directory options (optional)
get_item_directory() {
    local item_type="$1"
    local additional_options="$2"
    
    # Get the processed location template
    local rel_location=$(get_item_location "$item_type")
    
    # Handle absolute paths (if location starts with /)
    if [[ "${rel_location:0:1}" == "/" ]]; then
        echo "${rel_location}"
        return 0
    fi
    
    # Ensure the path is in the hikma workspace
    echo "${hikma_workspace}/${rel_location}"
    return 0
}


# Generate a filename for an item
# $1: item_type - Type of item
# $2: title - Title/ subject for named item_types (optional)
generate_item_filename() {
    local item_type="$1"
    local title="$2"
    
    # First check if there's a custom filename generator function
    local generator_key=""
    local generator_func="$(required_config "hikma.item_types.filename.${item_type}")"
    
    if [[ $+functions[$generator_func] ]]; then
        $generator_func "$title"
        return $?
    fi
    
    # Default name
    echo "$(gen_default_name "${item_type}" "${title}")"
}

# Converts passed options to an associative array
# Usage: process_options --title "My Note" --author Fahim --urgent opts
process_options() {
    local all_args=("$@")
    local array_name="${all_args[$#]}" # Last arg
    
    local -i i=0
    local -i length=$(($# - 1))
    local key

    # Process all but the last argument
    while [[ $i -lt $length ]]; do
        local arg="${all_args[$((++i))]}"
        if [[ "$arg" == --* ]]; then
            key="${arg#--}"
            local next_arg="${all_args[$((i+1))]}"
            if [[ "$next_arg" != --* && $((i+1)) -lt $# ]]; then
                eval "${array_name}[\${key}]=\${next_arg}"
                ((i++))
            else
                eval "${array_name}[\${key}]=true"
            fi
        fi
    done
}


# Handler for getting an item's path
# Usage: hikma item path <item-type>
handle_item_path() {
    local item_type="$1"
    validate_item_type "${item_type}"
        
    local dir_path=$(get_item_directory "$item_type")
    local filename=$(generate_item_filename "$item_type" "$title")
    
    # Return full path
    echo "${dir_path}/${filename}"
    return 0
}


# Handler for getting an item's template content
# Usage: hikma item content <item-type> [--var value ...]*
handle_item_content() {
    local item_type="$1"
    validate_item_type "${item_type}"
    
    local location_template="$(required_config "hikma.item_types.template.${item_type}")"
    local location="$(substitute_variables "${location_template}")" || return $?
    
    if [[ ! -f "${location}" ]]; then
        log_message "Template ${location} does not exist." "error"
        return ${hikma_code_illegal_state}
    fi

    if [[ ! -s "${location}" ]]; then
        echo ""
        return 0
    fi

    local content="$(cat "$location")"

    declare -A opts    
    process_options "$@" "opts"

    local processed_content="$(substitute_variables "${content}" "opts")"

    echo "$processed_content"
    return 0
}


# Handler for creating an item
# Usage: hikma item create <item-type> [--var value]*
handle_item_create() {
    local item_type="$1"
    shift

    # Get the file path
    local path="$(handle_item_path "$item_type")"
    if [[ $? -ne 0 ]]; then
        # Error already logged
        return ${hikma_code_illegal_state}
    fi
    
    # Get template content with variables
    local content=$(handle_item_content "$item_type" "$@")
    
    if [[ $? -ne 0 ]]; then
        # Error already logged
        return ${hikma_code_illegal_state}
    fi
    
    # Create parent directory if needed
    mkdir -p "$(dirname "$path")"
    
    # Write content to file
    echo "$content" > "$path"
    
    audit_message "Item created; type: $item_type, path: $path"
    return 0
}

