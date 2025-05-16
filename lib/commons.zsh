#!/bin/zsh

# Absolute directory path of the script root directory
declare -gx hikma_script_root="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")/.." && pwd)"

declare -Agx command_template

# Get the root script directory.
get_script_dir() 
{
    echo "$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")/.." && pwd)"
}

# Check if a value is in an array
# Usage: is_in_array "value" "${array[@]}"
# Returns: 0 if found, 1 if not found
is_in_array() 
{
   local needle="${1}"
   [[ $# -le 1 ]] && return 1

   local -a haystack=("${@:2}")
   
   for i in "${(@)haystack}"; do
      if [[ "${i}" == "${needle}" ]]; then
         return 0
      fi
   done
   return 1
}


# Read properties file into an associative array
# Usage:
#   declare -A config
#   read_props_to_array "config.props" config
#   echo "Username: ${config[USERNAME]}"
# Assumes the second parameter is the name of an associative array that has been declared
read_props_to_array() {
    local props_file="$1"
    # local -n props_array="$2"  # Name reference to the associative array - not supported in zsh
    local array_name="$2"

    if [[ ! -f "$props_file" ]]; then
        log_message "Properties file not found: $props_file" "ERROR"
        return 1
    fi
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Remove carriage returns
        line=$(echo "$line" | tr -d '\r')
        
        # Split on first equals sign
        local key="${line%%=*}"
        local value="${line#*=}"
        
        # Trim whitespace
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Store in associative array
        # props_array["$key"]="$value" -> not supported in zsh
        eval "${array_name}[\$key]=\"\$value\""
    done < "$props_file"
    
    return 0
}

# Load the local Hikma configuration into global configs
# load_config() {
#     local file=$1
#     local -n configs=$

#     if [[ ! -n "${hikma_workspace}" ]]; then
#         log_message "hikma_workspace not defined" "error"
#         return ${hikma_code_fatal}
#     fi

#     read_props_to_array "${hikma_workspace}/${config_file_name}" configs
#     return 0
# }

# Load the local Hikma configuration.
load_config() {
    [[ -z "$configs_loaded" ]] || return 0
    declare -g configs_loaded
    declare -gA configs
    read_props_to_array "$hikma_workspace/.hikma_config" configs
    configs_loaded=1
}

# $1 - key
_get_config() {
    local key="$1"
    if [[ -z "$key" ]]; then
        log_message "Config key is required." "error"
        return "${hikma_code_wrong_input}"
    fi

    load_config
    echo "${configs[$key]:-}"
}

# Get required config, error if missing.
# $1 - key
required_config() {
    local value="$(_get_config "$1")"
    if [[ -z "$value" ]]; then
        log_message "Value not configured for key $1" "error"
        return "${hikma_code_fatal}"
    fi

    echo "$value"
}


# Get optional config, empty if missing.
# $1 - key
optional_config() {
    local value="$(_get_config "$1")"
    if [[ -z "$value" ]]; then
        log_message "Value not configured for key $1" "warn"
        echo ""
    else
        echo "$value"
    fi
}


