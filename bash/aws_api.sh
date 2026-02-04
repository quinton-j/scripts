#!/bin/bash

# AWS CLI

# STS

alias awssts-whoami='aws --profile=$profile sts get-caller-identity'

# Lambda

function awsLambdaInvoke() {
    # Invokes a lambda function ($1) with the given payload ($2) using the given temp file ($3)
    # Expects env: profile to be set

    aws --profile=$profile lambda invoke --function-name=$1 --cli-binary-format=raw-in-base64-out --payload=$2 $3 && cat $3 | jq && rm $3
}

function awsLambdaPutConcurrency() {
    # Sets the reserved concurrency for a lambda function ($1) to ($2)
    # Expects env: profile to be set

    aws --profile=$profile lambda put-function-concurrency --function-name $1 --reserved-concurrent-executions $2
}

alias awsl-lf='aws --profile=$profile lambda list-functions --query="Functions"'
alias awsl-gf='aws --profile=$profile lambda get-function --query="Configuration" --function-name'
alias awsl-df='aws --profile=$profile lambda delete-function --function-name'

alias awsl-la='aws --profile=$profile lambda list-aliases --query="Aliases" --function-name'
alias awsl-lv='aws --profile=$profile lambda list-versions-by-function --query="Versions[*].{version:Version,modified:LastModified,revisionId:RevisionId}" --function-name'
alias awsl-gp='aws --profile=$profile lambda get-policy --function-name'
alias awsl-i='awsLambdaInvoke'

alias awsl-gc='aws --profile=$profile lambda get-function-concurrency --function-name'
alias awsl-pc='awsLambdaPutConcurrency'
alias awsl-dc='aws --profile=$profile lambda delete-function-concurrency --function-name'

# Pinpoint

alias awspp-la='aws --profile=$profile pinpoint get-apps --query="ApplicationsResponse.{apps:Item[*].{name:Name,id:Id},nextToken:NextToken}"'
alias awspp-gcc='aws --profile=$profile pinpoint get-gcm-channel --application-id '

# Opensearch

alias awsos-ld='aws --profile=$profile opensearch list-domain-names --query="DomainNames[].DomainName"'
alias awsos-gd='aws --profile=$profile opensearch describe-domain --domain-name'
alias awsos-gde='aws --profile=$profile opensearch describe-domain --query="DomainStatus.Endpoint" --output=text --domain-name'
alias awsos-dd='aws --profile=$profile opensearch delete-domain --domain-name'

alias awsos-k='AWS_PROFILE=$profile ENDPOINT=$os_endpoint aws-es-kibana'

# S3

alias awss3-lb='aws --profile=$profile s3api list-buckets --query="Buckets[].Name"'
alias awss3-gbp='aws --profile=$profile s3api get-bucket-policy --bucket'
alias awss3-gba='aws --profile=$profile s3api get-bucket-acl --bucket'
alias awss3-lbo='aws --profile=$profile s3api list-objects-v2 --bucket'

# IAM

function awsGetRolePolicy() {
    # Get a role policy ($2) for the given role ($1)
    # Expects env: profile to be set

    aws --profile=$profile iam get-role-policy --role-name=$1 --policy-name=$2
}

alias awsiam-lr='aws --profile=$profile iam list-roles --query="Roles[].RoleName"'
alias awsiam-gra='aws --profile=$profile iam get-role --query="Role.Arn" --output=text --role-name'
alias awsiam-lrp='aws --profile=$profile iam list-role-policies --role-name'
alias awsiam-grp='awsGetRolePolicy'

# QuickSight

function awsQuickSightGetAnalysis() {
    # Get a QuickSight analysis ($2) in a the given AWS account id $1
    # Expects env: profile to be set

    aws --profile=$profile quicksight describe-analysis --aws-account-id=$1 --analysis-id=$2
}

function awsQuickSightGetIngestions() {
    # Get QuickSight ingestions for the given AWS account id $1 and dataset id $2
    # Expects env: profile to be set

    aws --profile=$profile quicksight list-ingestions --query="Ingestions[*]" --aws-account-id=$1 --data-set-id=$2
}

