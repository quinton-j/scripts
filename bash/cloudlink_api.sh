#!/bin/bash

# CloudLink API

# General

function oDataFilter() {
    # Constructs an OData filter chain for the given operator ($1), property ($2) and following values

    local f="";
    for value in ${@:3}; do 
        f="$f%20$1%20$2%20eq%20%27$value%27";
    done;

    f="${f/\%20or\%20/}";
    echo $f;
}

function clOp() {
    # Executes a curl request with the CL auth_token for the given method ($1) and URL ($2)
    # Expects env: auth_token

    curl --header 'Content-Type: application/json' --header "Authorization: Bearer $auth_token" \
        --request $1 $2;
}

function clDataOp() {
    # Executes a curl request with the CL auth_token for the given method ($1) URL ($2) and data ($3)
    # Expects env: auth_token

    curl --header 'Content-Type: application/json' --header "Authorization: Bearer $auth_token" \
        --request $1 $2 \
        --data $3
}

# Auth API

function clAuthOp() {
    # Executes a curl request with the CL auth_token for the given method ($1) auth resource ($2)
    # Expects env: auth_token, cloud

    clOp $1 "https://authentication$cloud.api.mitel.io/2017-09-01/$2"
}

function clAuthDataOp() {
    # Executes a curl request with the CL auth_token for the given method ($1) auth resource ($2) and data ($3)
    # Expects env: auth_token, cloud

    clDataOp $1 "https://authentication$cloud.api.mitel.io/2017-09-01/$2" $3
}

function clAuthPostToken() {
    # Executes a curl request with the CL auth_token for the grant_type ($1) and params ($2)
    # Expects env: auth_token, cloud

    clAuthDataOp POST "token" "{\"grant_type\":\"$1\",$2}"
}

function clAuthLoginPassword() {
    # Executes a curl request with the CL auth_token for the username ($1), password ($2), and accountId ($3)
    # Expects env: auth_token, cloud

    read -r -p $'Enter your username and accountId: \n' uname accid
    read -r -p $'Enter your password: \n' -s pass

    clAuthPostToken "password" "\"username\":\"$uname\",\"password\":\"$pass\",\"account_id\":\"$accid\"" > token.tmp
    unset pass uname accid
    auth_token=$(jq -r '.access_token' token.tmp)
    rm token.tmp
    clAuthOp GET token | jq '.'
}

# Admin API

function clAdminOp() {
    # Executes a curl request with the CL auth_token for the given method ($1) admin resource ($2)
    # Expects env: auth_token, cloud

    clOp $1 "https://admin$cloud.api.mitel.io/2017-09-01/$2"
}

function clAdminDataOp() {
    # Executes a curl request with the CL auth_token for the given method ($1) admin resource ($2) and data ($3)
    # Expects env: auth_token, cloud

    clDataOp $1 "https://admin$cloud.api.mitel.io/2017-09-01/$2" $3
}

function clGetAccounts() {
    # Gets accounts with optional query params ($1)
    # Expects env: auth_token, cloud

    clAdminOp GET "accounts?\$expand=tags$1"
}

function clGetAccountsContainingName() {
    # Gets accounts with name variants and optional query params ($1)
    # Expects env: auth_token, cloud

    local casedNames=($1 ${1,,} ${1^^} ${1^});

    local filter='';
    for name in ${casedNames[*]}; do
         filter+="substringof(name,'$name')%20or%20";
    done;

    clAdminOp GET "accounts?\$filter=${filter::-8}";
}

function clGetAccount() {
    # Gets the account for the provided accountId ($1)
    # Expects env: auth_token, cloud

    clAdminOp GET "accounts/$1?\$expand=tags"
}

function clDeleteAccount() {
    # Deletes the account for the provided accountId ($1)
    # Expects env: auth_token, cloud

    clAdminOp DELETE "accounts/$1?hard=true"
}

function clPutAccount() {
    # Updates the accountId ($1) with body ($2)
    # Expects env: auth_token, cloud

    clAdminDataOp PUT "accounts/$1" $2
}

function clGetAccountByOrganizationId() {
    # Gets the account for the provided organizationId ($1)
    # Expects env: auth_token, cloud

    clAdminOp GET "accounts?\$expand=tags&\$filter=organizationId%20eq%20'$1'" \
        | jq '._embedded.items[0] | {name,accountId,accountNumber,partnerId,organizationId,sapId:.tags.mitel_connect_refs.sap_references_primary_1}'
}

