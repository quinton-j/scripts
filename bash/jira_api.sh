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

function jiraGetIssueFields() {
    # Gets only the given comma separated fields ($2) of an issue ($1), to keep the payload small
    # Expects env: jira_url, jira_auth

    jiraOp "GET" "issue/$1?fields=$2"
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
    # Transitions an issue ($1) to the given transition id ($2), with an optional resolution name ($3) for a
    # transition that requires one, such as Done
    # Expects env: jira_url, jira_token

    jiraDataOp "POST" "issue/$1/transitions" "$(jq --null-input --compact-output --arg id "$2" --arg resolution "${3:-}" \
        '{transition: {id: $id}} + (if $resolution == "" then {} else {fields: {resolution: {name: $resolution}}} end)')"
}

function jiraGetTransitions() {
    # Gets available transitions for an issue ($1)
    # Expects env: jira_url, jira_token

    jiraOp "GET" "issue/$1/transitions"
}

function jiraAddComment() {
    # Adds a comment to an issue ($1) with the given body ($2)
    # Expects env: jira_url, jira_token

    jiraDataOp "POST" "issue/$1/comment" "$(jq --null-input --compact-output --arg body "$2" '{body: $body}')"
}

function jiraAddCommentFile() {
    # Adds a comment to an issue ($1) with the body read from a file ($2), in Jira wiki markup
    # The body is JSON-encoded and streamed, so quotes, newlines and a long log need no escaping
    # Expects env: jira_url, jira_auth

    jq --null-input --compact-output --rawfile body "$2" '{body: $body}' |
        curl --silent --show-error --header 'Content-Type: application/json' --header "Authorization: Basic $jira_auth" \
            --request POST "$jira_url/rest/api/2/issue/$1/comment" \
            --data @-
}

function jiraUpdateCommentFile() {
    # Replaces the body of a comment ($2) on an issue ($1) with the body read from a file ($3), in Jira wiki markup
    # Expects env: jira_url, jira_auth

    jq --null-input --compact-output --rawfile body "$3" '{body: $body}' |
        curl --silent --show-error --header 'Content-Type: application/json' --header "Authorization: Basic $jira_auth" \
            --request PUT "$jira_url/rest/api/2/issue/$1/comment/$2" \
            --data @-
}

function jiraGetComments() {
    # Gets every comment of an issue ($1), following the pages
    # A default fetch returns one page of the most recent comments, and drops the earliest history of a long thread
    # Expects env: jira_url, jira_auth

    local startAt=0
    local total=1
    local page
    local tmpfile
    tmpfile=$(mktemp)

    while [ "$startAt" -lt "$total" ]; do
        page=$(jiraOp "GET" "issue/$1/comment?maxResults=100&startAt=$startAt")

        if [ "$(echo "$page" | jq --raw-output 'has("comments")')" != "true" ]; then
            rm --force "$tmpfile"
            echo "$page"
            return 1
        fi

        echo "$page" | jq --compact-output '.comments[]' >> "$tmpfile"
        total=$(echo "$page" | jq '.total')
        startAt=$((startAt + $(echo "$page" | jq '.comments | length')))

        if [ "$(echo "$page" | jq '.comments | length')" -eq 0 ]; then
            break
        fi
    done

    jq --slurp '{comments: ., total: length}' "$tmpfile"
    rm --force "$tmpfile"
}

function jiraAddLabels() {
    # Adds one or more labels ($2..) to an issue ($1), and keeps the labels it already has
    # Expects env: jira_url, jira_auth

    local key=$1
    shift

    jiraDataOp "PUT" "issue/$key" "$(jq --null-input --compact-output '{update: {labels: ($ARGS.positional | map({add: .}))}}' --args "$@")"
}

function jiraAssignIssue() {
    # Assigns an issue ($1) to a user ($2)
    # Expects env: jira_url, jira_token

    jiraDataOp "PUT" "issue/$1/assignee" "{\"accountId\": \"$2\"}"
}

alias jira-gi='jiraGetIssue'
alias jira-gif='jiraGetIssueFields'
alias jira-ci='jiraCreateIssue'
alias jira-ui='jiraUpdateIssue'
alias jira-ti='jiraTransitionIssue'
alias jira-gt='jiraGetTransitions'
alias jira-ac='jiraAddComment'
alias jira-acf='jiraAddCommentFile'
alias jira-ucf='jiraUpdateCommentFile'
alias jira-gc='jiraGetComments'
alias jira-al='jiraAddLabels'
alias jira-ai='jiraAssignIssue'
alias jira-s='jiraSearch'
alias jira-sa='jiraSearchAll'
alias jira-sc='jiraSearchCount'

# Attachments

function jiraListAttachments() {
    # Lists the attachments of an issue ($1), one line each: id, file name, MIME type and size
    # Expects env: jira_url, jira_auth

    jiraGetIssueFields "$1" "attachment" |
        jq --raw-output '.fields.attachment[] | [.id, .filename, .mimeType, .size] | @tsv'
}

function jiraDownloadAttachment() {
    # Downloads an attachment by id ($1) to a file ($2)
    # --location is required, because the content endpoint redirects to a signed URL
    # Expects env: jira_url, jira_auth

    curl --silent --show-error --fail --location --header "Authorization: Basic $jira_auth" \
        --output "$2" "$jira_url/rest/api/2/attachment/content/$1"
}

alias jira-la='jiraListAttachments'
alias jira-da='jiraDownloadAttachment'

# Remote links

function jiraGetRemoteLinks() {
    # Gets the remote (web) links of an issue ($1)
    # Expects env: jira_url, jira_auth

    jiraOp "GET" "issue/$1/remotelink"
}

function jiraAddRemoteLink() {
    # Adds a remote (web) link with a URL ($2) and a title ($3) to an issue ($1)
    # Expects env: jira_url, jira_auth

    jiraDataOp "POST" "issue/$1/remotelink" "$(jq --null-input --compact-output --arg url "$2" --arg title "$3" \
        '{object: {url: $url, title: $title}}')"
}

alias jira-grl='jiraGetRemoteLinks'
alias jira-arl='jiraAddRemoteLink'

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