function awsQuickSightCreateIngestion() {
    # Get QuickSight ingestions for the given AWS account id $2 and dataset id $3 and refresh type ($1)
    # Expects env: profile to be set

    local timestamp=$(date --utc '+%Y-%m-%dT%H-%M-%SZ')
    aws --profile=$profile quicksight create-ingestion --ingestion-id=full-refresh-$timestamp --ingestion-type=$1 --aws-account-id=$2 --data-set-id=$3
}

alias awsqs-la='aws --profile=$profile quicksight list-analyses --query="AnalysisSummaryList[*].{id:AnalysisId,name:Name,status:Status}" --aws-account-id'
alias awsqs-ga='awsQuickSightGetAnalysis'
alias awsqs-ld='aws --profile=$profile quicksight list-data-sets --query="DataSetSummaries[*].{id:DataSetId,name:Name,mode:ImportMode,lastUpdated:LastUpdatedTime}" --aws-account-id'
alias awsqs-li='awsQuickSightGetIngestions'
alias awsqs-cii='awsQuickSightCreateIngestion INCREMENTAL_REFRESH'
alias awsqs-cfi='awsQuickSightCreateIngestion FULL_REFRESH'

## Athena

function awsAthenaStartQueryExecution() {
    # Start an Athena query for the given region ($1), account id ($2), catalog ($3), database ($4), and query string ($5)
    # Expects env: profile, region, aws_acc_id to be set

    local timestamp=$(date --utc '+%Y/%m/%d')
    aws --profile=$profile athena start-query-execution \
        --result-configuration "OutputLocation=s3://aws-athena-query-results-$1-$2/Unsaved/$timestamp" \
        --query-execution-context="Catalog=$3,Database=$4" \
        --query-string="$5"
}

function awsAthenaGetQueryExecution() {
    # Gets the Athena execution with id ($1)
    # Expects env: profile to be set

    aws --profile=$profile athena get-query-execution \
        --query="QueryExecution" \
        --query-execution-id=$1
}

function awsAthenaGetQueryResults() {
    # Gets the status result of an Athena execution with id ($1)
    # Expects env: profile to be set

    aws --profile=$profile athena get-query-results \
        --query="ResultSet.Rows[].Data" \
        --query-execution-id=$1 |
        jq --raw-output '.[] | map(.VarCharValue) | @csv'
}

alias awsath-sqe='awsAthenaStartQueryExecution'
alias awsath-lqe='aws --profile=$profile athena list-query-executions --query="QueryExecutionIds"'
alias awsath-gqe='awsAthenaGetQueryExecution'
alias awsath-gqr='awsAthenaGetQueryResults'

# Glue

alias awsglue-lc='aws --profile=$profile glue list-crawlers --query=CrawlerNames'
alias awsglue-gc='aws --profile=$profile glue get-crawler --query="Crawler" --name'
alias awsglue-gcs='aws --profile=$profile glue get-crawler --query="Crawler.{name:Name,status:State,crawlElapsedTime:CrawlElapsedTime,lastCrawl:LastCrawl.{status:Status,start:StartTime}}" --name'
alias awsglue-sc='aws --profile=$profile glue start-crawler --name'
alias awsglue-ld='aws --profile=$profile glue get-databases --query="DatabaseList"'
alias awsglue-lt='aws --profile=$profile glue get-tables --query="TableList[].{name:Name,columns:length(StorageDescriptor.Columns),paritionKeys:PartitionKeys,type:TableType}" --database-name'
alias awsglue-lcm='aws --profile=$profile glue get-crawler-metrics --query=CrawlerMetricsList | jq "map({crawlerName:.CrawlerName,stillEstimating:.StillEstimating,lastRuntimeMins:(.LastRuntimeSeconds/60),medianRuntimeMins:(.MedianRuntimeSeconds/60),remainingMins:(.TimeLeftSeconds/60),tablesCreated:.TablesCreated,tablesUpdated:.TablesUpdated,tablesDeleted:.TablesDeleted})"'

# SES

