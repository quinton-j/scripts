#!/bin/bash

# CloudLink API

# General

function oDataFilter() {
    # Constructs an OData filter chain for the given operator ($1), property ($2) and following values

    local f=""
    for value in ${@:3}; do
        f="$f%20$1%20$2%20eq%20%27$value%27"
    done

    f="${f/\%20or\%20/}"
    echo $f
}

function clOp() {
    # Executes a curl request with the CL auth_token for the given method ($1) and URL ($2)
    # Expects env: auth_token

    curl --silent --header 'Content-Type: application/json' --header "Authorization: Bearer $auth_token" \
        --request $1 $2
}

function clDataOp() {
    # Executes a curl request with the CL auth_token for the given method ($1) URL ($2) and data ($3)
    # Expects env: auth_token

    curl --silent --header 'Content-Type: application/json' --header "Authorization: Bearer $auth_token" \
        --request $1 $2 \
        --data $3
}

alias odfilter="oDataFilter $@"

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
    # Executes a curl request with the CL auth_token by accepting or soliciting username ($1), accountId ($2), and password ($3)
    # Expects env: cloud, clCredentialsFile

    local username=$1
    local accountid=$2
    local password=$3

    if [ -z "$username" ]; then
        read -r -p 'Username: ' username
    fi
    
    if [ -z "$accountid" ]; then
        read -r -p 'AccountId: ' accountid
    fi
    
    if [ -z "$password" ]; then
        read -r -p 'Password: ' -s password
        echo
    fi

    tmpDir=${LOCALAPPDATA:-$TMP}/${USER:-$USERNAME}-cli && mkdir --parents $tmpDir
    local tmpFile=$tmpDir/token.tmp
    clAuthPostToken "password" "\"username\":\"$username\",\"password\":\"$password\",\"account_id\":\"$accountid\"" >$tmpFile
    auth_token=$(jq --raw-output '.access_token' $tmpFile)

    if [ ! -f $clCredentialsFile ]; then
        mkdir --parents ~/.cloudlink
        echo '{}' >$clCredentialsFile
    fi

    jq --arg cloud "${cloud:1}" --argjson token "$(jq --raw-output '{access_token ,refresh_token}' $tmpFile)" \
        '.[$cloud] = $token' $clCredentialsFile >$tmpFile
    mv $tmpFile $clCredentialsFile
    clAuthOp GET token | jq '.'
}

function clListCredentials() {
    # Lists the credentials account for the provided accountId ($1)
    # Expects env: auth_token, cloud

    clAuthOp GET "accounts/$1/credentials$2"
}

function clCreateCredential() {
    # Adds a credential for the provided accountId ($1) and name ($2), type ($3), access restriction ($4), target ($5), and privateKey ($6)
    # Expects env: auth_token, cloud

    clAuthDataOp POST "credentials" "{\"accountId\":\"$1\",\"name\":\"$2\",\"type\":\"$3\",\"accessRestriction\":\"$4\",\"target\":\"$5\",\"privateKey\":$6}"
}

function clUpdateCredential() {
    # Adds a credential for the provided credentialId ($1) and body ($2)
    # Expects env: auth_token, cloud

    clAuthDataOp PUT "credentials/$1" $2
}

function clGetCredential() {
    # Gets the credential for the provided credentialId ($2)
    # Expects env: auth_token, cloud

    clAuthOp GET "credentials/$1"
}

function clDeleteCredential() {
    # Gets the credential for the provided credentialId ($2)
    # Expects env: auth_token, cloud

    clAuthOp DELETE "credentials/$1"
}

function clListApplications() {
    # Lists the applications
    # Expects env: auth_token, cloud

    clAuthOp GET "apps$1"
}

function clGetApplication() {
    # Gets the application for the provided id ($1)
    # Expects env: auth_token, cloud

    clAuthOp GET "applications/$1"
}

function clUpdateApplication() {
    # Gets the application for provided appId ($1) and data ($2)
    # Expects env: auth_token, cloud

    clAuthDataOp PUT "applications/$1" $2
}

function clListIdentityProvders() {
    # Gets the identity providers for account of the token
    # Expects env: auth_token, cloud

    clAuthOp GET "identityProviders"
}

function clGetIdentityProvder() {
    # Gets the identity providers for the provided id ($1)
    # Expects env: auth_token, cloud

    clAuthOp GET "identityProviders/$1"
}

