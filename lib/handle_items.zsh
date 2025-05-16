#!/bin/zsh

declare -gA configs
read_props_to_array "${hikma_workspace}/.hikma_config" configs

declare -gA items=(${(s:,:)"${configs[hikma.items]}"})

# Helper function to validate items
validate_item() {
    local item="$1"

    if ! is_in_array "${item}" "${(@)items}"; then
        log_message "Invalid item '${item}'. See hikma.items for valid items." "error"
        return ${hikma_code_wrong_input}
    fi
}


# Get the location for a specific item from configuration
# $1: item_type - email, meeting, journal, index-note, concept-note, task
get_item_location() {
    local item_type="$1"
    validate_item "${item_type}"
    
    # Get location template from configuration
    local location_key="hikma.items.dir.${item_type}"
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
# $2: title - Title/ subject for named items (optional)
generate_item_filename() {
    local item_type="$1"
    local title="$2"
    
    # First check if there's a custom filename generator function
    local generator_key=""
    local generator_func="$(required_config "hikma.items.filename.${item_type}")"
    
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
    local key

    # Process all but the last argument
    while [[ $i -lt $(($# - 1)) ]]; do
        local arg="${all_args[$((++i))]}"
        if [[ "$arg" == --* ]]; then
            key="${arg#--}"
            local next_arg="${all_args[$((i+1))]}"
            if [[ "$next_arg" != --* && $((i+1)) -lt $# ]]; then
                eval "${array_name}[\${key}]=\${next_arg@Q}"
                ((i++))
            else
                eval "${array_name}[\${key}]=true"
            fi
        fi
    done
}



# Handler for getting an item's path
# Usage: hikma item path <item-type> [--title <title>]
handle_item_path() {
    local item_type="$1"
    shift
    
    if [[ -z "$item_type" ]]; then
        log_message "Item type is required" "error"
        return ${hikma_code_wrong_usage}
    }
    
    # Process options for title
    local title=""
    local options_dir=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --title)
                if [[ $# -gt 1 ]]; then
                    title="$2"
                    shift 2
                else
                    log_message "Missing value for --title" "error"
                    return ${hikma_code_wrong_usage}
                fi
                ;;
            --dir)
                if [[ $# -gt 1 ]]; then
                    options_dir="$2"
                    shift 2
                else
                    log_message "Missing value for --dir" "error"
                    return ${hikma_code_wrong_usage}
                fi
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # Get the directory
    local dir_path=$(get_item_directory "$item_type" "$options_dir")
    if [[ $? -ne 0 ]]; then
        # Error already logged in get_item_directory
        return ${hikma_code_illegal_state}
    }
    
    # Generate filename
    local filename=$(generate_item_filename "$item_type" "$title")
    
    # Return full path
    echo "${dir_path}/${filename}"
    return 0
}















# Handler for getting an item's path
handle_item_path() {
    local item_type="$1"
    
    if [[ -z "$item_type" ]]; then
        log_message "Item type is required" "error"
        return ${hikma_code_wrong_usage}
    fi
    
    # Get the directory
    local dir_path=$(get_item_directory "$item_type")
    
    # Generate filename if title provided
    local filename
    if [[ -n "$title" ]]; then
        filename=$(generate_item_filename "$item_type" "$title")
    else
        filename=$(generate_item_filename "$item_type")
    fi
    
    # Return full path
    echo "${dir_path}/${filename}"
    return 0
}

# Handler for getting an item's template content
handle_item_content() {
    local item_type="$1"
    shift
    
    if [[ -z "$item_type" ]]; then
        log_message "Item type is required" "error"
        return ${hikma_code_wrong_usage}
    fi
    
    # Get the template file
    local template_file="${hikma_script_root}/templates/${item_type}.org"
    if [[ ! -f "$template_file" ]]; then
        log_message "Template for ${item_type} not found at ${template_file}" "error"
        return ${hikma_code_wrong_input}
    fi
    
    # Read template content
    local content=$(cat "$template_file")
    
    # Get current context
    local context=$(get_current_context)
    local category=$(echo "$context" | cut -d '/' -f1)
    local concern=$(echo "$context" | cut -d '/' -f2)
    
    # Get current date in different formats
    local date_full=$(date +"%Y-%m-%d %H:%M:%S")
    local date_short=$(date +"%Y-%m-%d")
    
    # Replace system variables
    content=${content//\{\{__category__\}\}/$category}
    content=${content//\{\{__concern__\}\}/$concern}
    content=${content//\{\{__context__\}\}/$context}
    content=${content//\{\{__date__\}\}/$date_full}
    content=${content//\{\{__date_short__\}\}/$date_short}
    
    # Process any additional variables from command line
    local key value
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == --* ]]; then
            key=${1#--}
            if [[ $# -gt 1 && "$2" != --* ]]; then
                value="$2"
                # Replace the variable in content
                content=${content//\{\{__${key}__\}\}/$value}
                shift 2
            else
                # Flag option
                content=${content//\{\{__${key}__\}\}/true}
                shift
            fi
        else
            shift
        fi
    done
    
    echo "$content"
    return 0
}

# Handler for creating an item
handle_item_create() {
    local item_type="$1"
    shift
    
    if [[ -z "$item_type" ]]; then
        log_message "Item type is required" "error"
        return ${hikma_code_wrong_usage}
    fi
    
    # Extract title if provided with --title
    local title=""
    local args=("$@")
    local new_args=()
    
    for ((i=0; i<${#args[@]}; i+=2)); do
        if [[ "${args[$i]}" == "--title" && $((i+1)) -lt ${#args[@]} ]]; then
            title="${args[$i+1]}"
        else
            new_args+=("${args[$i]}")
            if [[ $((i+1)) -lt ${#args[@]} ]]; then
                new_args+=("${args[$i+1]}")
            fi
        fi
    done
    
    # Get the file path
    local path=$(handle_item_path "$item_type" "$title")
    
    # Get template content with variables
    local content=$(handle_item_content "$item_type" "${new_args[@]}")
    
    # Create parent directory if needed
    mkdir -p "$(dirname "$path")"
    
    # Write content to file
    echo "$content" > "$path"
    
    # Add to git if this is a git repository
    if [[ -d "${hikma_workspace}/.git" ]]; then
        (cd "${hikma_workspace}" && 
         git add "$path" && 
         git commit -m "Add ${item_type}: ${title}")
    fi
    
    echo "$path"
    return 0
}





























# Handler for getting an item's template content
# Usage: hikma item content <item-type> [--var value ...]
handle_item_content() {
    local item_type="$1"
    shift
    
    if [[ -z "$item_type" ]]; then
        log_message "Item type is required" "error"
        return ${hikma_code_wrong_usage}
    }
    
    # Get the template file
    local template_file="${hikma_script_root}/templates/${item_type}.org"
    if [[ ! -f "$template_file" ]]; then
        log_message "Template for ${item_type} not found at ${template_file}" "error"
        return ${hikma_code_wrong_input}
    }
    
    # Read template content
    local content=$(cat "$template_file")
    
    # Process custom variables from command line
    declare -A custom_vars
    
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == --* ]]; then
            local key="${1#--}"
            
            if [[ $# -gt 1 && "$2" != --* ]]; then
                custom_vars[$key]="$2"
                shift 2
            else
                custom_vars[$key]="true"
                shift
            fi
        else
            shift
        fi
    done
    
    # Use the substitute_variables function to process the template
    local processed_content=$(substitute_variables "$content" "custom_vars")
    
    echo "$processed_content"
    return 0
}

# Handler for creating an item
# Usage: hikma item create <item-type> [--var value ...]
handle_item_create() {
    local item_type="$1"
    shift
    
    if [[ -z "$item_type" ]]; then
        log_message "Item type is required" "error"
        return ${hikma_code_wrong_usage}
    }
    
    # Extract title and options
    local title=""
    local options_dir=""
    declare -A custom_vars
    
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == --* ]]; then
            local key="${1#--}"
            
            # Handle special options
            if [[ "$key" == "title" && $# -gt 1 ]]; then
                title="$2"
                custom_vars["title"]="$2"
                shift 2
            elif [[ "$key" == "dir" && $# -gt 1 ]]; then
                options_dir="$2"
                shift 2
            elif [[ $# -gt 1 && "$2" != --* ]]; then
                custom_vars[$key]="$2"
                shift 2
            else
                custom_vars[$key]="true"
                shift
            fi
        else
            shift
        fi
    done
    
    # Get the file path
    local path=$(handle_item_path "$item_type" --title "$title" --dir "$options_dir")
    if [[ $? -ne 0 ]]; then
        # Error already logged
        return ${hikma_code_illegal_state}
    }
    
    # Get template content with variables
    local content=$(handle_item_content "$item_type" $(
        for key in "${(@k)custom_vars}"; do
            echo "--${key}" "${custom_vars[$key]}"
        done
    ))
    
    if [[ $? -ne 0 ]]; then
        # Error already logged
        return ${hikma_code_illegal_state}
    }
    
    # Create parent directory if needed
    mkdir -p "$(dirname "$path")"
    
    # Write content to file
    echo "$content" > "$path"
    
    # Add to git if this is a git repository
    if [[ -d "${hikma_workspace}/.git" ]]; then
        (cd "${hikma_workspace}" && 
         git add "$path" && 
         git commit -m "Add ${item_type}${title:+: $title}")
    }
    
    echo "$path"
    return 0
}