function awsSesListSuppressedDestinations() {
    # List suppressed destinations for the given domain ($1) and optional other args
    # Expects env: profile to be set
    # Set variable nextToken

    tmpDir=${LOCALAPPDATA:-$TMP}/${USER:-$USERNAME}-cli && mkdir $tmpDir 2>/dev/null
    local tmpFile="$tmpDir/response.json"
    aws sesv2 list-suppressed-destinations --profile=$profile \
        --query="{suppressedAddresses:SuppressedDestinationSummaries[?contains(@.EmailAddress,'$1')],nextToken:NextToken}" ${@:2} \
        >$tmpFile
    nextToken=$(jq '.nextToken' $tmpFile --raw-output)
    jq '.' $tmpFile
    rm $tmpFile
}

alias awsses-lsd='awsSesListSuppressedDestinations'
alias awsses-gsd='aws sesv2 get-suppressed-destination --profile=$profile --query="SuppressedDestination" --email-address'
alias awsses-dsd='aws sesv2 delete-suppressed-destination --profile=$profile --email-address'

# DynamoDB

alias awsddb-lt='aws --profile=$profile dynamodb list-tables --query="TableNames"'
alias awsddb-it='aws --profile=$profile dynamodb describe-table --table-name'
alias awsddb-dt='aws --profile=$profile dynamodb delete-table --table-name'

alias awsddb-qa='aws --profile=$profile dynamodb execute-statement --statement="select * from \"$table\""'
alias awsddb-qd='aws --profile=$profile dynamodb execute-statement --statement="delete from \"$table\" where $column = '\''$value'\''"'
alias awsddb-qi='aws --profile=$profile dynamodb execute-statement --statement="insert into \"$table\" value $value"'
alias awsddb-qu='aws --profile=$profile dynamodb execute-statement --statement="update \"$table\" set $value where $condition returning all new *'

alias awsddb-lb='aws --profile=$profile dynamodb list-backups'
alias awsddb-cb='aws --profile=$profile dynamodb create-backup --table-name $sourceTable --backup-name'
alias awsddb-ib='aws --profile=$profile dynamodb describe-backup --backup-arn'
alias awsddb-rb='aws --profile=$profile dynamodb restore-table-from-backup --target-table-name=$targetTable --backup-arn'
alias awsddb-db='aws --profile=$profile dynamodb delete-backup --backup-arn'

alias awsddb-icb='aws --profile=$profile dynamodb describe-continuous-backups --table-name'
alias awsddb-rcb='aws --profile=$profile dynamodb restore-table-to-point-in-time --use-latest-restorable-time --source-table-name=$sourceTable --target-table-name'

# SSM Parameter Store

alias awsssm-lp='aws --profile=$profile ssm describe-parameters'
alias awsssm-gp='aws --profile=$profile ssm get-parameter --with-decryption --name'
alias awsssm-dp='aws --profile=$profile ssm delete-parameter --name'
alias awsssm-up='aws --profile=$profile ssm put-parameter --overwrite --type=String'

# Codepipline

alias awscp-lp='aws --profile=$profile codepipeline list-pipelines --query="pipelines"'
alias awscp-lpe='aws --profile=$profile codepipeline list-pipeline-executions --query="pipelineExecutionSummaries" --pipeline-name'
alias awscp-lpace='aws --profile=$profile codepipeline list-action-executions --query="actionExecutionDetails" --pipeline-name'
alias awscp-gps="aws --profile=\$profile codepipeline get-pipeline-state --query=\"stageStates[].{ name: stageName, status: latestExecution.status, actions: actionStates}\" --name "
## requires profile, pipeline, stageName, actionName, reason, and token to be set
alias awscp-pa='aws --profile=$profile codepipeline --pipeline-name=$pipeline put-approval-result --stage-name=$stageName --action-name=$actionName --result="status=Approved,summary=$reason" --token=$token'
alias awscp-spe='aws --profile=$profile codepipeline start-pipeline-execution --name'

# CodeBuild

alias awscb-lp='aws --profile=$profile codebuild list-projects --query="projects"'
alias awscb-lb='aws --profile=$profile codebuild list-builds-for-project --query="ids" --project-name'
alias awscb-gb='aws --profile=$profile codebuild batch-get-builds --query="builds[0]" --ids'

