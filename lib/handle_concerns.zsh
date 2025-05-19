#!/bin/zsh

declare -gA configs
read_props_to_array "${hikma_workspace}/.hikma_config" configs

declare -gA categories=(${(s:,:)"${configs[hikma.categories]}"})

# Helper function to validate category
validate_category() {
    local category="$1"

    if ! is_in_array "$category" "${(@)categories}"; then
        log_message "Invalid category '$category'. See hikma.categories for valid categories." "error"
        return ${hikma_code_wrong_input}
    fi
}


# Helper function to validate concern name
validate_concern_name() {
    local concern="$1"
    if [[ -z "$concern" ]]; then
        log_message "Concern name cannot be empty." "error"
        return ${hikma_code_wrong_input}
    fi
}


# Check if concern already exists in category
is_concern_exists() {
    local category="$1"
    local concern="$2"

    local concern_path="${hikma_workspace}/${category}/${concern}"
    if [[ -d "$concern_path" ]]; then
        return 0
    fi

    return 1
}


# Initialize concern from template
init_concern() {
    local category="$1"
    local concern="$2"
    local concern_path="$3"
    local current_date=$(date +"%Y-%m-%d %H:%M:%S")
    local template_path="${hikma_script_root}/template/${category}"

    if [[ ! -d "${template_path}" ]]; then
        log_message "Template ${template_path} does not exist." "error"
        return ${hikma_code_illegal_state}
    fi

    cp -r "$template_path"/* "$concern_path/"

    find "$concern_path" -type f | while read file; do
        sed -i'' -e "s/{{__category__}}/$category/g" "$file"
        sed -i'' -e "s/{{__concern__}}/$concern/g" "$file"
        sed -i'' -e "s/{{__concern_path__}}/$concern_path/g" "$file"
        sed -i'' -e "s/{{__date__}}/$current_date/g" "$file"
    done
 
    audit_message "$concern $category created" "$category" "$concern"
}


# Handler for creating concerns i.e. items in categories
# $1: category - project, domain, archive, resource
# $2: concern - item name within the category. i.e. concern name
handle_concern_create() {
    local category="$1"
    local concern="$2"
    
    validate_category "$category"

    if [[ "$category" == "${configs[hikma.categories.archives]:-archive}" ]]; then
        log_message "Cannot create concerns in archive category directly. Use move instead." "error"
        return ${hikma_code_wrong_usage}
    fi

    validate_concern_name "$concern"
    
    if is_concern_exists "$category" "$concern"; then
        log_message "Concern '$concern' already exists in category '$category'." "error"
        return ${hikma_code_illegal_state}
    fi
    
    # Create the item directory
    local concern_path="${hikma_workspace}/${category}/${concern}"
    mkdir -p "$concern_path"

    # Initialize with default structure
    init_concern "$category" "$concern" "$concern_path"

    # $hikma_workspace is already a git repo.
    # Using subshells (...) for operations that need a different directory
    (cd "$concern_path" && git add . && git commit -m "Bismiallah, created $concern in $category")
    
    log_message "Successfully created '$concern' in category '$category'." "INFO"
    return 0
}


# Handler for deleting concerns i.e. items in categories
# $1: category - project, domain, archive, resource
# $2: concern - item name within the category. i.e. concern name
handle_concern_delete() {
    local category="$1"
    local concern="$2"

    validate_category "$category"
    
    if ! is_concern_exists "$category" "$concern"; then
        log_message "Concern '$concern' does not exist in category '$category'." "error"
        return ${hikma_code_illegal_state}
    fi

    # Ask for confirmation
    log_message "Warning: This will permanently delete '$concern' from '$category'." "INFO"
    read -p "Are you sure you want to continue? (y/N): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_message "Operation cancelled." "error"
        return ${hikma_code_fatal}
    fi
    
    local concern_path="${hikma_workspace}/${category}/${concern}"

    # Remove from git
    # Using subshells (...) for operations that need a different directory
    (cd "${hikma_workspace}" && git rm -rf "$concern_path" && git commit -m "Deleted $concern from $category")
    
    # Delete the directory
    rm -rf "$concern_path"
    
    log_message "Successfully deleted '$concern' from category '$category'." "INFO"
    return 0
}


# Handler for moving a concern between categories
# $1: source category
# $2: concern name
# $3: destination category
handle_concern_mv() {
    local src_category="$1"
    local concern="$2"
    local dest_category="$3"

    validate_category "$src_category"
    validate_category "$dest_category"
    validate_concern_name "$concern"
    
    if ! is_concern_exists "$src_category" "$concern"; then
        log_message "Concern '$concern' does not exist in source category '$category'." "error"
        return ${hikma_code_illegal_state}
    fi

    if is_concern_exists "$dest_category" "$concern"; then
        log_message "Concern '$concern' already exists in destination category '$category'." "error"
        return ${hikma_code_illegal_state}
    fi
    
    # Create destination directory if it doesn't exist
    mkdir -p "${hikma_workspace}/${dest_category}"
    
    # Move the item
    local source_path="${hikma_workspace}/${src_category}/${concern}"
    local dest_path="${hikma_workspace}/${dest_category}/${concern}"
    mv "$source_path" "$dest_path"
    
    # Update metadata
    audit_message "Moved from '$src_category' to '$dest_category'" "${dest_category}" "${concern}"
    
    # Update git
    # Using subshells (...) for operations that need a different directory
    (cd "${hikma_workspace}" && 
    git add "${src_category}/${concern}" "${dest_category}/${concern}" && 
    git commit -m "Moved $concern from $src_category to $dest_category")
    
    log_message "Successfully moved '$concern' from '$src_category' to '$dest_category'." "INFO"
    return 0
}


# Handler for archiving concerns in categories
# $1: source category - project, domain, resource
# $2: concern - item name within the category
handle_concern_archive() {
    local src_category="$1"
    local concern="$2"

    handle_concern_mv $src_category $concern "archive"
    return $?
}