function clGetAccountsByPartnerId() {
    # Gets the accounts for the provided partnerIds ($1)
    # Expects env: auth_token, cloud

    clAdminOp GET "accounts?\$expand=tags&\$filter=partnerId%20eq%20'$1'" \
        | jq '._embedded.items | map({name,accountId,accountNumber,partnerId,organizationId,sapId:.tags.mitel_connect_refs.sap_references_primary_1,createdOn,createdBy})'
}

function clGetUsersByRole() {
    # Gets the account for the provided accountId ($1)
    # Expects env: auth_token, cloud

    clAdminOp GET "accounts/$1/users$2" | jq  '._embedded.items//[] | group_by(.role) | map({accountId:.[0].accountId,role:.[0].role,users:(. | del(.[].sipPassword)),count:length })'
}

function clGetPartner() {
    # Gets the partner for the provided partnerId ($1)
    # Expects env: auth_token, cloud

    clAdminOp GET "partners/$1"
}

function clGetPartners() {
    # Gets partners for the provided accountId ($1)
    # Expects env: auth_token, cloud

    clAdminOp GET "partners$1"
}

function clPutPartner() {
    # Updates the partnertId ($1) with body ($2)
    # Expects env: auth_token, cloud

    clAdminDataOp PUT "partners/$1" $2
}

function clGetPolicies() {
    # Gets policies in accountId ($1), and optional query params ($2)
    # Expects env: auth_token, cloud

    clAdminOp GET "accounts/$1/policies$2"
}

function clGetPolicy() {
    # Gets policy with accountId ($1) and policyId ($2)
    # Expects env: auth_token, cloud

    clAdminOp GET "accounts/$1/policies/$2"
}

function clGetPolicyStatements() {
    # Gets policy statements for accountId ($1) and policyId ($2)
    # Expects env: auth_token, cloud

    clAdminOp GET "accounts/$1/policies/$2/statements"
}

function clGetPolicyStatement() {
    # Gets policy statement for accountId ($1), policyId ($2), and statementId ($3)
    # Expects env: auth_token, cloud

    clAdminOp GET "accounts/$1/policies/$2/statements/$3"
}

function clPostPolicyStatements() {
    # Updates the user with accountId ($1), policyId ($2), and body ($3)
    # Expects env: auth_token, cloud

    clAdminDataOp POST "accounts/$1/policies/$2/statements" $3
}

function clPostPolicyStatement() {
    # Updates the policy statement with accountId ($1), policyId ($2), statementId ($3), effect ($4), action ($5), and resource ($6)
    # Expects env: auth_token, cloud

    local data="{\"statementId\":\"$3\",\"effect\":\"$4\",\"action\":[\"$5\"],\"resource\":[\"$6\"]}";

    clPostPolicyStatements $1 $2 $data
}

function clPostChatMicroAccountPolicyStatement() {
    # Updates the policy statement with accountId ($1), statementId ($2) effect ($3)
    # Expects env: auth_token, cloud

    clPostPolicyStatement $1 account $2 $3 '*' "https://mitel.io/auth/conversations/features/$2"
}

function clGetUsers() {
    # Gets users for accountId ($1) and optional query params ($2)
    # Expects env: auth_token, cloud

    clAdminOp GET "accounts/$1/users$2" | jq '._embedded.items//[] | map(del(.sipPassword))'
}

function clGetUser() {
    # Gets user for accountId ($1) and userId ($2)
    # Expects env: auth_token, cloud

    clAdminOp GET "accounts/$1/users/$2?\$expand=tags" | jq 'del(.sipPassword)'
}

function clPutUser() {
    # Updates the user with accountId ($1), userId ($2), and body ($3)
    # Expects env: auth_token, cloud

    clAdminDataOp PUT "accounts/$1/users/$2" $3 | jq 'del(.sipPassword)'
}

function clDeleteUser() {
    # Deletes the user with accountId ($1), userId ($2)
    # Expects env: auth_token, cloud

    clAdminOp DELETE "accounts/$1/users/$2"
}

function clPutUserTag() {
    # Updates the user with accountId ($1), userId ($2), tagId ($3) and tag value ($4)
    # Expects env: auth_token, cloud

    clAdminDataOp PUT "accounts/$1/users/$2/tags/$3" $4
}

function clDeleteUserTag() {
    # Updates the user with accountId ($1), userId ($2) and tagId ($3)
    # Expects env: auth_token, cloud

    clAdminOp DELETE "accounts/$1/users/$2/tags/$3"
}

function clPatchUsers() {
    # Updates the userIds (${@:4}) in accountId ($1), op ($2) command ($3)
    # Expects env: auth_token, cloud

    local data='{"operations":[';
    for userId in ${@:4};
        do data="${data}{\"op\":\"$2\",\"id\":\"${userId}\",\"body\":$3},";
    done;
    data="${data%?}]}";

    clAdminDataOp PATCH "accounts/$1/users" "$data" | jq '.operations//[] | map({statusCode,corrId:.headers."x-mitel-correlation-id",body:(.body | del(.sipPassword))})'
}

