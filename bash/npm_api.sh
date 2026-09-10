#!/bin/bash

# npm

alias n-vp="npm version patch --no-git-tag-version";
alias n-ls="jq '.scripts' package.json";
alias n-rs="npm run $@";
alias nr="n-rs $@";
alias n-ld="jq '.dependencies' package.json";
alias n-ldd="jq '.devDependencies' package.json";

function npm_run_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local scripts

    if [ -f "package.json" ]; then
        scripts=$(jq --raw-output '.scripts | keys[]' package.json 2>/dev/null)
        COMPREPLY=($(compgen -W "${scripts}" -- "${cur}"))
    fi
}

complete -F npm_run_complete nr
