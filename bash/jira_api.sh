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

function jiraSearch() {
    # Searches for issues using the given JQL query ($1)
    # Expects env: jira_url, jira_auth

    jiraDataOp "POST" "search" "{\"jql\": \"$1\", \"maxResults\": 1000}"
}

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

# Sprints / Boards (Agile API)

function jiraAgileOp() {
    # Executes a curl request against the Agile API for the given method ($1) and path ($2)
    # Expects env: jira_url, jira_auth

    curl --silent --show-error --header 'Content-Type: application/json' --header "Authorization: Basic $jira_auth" \
        --request "$1" "$jira_url/rest/agile/1.0/$2"
}

function jiraListBoards() {
    # Lists all boards, optional extra params ($1) e.g. '&name=My%20Board&type=scrum'
    # Expects env: jira_url, jira_auth

    jiraAgileOp "GET" "board?maxResults=1000$1"
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

# Aliases

alias jira-gi='jiraGetIssue'
alias jira-ci='jiraCreateIssue'
alias jira-ui='jiraUpdateIssue'
alias jira-ti='jiraTransitionIssue'
alias jira-gt='jiraGetTransitions'
alias jira-ac='jiraAddComment'
alias jira-ai='jiraAssignIssue'
alias jira-s='jiraSearch'
alias jira-lb='jiraListBoards'
alias jira-lbs='jiraListBoardSprints'
alias jira-lsi='jiraListSprintIssues'
alias jira-myself='jiraOp "GET" "myself"'
