#!/bin/zsh

# Print line numbers with error
export PS4='LINENO:'

# Error codes
# 128+ error codes are fatal - hence exited
declare -gx hikma_code_fatal=128
declare -gx hikma_code_illegal_state=129
declare -gx hikma_code_wrong_usage=130
declare -gx hikma_code_wrong_input=131


# Debug status
[[ -z "${hikma_debug+x}" ]] && declare -gx hikma_debug=0

# Log levels
declare -Agx hikma_log_levels=(
    ["info"]="info"
    ["error"]="error"
    ["warn"]="warn"
    ["debug"]="debug"
)

# Log a message with a timestamp
log_message() {
    local level="${2:-info}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    if [[ -z "${hikma_log_levels}[${level}]"  ]]; then
        echo "[${timestamp}] [error] Unsupported log level - ${level} }"
        return ${hikma_code_fatal}
    fi

    local message="${1}"
    local log="[${timestamp}] [${level}] ${message}"

    if [[ "debug" == ${hikma_log_levels}["${level}"]  ]]; then
        if [[ -o xtrace || -n "${hikma_debug}" ]]; then
            echo "${log}"
        fi
    elif [[ "error" == ${hikma_log_levels}["${level}"] ]]; then
        (echo "${log}") >&2
    else
        echo "${log}"
    fi

    return 0
}

do_exit() {
    local code=$?
    if (( ${code} >= ${hikma_code_fatal} )); then
        log_message "Exiting due to fatal condition. ${hikma_fatal_message}"
        exit ${code}
    fi
}

trap 'do_exit' ERR


# Audit a message with a timestamp at appropriate level
audit_message() {
    local message="${1}"
    local level="${2:-info}"
    local category="${3:-}"
    local concern="${4:-}"

    local audit_file="${hikma_workspace}"
    
    # Determine audit file path based on parameters provided
    if [[ -n "$concern" && -n "$category" ]]; then
        # Both category and concern provided - log at concern level
        audit_file="${audit_file}/${category}/${concern}"
    elif [[ -n "$category" ]]; then
        # Only category provided - log at category level
        audit_file="${audit_file}/${category}"
    fi

    audit_file="${audit_file}/.hikma_audit"

    # Create directory and audit file if they don't exist
    mkdir -p "$(dirname "$audit_file")"
    if [[ ! -f "$audit_file" ]]; then
        touch "$audit_file"
    fi
    
    # Log the message with timestamp
    log_message "${message}" "${level}" >> "$audit_file"
}