function clGetClients() {
    # Gets the clients for the provided accountId ($1)
    # Expects env: auth_token, cloud

    clAdminOp GET "accounts/$1/clients$2" | jq  '._embedded.items//[]'
}

function clGetClient() {
    # Gets the clients for the provided accountId ($1) and clientId ($2)
    # Expects env: auth_token, cloud

    clAdminOp GET "accounts/$1/clients$2"
}

# Director API

function clGetIdentities() {
    # Gets identities with the id ($1)
    # Expects env: auth_token, cloud

    clOp GET "https://director$cloud.api.mitel.io/2018-07-01/identities?\$expand=null$1"
}

# Chat API

function clChatOp() {
    # Executes a curl get request with the CL auth_token for the given method ($1) chat subresource ($2)
    # Expects env: auth_token, cloud

    clOp $1 "https://chat$cloud.api.mitel.io/2017-09-01/$2"
}

function clChatDataOp() {
    # Executes a chat data request with the CL auth_token for the given method ($1) subpath  ($2) and data ($3)
    # Expects env: auth_token, cloud

    clDataOp $1 "https://chat$cloud.api.mitel.io/2017-09-01/$2" $3
}

function clChatDataOp() {
    # Executes a curl POST request with the CL auth_token for the given admin resource ($1) and data ($2)
    # Expects env: auth_token, cloud

    clChatDataOp POST $1 $2
}

function clGetConversations() {
    # Gets user conversations for the logged in user
    # Expects env: auth_token, cloud

    clChatOp GET "conversations$1"
}

function clGetParticipants() {
    # Gets participants for the given conversationId ($1)
    # Expects env: auth_token, cloud

    clChatOp GET "conversations/$1/participants"
}

function clPostMessage() {
    # Post a message for the given conversationId ($1) with body ($2)
    # Expects env: auth_token, cloud

    clChatDataOp POST "conversations/$1/messages" $2
}

function clPostMessageText() {
    # Post a message for the given conversationId ($1) with text ($2)
    # Expects env: auth_token, cloud

    clPostMessage $1 "{\"body\":\"$2\"}"
}

# Event history API

function clAnalyticsOp() {
    # Executes a curl get request with the CL auth_token for the given method ($1) subresource ($2)
    # Expects env: auth_token, cloud

    clOp $1 "https://analytics$cloud.api.mitel.io/2020-06-19/$2"
}

function clEventHistoryQuery() {
    # Executes a queries the event history with the CL auth_token by source ($1), subject ($2), date exceeding ($3) and optional further filters ($4)
    # Expects env: auth_token, cloud

    clAnalyticsOp GET "events-records?\$filter=source%20eq%20'$1'%20and%20subject%20eq%20'$2'%20and%20occurredOn%20gt%20'$3'$4"
}

# Aliases

alias odfilter="oDataFilter $@"

alias cltok-g="clAuthOp GET token"
alias cltok-lp="clAuthLoginPassword $@"

alias clacc-l="clGetAccounts $@"
alias clacc-g="clGetAccount $@"
alias clacc-u="clPutAccount $@"
alias clacc-d="clDeleteAccount $@"
alias clpart-g="clGetPartner $@"
alias clpart-l="clGetPartners $@"
alias clpart-u="clPutPartner $@"
alias clacc-gbo="clGetAccountByOrganizationId $@"
alias clacc-lbp="clGetAccountsByPartnerId $@"
alias clacc-lbn="clGetAccountsContainingName $@"

alias clpol-l="clGetPolicies $@"
alias clpol-g="clGetPolicy $@"
alias clstate-l="clGetPolicyStatements $@"
alias clstate-g="clGetPolicyStatement $@"
alias clstate-uc="clPostChatMicroAccountPolicyStatement $@"

alias cluser-l="clGetUsers $@"
alias cluser-lbr="clGetUsersByRole $@"
alias cluser-g="clGetUser $@"
alias cluser-u="clPutUser $@"
alias cluser-d="clDeleteUser $@"
alias clutag-u="clPutUserTag $@"
alias clutag-d="clDeleteUserTag $@"

alias clclient-l="clGetClients $@"
alias clclient-g="clGetClient $@"

alias clid-l="clGetIdentities $@"

alias clconv-l='clChatOp GET conversations'
alias cluconv-l='clChatOp GET users/me/conversations'
alias clcpart-l="clGetParticipants $@"
alias clcmsg-c="clPostMessageText $@"

alias clehis-l="clEventHistoryQuery $@"