export clCredentialsFile=~/.cloudlink/credentials
alias cltok-g="clAuthOp GET token"
alias cltok-lp="clAuthLoginPassword $@"
alias cltok-clip="echo \$auth_token > /dev/clipboard"
alias cltok-set='auth_token=$(jq --raw-output ".[\"${cloud:1}\"].access_token" $clCredentialsFile)'

alias clcred-l="clListCredentials $@"
alias clcred-c="clCreateCredential $@"
alias clcred-u="clUpdateCredential $@"
alias clcred-g="clGetCredential $@"
alias clcred-d="clDeleteCredential $@"

alias clapp-l="clListApplications $@"
alias clapp-g="clGetApplication $@"
alias clapp-u="clUpdateApplication $@"

alias clsso-sg="clAuthOp GET /saml2/status?username=$@"
alias clidp-l="clListIdentityProvders $@"
alias clidp-g="clGetIdentityProvders $@"

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

function clListAccounts() {
    # List accounts with optional query params ($1)
    # Expects env: auth_token, cloud

    clAdminOp GET "accounts?\$expand=tags$1"
}

function clListAccountsContainingName() {
    # List accounts with name variants and optional query params ($1)
    # Expects env: auth_token, cloud

    local casedNames=($1 ${1,,} ${1^^} ${1^})

    local filter=''
    for name in ${casedNames[*]}; do
        filter+="substringof(name,'$name')%20or%20"
    done

    clAdminOp GET "accounts?\$filter=${filter::-8}"
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

    clAdminOp GET "accounts?\$expand=tags&\$filter=organizationId%20eq%20'$1'" |
        jq '._embedded.items[0] | {name,accountId,accountNumber,partnerId,organizationId,sapId:.tags.mitel_connect_refs.sap_references_primary_1}'
}

function clListAccountsByPartnerId() {
    # Lists the accounts for the provided partnerId ($1) and optional query params ($2)
    # Expects env: auth_token, cloud

    clAdminOp GET "accounts?\$top=10000&\$expand=tags&\$filter=partnerId%20eq%20'$1'" |
        jq '._embedded.items | map({name,accountId,accountNumber,partnerId,organizationId,sapId:.tags.mitel_connect_refs.sap_references_primary_1,createdOn,createdBy})'
}

function clListUsersByRole() {
    # Lists the account for the provided accountId ($1)
    # Expects env: auth_token, cloud

    clAdminOp GET "accounts/$1/users$2" | jq '._embedded.items//[] | group_by(.role) | map({accountId:.[0].accountId,role:.[0].role,users:(. | del(.[].sipPassword)),count:length })'
}

function clGetPartner() {
    # Gets the partner for the provided partnerId ($1)
    # Expects env: auth_token, cloud

    clAdminOp GET "partners/$1"
}

function clListPartners() {
    # Lists partners for the provided accountId ($1)
    # Expects env: auth_token, cloud

    clAdminOp GET "partners$1"
}

function clPutPartner() {
    # Updates the partnertId ($1) with body ($2)
    # Expects env: auth_token, cloud

    clAdminDataOp PUT "partners/$1" $2
}

function clListPolicies() {
    # Lists policies in accountId ($1), and optional query params ($2)
    # Expects env: auth_token, cloud

    clAdminOp GET "accounts/$1/policies$2"
}

function clGetPolicy() {
    # Gets policy with accountId ($1) and policyId ($2)
    # Expects env: auth_token, cloud

    clAdminOp GET "accounts/$1/policies/$2"
}

function clListPolicyStatements() {
    # Lists policy statements for accountId ($1) and policyId ($2)
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

    local data="{\"statementId\":\"$3\",\"effect\":\"$4\",\"action\":[\"$5\"],\"resource\":[\"$6\"]}"

    clPostPolicyStatements $1 $2 $data
}

function clDeletePolicyStatement() {
    # Delete policy statement for accountId ($1), policyId ($2), and statementId ($3)
    # Expects env: auth_token, cloud

    clAdminOp DELETE "accounts/$1/policies/$2/statements/$3"
}

function clPostChatMicroAccountPolicyStatement() {
    # Updates the policy statement with accountId ($1), statementId ($2) effect ($3)
    # Expects env: auth_token, cloud

    clPostPolicyStatement $1 account $2 $3 '*' "https://mitel.io/auth/conversations/features/$2"
}