# Secrets Manager

alias awssec-ls='aws --profile=$profile secretsmanager list-secrets --query="SecretList"'
alias awssec-gs='aws --profile=$profile secretsmanager describe-secret --secret-id'
alias awssec-gsv='aws --profile=$profile secretsmanager get-secret-value --secret-id'
alias awssec-ds='aws --profile=$profile secretsmanager delete-secret --secret-id'
alias awssec-us='aws --profile=$profile secretsmanager put-secret-value --secret-id'

# CloudFormation

alias awscform-ls='aws --profile=$profile cloudformation list-stacks --query "StackSummaries" | jq'
alias awscform-gs='aws --profile=$profile cloudformation describe-stacks --stack-name=$stackName | jq'
alias awscform-lsr='aws --profile=$profile cloudformation list-stack-resources --stack-name=$stackName --query "StackResourceSummaries" | jq'
alias awscform-lse='aws --profile=$profile cloudformation describe-stack-events --stack-name=$stackName --query="StackEvents" | jq'

alias awscform-dsd='aws --profile=$profile cloudformation detect-stack-drift --stack-name=$stackName | jq'
alias awscform-lsd='aws --profile=$profile cloudformation describe-stack-resource-drifts --query=""StackResourceDrifts --stack-name=$stackName | jq'

# Route53

alias awsr53-lz='aws --profile=$profile route53 list-hosted-zones --query="HostedZones" | jq'
alias awsr53-ld='aws --profile=$profile route53domains list-domains --query="Domains" | jq'

# CloudWatch Logs

function awsCloudWatchLogsListFieldIndexes() {
    # List CloudWatch Logs field indexes for the given log group ($1)
    # Expects env: profile to be set

    aws --profile=$profile logs describe-field-indexes --log-group-identifiers $1 --query="fieldIndexes" | jq 'map(. + {firstEventTime: (if .firstEventTime then (.firstEventTime/1000|todate) else .firstEventTime end), lastEventTime: (if .lastEventTime then (.lastEventTime/1000|todate) else .lastEventTime end), lastScanTime: (if .lastScanTime then (.lastScanTime/1000|todate) else .lastScanTime end)})'
}

function awsCloudWatchLogsRenameQueryDefinition() {
    # Rename a CloudWatch Logs Insights query definition with id ($1) to new name ($2)
    # Expects env: profile to be set
    # Expects env: region to be set

    local queryDefId="$1"
    local newName="$2"

    # Fetch the existing query definition
    local queryDef=$(aws --profile=$profile --region=$region logs describe-query-definitions \
        --query="queryDefinitions[?queryDefinitionId=='$queryDefId']|[0]" --output json)

    if [ "$queryDef" == "null" ] || [ -z "$queryDef" ]; then
        echo "Error: Query definition with ID '$queryDefId' not found"
        return 1
    fi

    # Extract the query string and log group names
    local queryString=$(echo "$queryDef" | jq -r '.queryString')
    local logGroupNames=$(echo "$queryDef" | jq -r '.logGroupNames // [] | join(",")')

    # Update with new name while preserving query string and log groups
    if [ -n "$logGroupNames" ] && [ "$logGroupNames" != "" ]; then
        aws --profile=$profile --region=$region logs put-query-definition \
            --query-definition-id "$queryDefId" \
            --name "$newName" \
            --query-string "$queryString" \
            --log-group-names $(echo $logGroupNames | tr ',' ' ')
    else
        aws --profile=$profile --region=$region logs put-query-definition \
            --query-definition-id "$queryDefId" \
            --name "$newName" \
            --query-string "$queryString"
    fi
}

