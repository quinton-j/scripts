#!/bin/bash

# Jira API

jira_token=$(jq --raw-output '.apiKey' ~/.jira/config.json);
jira_email=$(jq --raw-output '.jiraEmail' ~/.jira/config.json);
jira_url=$(jq --raw-output '.jiraUrl' ~/.jira/config.json);
jira_auth=$(echo -n "$jira_email:$jira_token" | base64 --wrap=0);

# General

function jiraOp() {
    # Executes a curl request for the given method ($1) and path ($2)
    # Expects env: jira_url, jira_auth

    curl --silent --show-error --header 'Content-Type: application/json' --header "Authorization: Basic $jira_auth" \
        --request "$1" "$jira_url/rest/api/2/$2"
}

function jiraDataOp() {
    # Executes a curl request for the given method ($1), path ($2) and data ($3)
    # Expects env: jira_url, jira_auth

    curl --silent --show-error --header 'Content-Type: application/json' --header "Authorization: Basic $jira_auth" \
        --request "$1" "$jira_url/rest/api/2/$2" \
        --data "$3"
}

function jiraSearchOp() {
    # Executes a curl request against the search API for the given path ($1) and data ($2)
    # Search lives on v3 only, Atlassian removed /rest/api/2/search, so this cannot use jiraDataOp
    # Expects env: jira_url, jira_auth

    curl --silent --show-error --header 'Content-Type: application/json' --header "Authorization: Basic $jira_auth" \
        --request "POST" "$jira_url/rest/api/3/search/$1" \
        --data "$2"
}

function jiraSearch() {
    # Searches for issues using the given JQL query ($1), optional comma separated field names
    # ($2, default '*navigable') and optional next page token ($3)
    # Returns one page. The API caps a page at 100 issues once fields are named, and it caps
    # silently, so use jiraSearchAll for a query that can match more
    # Expects env: jira_url, jira_auth

    local jql="$1"
    local fields="${2:-*navigable}"
    local token="$3"

    jiraSearchOp "jql" "$(jq --null-input --compact-output \
        --arg jql "$jql" --arg fields "$fields" --arg token "$token" \
        '{jql: $jql, maxResults: 100, fields: ($fields | split(","))}
            + (if $token == "" then {} else {nextPageToken: $token} end)')"
}

function jiraSearchAll() {
    # Searches for issues using the given JQL query ($1) and optional comma separated field
    # names ($2), following the page tokens to collect every match
    # Expects env: jira_url, jira_auth

    local jql="$1"
    local fields="$2"

    local page
    local token=""
    local readCount=0
    local totalCount=0
    local tmpfile
    tmpfile=$(mktemp)

    while true; do
        page=$(jiraSearch "$jql" "$fields" "$token")

        if [ "$(echo "$page" | jq --raw-output 'has("issues")')" != "true" ]; then
            rm --force "$tmpfile"
            echo "$page"
            return 1
        fi

        readCount=$(echo "$page" | jq '.issues | length')
        echo "$page" | jq --compact-output '.issues[]' >> "$tmpfile"
        totalCount=$((totalCount + readCount))
        echo "Read $readCount issue(s); total collected: $totalCount" >&2

        token=$(echo "$page" | jq --raw-output '.nextPageToken // empty')

        if [ -z "$token" ]; then
            break
        fi
    done

    jq --slurp '{issues: ., total: length}' "$tmpfile"
    rm --force "$tmpfile"
}

function jiraSearchCount() {
    # Gets the approximate count of issues matching the given JQL query ($1)
    # The search response no longer carries a total, so a count takes its own call
    # Expects env: jira_url, jira_auth

    jiraSearchOp "approximate-count" "$(jq --null-input --compact-output --arg jql "$1" '{jql: $jql}')"
}

alias jira-me='jiraOp "GET" "myself"'

# Issues

function jiraGetIssue() {
    # Gets an issue by key ($1)
    # Expects env: jira_url, jira_token

    jiraOp "GET" "issue/$1"
}

function jiraCreateIssue() {
    # Creates an issue with the given JSON payload ($1)
    # Expects env: jira_url, jira_token

    jiraDataOp "POST" "issue" "$1"
}

function jiraUpdateIssue() {
    # Updates an issue ($1) with the given JSON payload ($2)
    # Expects env: jira_url, jira_token

    jiraDataOp "PUT" "issue/$1" "$2"
}

function jiraTransitionIssue() {
    # Transitions an issue ($1) to the given transition id ($2)
    # Expects env: jira_url, jira_token

    jiraDataOp "POST" "issue/$1/transitions" "{\"transition\": {\"id\": \"$2\"}}"
}

function jiraGetTransitions() {
    # Gets available transitions for an issue ($1)
    # Expects env: jira_url, jira_token

    jiraOp "GET" "issue/$1/transitions"
}

function jiraAddComment() {
    # Adds a comment to an issue ($1) with the given body ($2)
    # Expects env: jira_url, jira_token

    jiraDataOp "POST" "issue/$1/comment" "{\"body\": \"$2\"}"
}

function jiraAssignIssue() {
    # Assigns an issue ($1) to a user ($2)
    # Expects env: jira_url, jira_token

    jiraDataOp "PUT" "issue/$1/assignee" "{\"accountId\": \"$2\"}"
}

alias jira-gi='jiraGetIssue'
alias jira-ci='jiraCreateIssue'
alias jira-ui='jiraUpdateIssue'
alias jira-ti='jiraTransitionIssue'
alias jira-gt='jiraGetTransitions'
alias jira-ac='jiraAddComment'
alias jira-ai='jiraAssignIssue'
alias jira-s='jiraSearch'
alias jira-sa='jiraSearchAll'
alias jira-sc='jiraSearchCount'

# Sprints / Boards (Agile API)

function jiraAgileOp() {
    # Executes a curl request against the Agile API for the given method ($1) and path ($2)
    # Expects env: jira_url, jira_auth

    curl --silent --show-error --header 'Content-Type: application/json' --header "Authorization: Basic $jira_auth" \
        --request "$1" "$jira_url/rest/agile/1.0/$2"
}

function jiraListBoards() {
    # Lists all boards, optional extra params ($1) e.g. '&name=My%20Board&type=scrum&projectKeyOrId=CL'
    # Expects env: jira_url, jira_auth

    jiraAgileOp "GET" "board?maxResults=1000$1"
}

function jiraGetSprint() {
    # Gets a sprint by id ($1)
    # Expects env: jira_url, jira_auth

    jiraAgileOp "GET" "sprint/$1"
}

function jiraListBoardSprints() {
    # Lists sprints for a board ($1), optional extra params ($2) e.g. '&state=active,future'
    # Expects env: jira_url, jira_auth

    jiraAgileOp "GET" "board/$1/sprint?maxResults=1000$2"
}

function jiraListSprintIssues() {
    # Lists issues for a sprint ($1), optional extra params ($2) e.g. '&jql=assignee=currentUser()'
    # Expects env: jira_url, jira_auth

    jiraAgileOp "GET" "sprint/$1/issue?maxResults=1000$2"
}

alias jira-lb='jiraListBoards'
alias jira-gs='jiraGetSprint'
alias jira-lbs='jiraListBoardSprints'
alias jira-lsi='jiraListSprintIssues'