function clListUsers() {
    # Lists users for accountId ($1) and optional query params ($2)
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

function clPostUser() {
    # Updates the user with accountId ($1), and body ($3)
    # Expects env: auth_token, cloud

    clAdminDataOp POST "accounts/$1/users" $2 | jq 'del(.sipPassword)'
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

    local data='{"operations":['
    for userId in ${@:4}; do
        data="${data}{\"op\":\"$2\",\"id\":\"${userId}\",\"body\":$3},"
    done
    data="${data%?}]}"

    clAdminDataOp PATCH "accounts/$1/users" "$data" | jq '.operations//[] | map({statusCode,corrId:.headers."x-mitel-correlation-id",body:(.body | del(.sipPassword))})'
}

function clListClients() {
    # Lists the clients for the provided accountId ($1)
    # Expects env: auth_token, cloud

    clAdminOp GET "accounts/$1/clients$2" | jq '._embedded.items//[]'
}

function clGetClient() {
    # Gets the clients for the provided accountId ($1) and clientId ($2)
    # Expects env: auth_token, cloud

    clAdminOp GET "accounts/$1/clients/$2"
}

function clListGroups() {
    # Lists the clients for the provided accountId ($1)
    # Expects env: auth_token, cloud

    clAdminOp GET "accounts/$1/groups$2" | jq '._embedded.items//[]'
}

function clGetGroup() {
    # Gets the clients for the provided accountId ($1) and clientId ($2)
    # Expects env: auth_token, cloud

    clAdminOp GET "accounts/$1/groups/$2"
}

alias clacc-l="clListAccounts $@"
alias clacc-g="clGetAccount $@"
alias clacc-u="clPutAccount $@"
alias clacc-d="clDeleteAccount $@"
alias clacc-gbo="clGetAccountByOrganizationId $@"
alias clacc-lbp="clListAccountsByPartnerId $@"
alias clacc-lbn="clListAccountsContainingName $@"

alias clatag-u="clPutAccountTag $@"
alias clatag-d="clDeleteAccountTag $@"

alias clpart-g="clGetPartner $@"
alias clpart-l="clListPartners $@"
alias clpart-u="clPutPartner $@"

alias clpol-l="clListPolicies $@"
alias clpol-g="clGetPolicy $@"
alias clstate-l="clListPolicyStatements $@"
alias clstate-g="clGetPolicyStatement $@"
alias clstate-d="clDeletePolicyStatement $@"
alias clstate-uc="clPostChatMicroAccountPolicyStatement $@"

alias cluser-l="clListUsers $@"
alias cluser-lbr="clListUsersByRole $@"
alias cluser-g="clGetUser $@"
alias cluser-u="clPutUser $@"
alias cluser-c="clPostUser $@"
alias cluser-d="clDeleteUser $@"
alias cluser-mu="clPatchUsers $@"
alias clutag-u="clPutUserTag $@"
alias clutag-d="clDeleteUserTag $@"

alias clclient-l="clListClients $@"
alias clclient-g="clGetClient $@"

alias clgroup-l="clListGroups $@"
alias clgroup-g="clGetGroup $@"

# Director API

function clDirectorOp() {
    # Executes a curl get request with the CL auth_token for the given method ($1) chat subresource ($2)
    # Expects env: auth_token, cloud

    clOp $1 "https://director$cloud.api.mitel.io/2018-07-01/$2"
}

function clDirectorDataOp() {
    # Executes a curl get request with the CL auth_token for the given method ($1) chat subresource ($2)
    # Expects env: auth_token, cloud

    clDataOp $1 "https://director$cloud.api.mitel.io/2018-07-01/$2" $3
}

function clListIdentities() {
    # Lists identities with the id ($1)
    # Expects env: auth_token, cloud

    clDirectorOp GET "identities?\$expand=null$1"
}

function clListServices() {
    # Lists services
    # Expects env: auth_token, cloud

    clDirectorOp GET "services"
}

function clDeleteService() {
    # Deletes a registered service with the given host ($1)
    # Expects env: auth_token, cloud

    clDirectorOp DELETE "services/$1"
}

function clUpsertService() {
    # Deletes a registered service with the given host ($3), name ($2), and rank ($2)
    # Expects env: auth_token, cloud

    local encodedHost=$(echo $3 | jq --raw-input --raw-output '@uri')
    clDirectorDataOp PUT "services/$encodedHost" "{\"name\":\"$1\",\"rank\":$2}"
}

function clListEventRouters() {
    # Lists EventRouters
    # Expects env: auth_token, cloud

    clDirectorOp GET "event-routers"
}

function clGetEventRouter() {
    # Gets a EventRouter with the given id ($1)
    # Expects env: auth_token, cloud

    clDirectorOp GET "event-routers/$1"
}

function clDeleteEventRouter() {
    # Deletes an EventRouter with the given id ($1)
    # Expects env: auth_token, cloud

    clDirectorOp DELETE "event-routers/$1"
}

function clUpdateEventRouter() {
    # Updates an EventRouter with the given id ($1) and eventType ($2) and destination ($3)
    # Expects env: auth_token, cloud

    clDirectorDataOp PUT "event-routers/$1" "{\"eventType\":\"$2\",\"destination\":\"$3\"}"
}

function clCreateEventRouter() {
    # Creates an EventRouter with the given account id ($1) and eventType ($2) and destination ($3)
    # Expects env: auth_token, cloud

    clDirectorDataOp POST "event-routers" "{\"accountId\":\"$1\",\"eventType\":\"$2\",\"destination\":\"$3\"}"
}

alias clid-l="clListIdentities $@"
alias clid-g="clDirectorOp GET identities/$@"
alias clid-d="clDirectorOp DELETE identities/$@"

alias clser-l="clListServices $@"
alias clser-d="clDeleteService $@"
alias clser-u="clUpsertService $@"

alias clert-l="clListEventRouters $@"
alias clert-g="clGetEventRouter $@"
alias clert-c="clCreateEventRouter $@"
alias clert-u="clUpdateEventRouter $@"
alias clert-d="clDeleteEventRouter $@"

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

function clGetChatAccountById() {
    # Gets chat cached account record for the given accountId ($1)
    # Expects env: auth_token, cloud

    clChatOp GET "accounts/$1"
}

function clGetConversations() {
    # Gets user conversations for the logged in user
    # Expects env: auth_token, cloud

    clChatOp GET "conversations$1"
}

function clPutAccountTag() {
    # Updates the user with accountId ($1), tagId ($2), and tag value ($2)
    # Expects env: auth_token, cloud

    clAdminDataOp PUT "accounts/$1/tags/$2" $3
}

function clDeleteAccountTag() {
    # Updates the user with accountId ($1), and tagId ($2)
    # Expects env: auth_token, cloud

    clAdminOp DELETE "accounts/$1/tags/$2"
}

function clListParticipants() {
    # Lists participants for the given conversationId ($1)
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

alias clconv-l='clChatOp GET conversations'
alias cluconv-l='clChatOp GET users/me/conversations'
alias clcpart-l="clListParticipants $@"
alias clcmsg-c="clPostMessageText $@"
alias clcacc-g="clGetChatAccountById $@"

# DataLake API

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

alias clehis-l="clEventHistoryQuery $@"

# Notifications API

function clNotificationsOp() {
    # Executes a curl get request with the CL auth_token for the given method ($1) subresource ($2)
    # Expects env: auth_token, cloud

    clOp $1 "https://notifications$cloud.api.mitel.io/2017-09-01/$2"
}

alias clsub-l="clNotificationsOp GET subscriptions"

# System manager API

function clSysManOp() {
    # Executes a curl request with the CL auth_token for the given method ($1) system manager resource ($2)
    # Expects env: auth_token, cloud

    clOp $1 "https://system-manager$cloud.api.mitel.io/2023-07-01/$2"
}

function clListComponents() {
    # List components with optional query params ($1)
    # Expects env: auth_token, cloud

    clSysManOp GET "components$1"
}

function clListPlatforms() {
    # List platforms with optional query params ($1)
    # Expects env: auth_token, cloud

    clSysManOp GET "platforms$1"
}

function clGetPlatform() {
    # Get platform with ID ($1)
    # Expects env: auth_token, cloud

    clSysManOp GET "platforms/$1"
}

function clDeletePlatform() {
    # Delete platform with ID ($1)
    # Expects env: auth_token, cloud

    clSysManOp DELETE "platforms/$1"
}

alias clcomp-l='clListComponents $@'
alias clplat-l='clListPlatforms $@'
alias clplat-g='clGetPlatform $@'
alias clplat-d='clDeletePlatform $@'

# Billing API

function clBillingOp() {
    # Executes a curl request with the CL auth_token for the given method ($1) billing resource ($2)
    # Expects env: auth_token, cloud

    clOp $1 "https://billing$cloud.api.mitel.io/2019-03-01/$2"
}

alias cllic-l="clBillingOp GET licenses $@"
alias clsub-l="clBillingOp GET subscriptions $@"
alias clpsub-l="clBillingOp GET partner-subscriptions $@"
alias clbu-l="clBillingOp GET users $@"
alias clba-l="clBillingOp GET accounts $@"