function awsCloudWatchLogsCopyQueryDefinition() {
    # Copy CloudWatch Insights Query Definitions from source region ($1) to destination region ($2)
    # Expects env: profile to be set
    # Optional: Provide query name as $3 to copy a specific query, otherwise copies all

    local sourceRegion=$1
    local destRegion=$2
    local queryName=$3

    if [ -z "$sourceRegion" ] || [ -z "$destRegion" ]; then
        echo "Error: Both source and destination regions must be specified"
        echo "Usage: awsCloudWatchLogsCopyQueryDefinition <source-region> <dest-region> [query-name]"
        return 1
    fi

    if [ -n "$queryName" ]; then
        # Copy a specific query definition by name
        local queryDef=$(aws --profile=$profile --region=$sourceRegion logs describe-query-definitions \
            --query="queryDefinitions[?name=='$queryName']|[0]" --output json)

        if [ "$queryDef" == "null" ] || [ -z "$queryDef" ]; then
            echo "Error: Query definition '$queryName' not found in region $sourceRegion"
            return 1
        fi

        local name=$(echo $queryDef | jq -r '.name')
        local queryString=$(echo $queryDef | jq -r '.queryString')
        local logGroupNames=$(echo $queryDef | jq -r '.logGroupNames // [] | join(",")')

        # Check if query already exists in destination region
        local existingQueryDef=$(aws --profile=$profile --region=$destRegion logs describe-query-definitions \
            --query="queryDefinitions[?name=='$queryName']|[0]" --output json)
        local existingQueryDefId=""

        if [ "$existingQueryDef" != "null" ] && [ -n "$existingQueryDef" ]; then
            existingQueryDefId=$(echo $existingQueryDef | jq -r '.queryDefinitionId')
            echo "Updating existing query: $name (ID: $existingQueryDefId)"
        else
            echo "Creating new query: $name"
        fi

        if [ -n "$logGroupNames" ] && [ "$logGroupNames" != "" ]; then
            if [ -n "$existingQueryDefId" ]; then
                aws --profile=$profile --region=$destRegion logs put-query-definition \
                    --query-definition-id "$existingQueryDefId" \
                    --name "$name" \
                    --query-string "$queryString" \
                    --log-group-names $(echo $logGroupNames | tr ',' ' ')
            else
                aws --profile=$profile --region=$destRegion logs put-query-definition \
                    --name "$name" \
                    --query-string "$queryString" \
                    --log-group-names $(echo $logGroupNames | tr ',' ' ')
            fi
        else
            if [ -n "$existingQueryDefId" ]; then
                aws --profile=$profile --region=$destRegion logs put-query-definition \
                    --query-definition-id "$existingQueryDefId" \
                    --name "$name" \
                    --query-string "$queryString"
            else
                aws --profile=$profile --region=$destRegion logs put-query-definition \
                    --name "$name" \
                    --query-string "$queryString"
            fi
        fi
    else
        # Copy all query definitions
        local queryDefs=$(aws --profile=$profile --region=$sourceRegion logs describe-query-definitions --output json)
        local count=$(echo $queryDefs | jq '.queryDefinitions | length')

        echo "Copying $count query definitions from $sourceRegion to $destRegion..."

        echo $queryDefs | jq -c '.queryDefinitions[]' | while read -r queryDef; do
            local name=$(echo $queryDef | jq -r '.name')
            local queryString=$(echo $queryDef | jq -r '.queryString')
            local logGroupNames=$(echo $queryDef | jq -r '.logGroupNames // [] | join(",")')

            # Check if query already exists in destination region
            local existingQueryDef=$(aws --profile=$profile --region=$destRegion logs describe-query-definitions \
                --query="queryDefinitions[?name=='$name']|[0]" --output json)
            local existingQueryDefId=""

            if [ "$existingQueryDef" != "null" ] && [ -n "$existingQueryDef" ]; then
                existingQueryDefId=$(echo $existingQueryDef | jq -r '.queryDefinitionId')
                echo "Updating: $name (ID: $existingQueryDefId)"
            else
                echo "Creating: $name"
            fi

            if [ -n "$logGroupNames" ] && [ "$logGroupNames" != "" ]; then
                if [ -n "$existingQueryDefId" ]; then
                    aws --profile=$profile --region=$destRegion logs put-query-definition \
                        --query-definition-id "$existingQueryDefId" \
                        --name "$name" \
                        --query-string "$queryString" \
                        --log-group-names $(echo $logGroupNames | tr ',' ' ')
                else
                    aws --profile=$profile --region=$destRegion logs put-query-definition \
                        --name "$name" \
                        --query-string "$queryString" \
                        --log-group-names $(echo $logGroupNames | tr ',' ' ')
                fi
            else
                if [ -n "$existingQueryDefId" ]; then
                    aws --profile=$profile --region=$destRegion logs put-query-definition \
                        --query-definition-id "$existingQueryDefId" \
                        --name "$name" \
                        --query-string "$queryString"
                else
                    aws --profile=$profile --region=$destRegion logs put-query-definition \
                        --name "$name" \
                        --query-string "$queryString"
                fi
            fi
        done

        echo "Done copying query definitions"
    fi
}

