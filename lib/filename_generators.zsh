#!/bin/zsh

# Filename genrator functions (configured in config) accept single or no argument

declare extention_format="$(required_config "hikma.formats.document"})"
declare date_time_format="$(required_config "hikma.formats.date_time"})"
declare date_format="$(required_config "hikma.formats.date"})"

# Generate slug from input text
# $1 - string for which slug to be created
# Returns: sanitized slug
_slug() {
    local subject=$1

    if [[ -z "$1" ]]; then
        return ${hikma_code_wrong_input}
    fi

    local slug=$(echo "$subject" | tr '[:upper:]' '[:lower:]' | 
                 sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | 
                 sed 's/^-//' | sed 's/-$//' | head -c 30)

    echo ${slug}
}

# Generate standard timestamp
# Returns: formatted timestamp string based on hikma.formats.date_time
_timestamp() {
    echo $(date +"${date_time_format}")
}

# Generate standard date format
# Returns: formatted date string based on hikma.formats.date
_date() {
    echo $(date +"${date_format}")
}

# Generate a default name for items
# $1: Item type (optional)
# $2: Title (optional)
# Returns: formatted filename using timestamp
gen_default_name() {
    local item_type="${1:-}"
    local title="${2:-untitled}"
    echo "${item_type}-$(_timestamp)-$(_slug "${title}").${extention_format}"
}

# Generate a filename for email notes
# $1: Email subject (optional)
# Returns: formatted filename using subject as slug
gen_email_name() {
    gen_default_name "email" "$1"
}

# Generate a filename for meeting notes
# $1: Meeting subject (optional)
# Returns: formatted filename with timestamp and slug
gen_meeting_name() {
    gen_default_name "meeting" "$1"
}

# Generate a filename for daily journal
# Returns: formatted filename with date
gen_journal_name() {
    echo "journal-$(_date)${extention_format}"
}

# Generate a filename for index notes
# $1: Title (optional)
# Returns: formatted filename with timestamp and slug
gen_index_note_name() {
    gen_default_name "index" "$1"
}

# Generate a filename for concept notes
# $1: Title (optional)
# Returns: formatted filename with timestamp and slug
gen_concept_note_name() {
    gen_default_name "concept" "$1"
}

# Generate a filename for task notes
# $1: Title (optional)
# Returns: formatted filename with timestamp and slug
gen_task_name() {
    gen_default_name "task" "$1"
}

