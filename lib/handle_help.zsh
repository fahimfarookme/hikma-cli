#!/bin/zsh


# Display help information
handle_help() 
{
    local help_file="$(hikma_script_root)/doc/help.txt"
    
    if [[ ! -f "${help_file}" ]]; then
        log_message "Help file not found at ${help_file}" "error"
        return ${hikma_code_illegal_state}
    fi

    cat "${help_file}"
    return 0
}
