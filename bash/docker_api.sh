#!/bin/bash

dockerGetLibrary() {
    # Gets the Docker library with name ($1)

    curl --silent "https://registry.hub.docker.com/v2/repositories/library/$1"
}

dockerGetLibraryTags() {
    # Gets the Docker library tags for library ($1)

    curl --silent "https://registry.hub.docker.com/v2/repositories/library/$1/tags?page_size=100" |
        jq '.results | map(select(.tag_status == "active")) | sort_by(.last_updated) | reverse'
}

alias doc-ll='curl --silent https://registry.hub.docker.com/v2/repositories/library/?page_size=100'
alias doc-gl='dockerGetLibrary $@'
alias doc-glt='dockerGetLibraryTags $@'
