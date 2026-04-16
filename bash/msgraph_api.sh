#!/bin/bash

# Microsoft Graph API

msgraph_token=$(jq --raw-output '.accessToken // empty' ~/.msgraph/config.json 2>/dev/null);
msgraph_url="https://graph.microsoft.com/v1.0"

# Token Retrieval

function msgraphSetCredentials() {
    # Stores credentials to ~/.msgraph/config.json
    # Arguments: ($1) tenantId ($2) clientId ($3) clientSecret

    mkdir -p ~/.msgraph
    local msCredentialsFile="~/.msgraph/config.json"
    if [ ! -s "$msCredentialsFile" ] || ! jq empty "$msCredentialsFile" > /dev/null 2>&1; then
        mkdir --parents ~/.msgraph
        echo "Creating new credentials file $msCredentialsFile" >&2
        echo '{}' > "$msCredentialsFile"
    fi
    jq --arg tenant "$1" --arg client "$2" --arg secret "$3" \
        '.tenantId = $tenant | .clientId = $client | .clientSecret = $secret' \
        "$msCredentialsFile" > "$msCredentialsFile.tmp" && \
        mv "$msCredentialsFile.tmp" "$msCredentialsFile"
}

function msgraphGetTokenClientCredentials() {
    # Gets a token using client credentials (service principal) flow
    # Reads tenantId, clientId, clientSecret from ~/.msgraph/config.json
    # Saves access_token, refresh_token, and expiration time to config.json

    local tenant_id=$(jq --raw-output '.tenantId' ~/.msgraph/config.json)
    local client_id=$(jq --raw-output '.clientId' ~/.msgraph/config.json)
    local client_secret=$(jq --raw-output '.clientSecret' ~/.msgraph/config.json)

    local response=$(curl --silent --request POST \
        "https://login.microsoftonline.com/$tenant_id/oauth2/v2.0/token" \
        --data "client_id=$client_id" \
        --data "client_secret=$client_secret" \
        --data "scope=https://graph.microsoft.com/.default" \
        --data "grant_type=client_credentials")

    msgraphSaveTokenResponse "$response"
}

function msgraphGetTokenDeviceFlow() {
    # Gets a token using device code flow (interactive user authentication)
    # Reads tenantId, clientId from ~/.msgraph/config.json
    # Saves access_token, refresh_token, and expiration time to config.json

    local tenant_id=$(jq --raw-output '.tenantId' ~/.msgraph/config.json)
    local client_id=$(jq --raw-output '.clientId' ~/.msgraph/config.json)

    # Get device code
    local device_response=$(curl --silent --request POST \
        "https://login.microsoftonline.com/$tenant_id/oauth2/v2.0/devicecode" \
        --data "client_id=$client_id" \
        --data "scope=https://graph.microsoft.com/.default")

    local device_code=$(echo "$device_response" | jq -r '.device_code')
    local user_code=$(echo "$device_response" | jq -r '.user_code')
    local verification_uri=$(echo "$device_response" | jq -r '.verification_uri')

    echo "Visit: $verification_uri"
    echo "Code: $user_code"
    echo ""

    # Poll for token
    local token_response=$(curl --silent --request POST \
        "https://login.microsoftonline.com/$tenant_id/oauth2/v2.0/token" \
        --data "client_id=$client_id" \
        --data "device_code=$device_code" \
        --data "grant_type=urn:ietf:params:oauth:grant-type:device_flow")

    msgraphSaveTokenResponse "$token_response"
}

function msgraphSaveTokenResponse() {
    # Saves token response (with access_token, refresh_token, expires_in) to ~/.msgraph/config.json
    # Expects argument ($1) to be the full token response JSON

    mkdir -p ~/.msgraph
    local now=$(date +%s)
    local expires_in=$(echo "$1" | jq -r '.expires_in // 3600' | grep -o '^[0-9]*')
    local expires_at=$((now + expires_in))

    jq --arg access_token "$(echo "$1" | jq -r '.access_token')" \
        --arg refresh_token "$(echo "$1" | jq -r '.refresh_token // empty')" \
        --arg expires_at "$expires_at" \
        '.accessToken = $access_token | .refreshToken = $refresh_token | .expiresAt = $expires_at' \
        ~/.msgraph/config.json > ~/.msgraph/config.json.tmp && \
        mv ~/.msgraph/config.json.tmp ~/.msgraph/config.json
    msgraph_token=$(echo "$1" | jq -r '.access_token')
    echo "$1" | jq 'del(.access_token, .refresh_token, .id_token)'
}

function msgraphRefreshToken() {
    # Refreshes the access token using the refresh token
    # Reads clientId, refreshToken from ~/.msgraph/config.json

    local tenant_id=$(jq --raw-output '.tenantId' ~/.msgraph/config.json)
    local client_id=$(jq --raw-output '.clientId' ~/.msgraph/config.json)
    local client_secret=$(jq --raw-output '.clientSecret // empty' ~/.msgraph/config.json)
    local refresh_token=$(jq --raw-output '.refreshToken' ~/.msgraph/config.json)

    if [[ -z "$refresh_token" || "$refresh_token" == "null" ]]; then
        echo "Error: No refresh token found" >&2
        return 1
    fi

    local response=$(curl --silent --request POST \
        "https://login.microsoftonline.com/$tenant_id/oauth2/v2.0/token" \
        --data "client_id=$client_id" \
        --data "client_secret=$client_secret" \
        --data "refresh_token=$refresh_token" \
        --data "grant_type=refresh_token" \
        --data "scope=https://graph.microsoft.com/.default")

    msgraphSaveTokenResponse "$response"
    echo "Token refreshed"
}

function msgraphSaveToken() {
    # Saves a token to ~/.msgraph/config.json
    # Expects argument ($1) to be the token

    mkdir -p ~/.msgraph
    jq --arg token "$1" '.accessToken = $token' ~/.msgraph/config.json > ~/.msgraph/config.json.tmp && mv ~/.msgraph/config.json.tmp ~/.msgraph/config.json
    msgraph_token="$1"
}

# General

function msgraphOp() {
    # Executes a curl request for the given method ($1) and path ($2)
    # Expects env: msgraph_token, msgraph_url

    curl --silent --show-error --header 'Content-Type: application/json' --header "Authorization: Bearer $msgraph_token" \
        --request "$1" "$msgraph_url/$2"
}

function msgraphDataOp() {
    # Executes a curl request for the given method ($1), path ($2) and data ($3)
    # Expects env: msgraph_token, msgraph_url

    curl --silent --show-error --header 'Content-Type: application/json' --header "Authorization: Bearer $msgraph_token" \
        --request "$1" "$msgraph_url/$2" \
        --data "$3"
}

alias msgt-lcc='msgraphGetTokenClientCredentials'
alias msgt-lu='msgraphGetTokenDeviceFlow'
alias msgl-r='msgraphRefreshToken'

# User

function msgraphMe() {
    # Gets the current authenticated user's information
    # Expects env: msgraph_token, msgraph_url

    msgraphOp "GET" "me"
}

function msgraphGetUser() {
    # Gets a user by id or userPrincipalName ($1)
    # Expects env: msgraph_token, msgraph_url

    msgraphOp "GET" "users/$1"
}

alias msgu-me='msgraphMe'
alias msgu-g='msgraphGetUser'