function awsCloudWatchLogsRenameQueryFolder() {
    # Rename all CloudWatch Logs Insights query definitions in a folder
    # Replaces old folder name ($1) with new folder name ($2) for all queries
    # Expects env: profile to be set
    # Expects env: region to be set

    local oldFolder="$1"
    local newFolder="$2"

    if [ -z "$oldFolder" ] || [ -z "$newFolder" ]; then
        echo "Error: Both old and new folder names must be specified"
        echo "Usage: awsCloudWatchLogsRenameQueryFolder <old-folder> <new-folder>"
        return 1
    fi

    # Get all query definitions that start with the old folder name
    local queries=$(aws --profile=$profile --region=$region logs describe-query-definitions \
        --output json | jq -c ".queryDefinitions[] | select(.name | startswith(\"$oldFolder\"))")

    if [ -z "$queries" ]; then
        echo "No query definitions found in folder: $oldFolder"
        return 0
    fi

    local total=$(echo "$queries" | wc -l)
    local success=0
    local failed=0

    while read -r query; do
        local queryDefId=$(echo "$query" | jq -r '.queryDefinitionId')
        local oldName=$(echo "$query" | jq -r '.name')
        local queryString=$(echo "$query" | jq -r '.queryString')
        local logGroupNames=$(echo "$query" | jq -r '.logGroupNames // [] | join(",")')
        local newName=$(echo "$oldName" | sed "s|^$oldFolder|$newFolder|")

        echo "Renaming: $oldName -> $newName"

        local result
        if [ -n "$logGroupNames" ] && [ "$logGroupNames" != "" ]; then
            result=$(aws --profile=$profile --region=$region logs put-query-definition \
                --query-definition-id "$queryDefId" \
                --name "$newName" \
                --query-string "$queryString" \
                --log-group-names $(echo $logGroupNames | tr ',' ' ') 2>&1)
        else
            result=$(aws --profile=$profile --region=$region logs put-query-definition \
                --query-definition-id "$queryDefId" \
                --name "$newName" \
                --query-string "$queryString" 2>&1)
        fi

        if echo "$result" | jq -e '.queryDefinitionId' >/dev/null 2>&1; then
            ((success++))
        else
            ((failed++))
            echo "Failed to rename: $oldName"
            echo "$result"
        fi
    done <<< "$queries"

    echo "Renamed $success of $total query definitions from $oldFolder to $newFolder"
    [ $failed -gt 0 ] && echo "Failed: $failed" && return 1
    return 0
}

alias awslogs-lfi='awsCloudWatchLogsListFieldIndexes'
alias awslogs-llg='aws --profile=$profile logs describe-log-groups --query="logGroups" | jq "map(. + {firstEventTime: (if .firstEventTime then (.firstEventTime/1000|todate) else .firstEventTime end), lastEventTime: (if .lastEventTime then (.lastEventTime/1000|todate) else .lastEventTime end)})"'
alias awslogs-lqd='aws --profile=$profile --region=$region logs describe-query-definitions | jq ".queryDefinitions | map({qdi:.queryDefinitionId ,name ,qs:.queryString})"'
alias awslogs-pqd='aws --profile=$profile --region=$region logs put-query-definition'
alias awslogs-rqd='awsCloudWatchLogsRenameQueryDefinition'
alias awslogs-rqf='awsCloudWatchLogsRenameQueryFolder'
alias awslogs-cqd='awsCloudWatchLogsCopyQueryDefinition'
