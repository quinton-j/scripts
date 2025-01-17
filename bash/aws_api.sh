#!/bin/bash

# AWS CLI

# STS

alias awssts-whoami='aws --profile=$profile sts get-caller-identity'

# Lambda

alias awsl-la='aws --profile=$profile lambda list-aliases --function-name=$lambda_func'
alias awsl-lv='aws --profile=$profile lambda list-versions-by-function --function-name=$lambda_func --query="Versions[*].{version:Version,modified:LastModified,revisionId:RevisionId}"'
alias awsl-gp='aws --profile=$profile lambda get-policy --function-name=$lambda_func'

# Pinpoint

alias awspp-la='aws --profile=$profile pinpoint get-apps --query="ApplicationsResponse.{apps:Item[*].{name:Name,id:Id},nextToken:NextToken}"'
alias awspp-gcc='aws --profile=$profile pinpoint get-gcm-channel --application-id=$@'

# Opensearch

alias awsos-ld='aws --profile=$profile opensearch list-domain-names --query="DomainNames[].DomainName"'
alias awsos-gd='aws --profile=$profile opensearch describe-domain --domain-name $@'
alias awsos-gde='aws --profile=$profile opensearch describe-domain --query="DomainStatus.Endpoint" --output=text --domain-name $@'

alias awsos-k='AWS_PROFILE=$profile ENDPOINT=$os_endpoint aws-es-kibana'

# S3

alias awss3-lb='aws --profile=$profile s3api list-buckets --query="Buckets[].Name"'
alias awss3-gbp='aws --profile=$profile s3api get-bucket-policy --bucket $@'
alias awss3-gba='aws --profile=$profile s3api get-bucket-acl --bucket $@'
alias awss3-lbo='aws --profile=$profile s3api list-objects-v2 --bucket $@'

# IAM

function awsGetRolePolicy() {
    # Get a role policy ($2) for the given role ($1)
    # Expects env: profile to be set

    aws --profile=$profile iam get-role-policy --role-name=$1 --policy-name=$2
}

alias awsiam-lr='aws --profile=$profile iam list-roles --query="Roles[].RoleName"'
alias awsiam-gra='aws --profile=$profile iam get-role --query="Role.Arn" --output=text --role-name $@'
alias awsiam-lrp='aws --profile=$profile iam list-role-policies --role-name $@'
alias awsiam-grp='awsGetRolePolicy $@'

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

    local timestamp=$(date --utc '+%Y-%m-%dT%H-%M-%SZ');
    aws --profile=$profile quicksight create-ingestion --ingestion-id=full-refresh-$timestamp --ingestion-type=$1 --aws-account-id=$2 --data-set-id=$3
}

alias awsqs-la='aws --profile=$profile quicksight list-analyses --query="AnalysisSummaryList[*].{id:AnalysisId,name:Name,status:Status}" --aws-account-id $@'
alias awsqs-ga='awsQuickSightGetAnalysis $@'
alias awsqs-ld='aws --profile=$profile quicksight list-data-sets --query="DataSetSummaries[*].{id:DataSetId,name:Name,mode:ImportMode,lastUpdated:LastUpdatedTime}" --aws-account-id $@'
alias awsqs-li='awsQuickSightGetIngestions $@'
alias awsqs-cii='awsQuickSightCreateIngestion INCREMENTAL_REFRESH $@'
alias awsqs-cfi='awsQuickSightCreateIngestion FULL_REFRESH $@'

## Athena

function awsAthenaStartQueryExecution() {
    # Start an Athena query for the given region ($1), account id ($2), catalog ($3), database ($4), and query string ($5)
    # Expects env: profile, region, aws_acc_id to be set

    local timestamp=$(date --utc '+%Y/%m/%d');
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
        --query-execution-id=$1 \
    | jq --raw-output '.[] | map(.VarCharValue) | @csv'
}

alias awsath-sqe='awsAthenaStartQueryExecution $@'
alias awsath-lqe='aws --profile=$profile athena list-query-executions --query="QueryExecutionIds"'
alias awsath-gqe='awsAthenaGetQueryExecution $@'
alias awsath-gqr='awsAthenaGetQueryResults $@'

# Glue

alias awsglue-lc='aws --profile=$profile glue list-crawlers --query=CrawlerNames'
alias awsglue-gc='aws --profile=$profile glue get-crawler --query="Crawler" --name $@'
alias awsglue-gcs='aws --profile=$profile glue get-crawler --query="Crawler.{name:Name,status:State,crawlElapsedTime:CrawlElapsedTime,lastCrawl:LastCrawl.{status:Status,start:StartTime}}" --name $@'
alias awsglue-sc='aws --profile=$profile glue start-crawler --name $@'
alias awsglue-ld='aws --profile=$profile glue get-databases --query="DatabaseList"'
alias awsglue-lt='aws --profile=$profile glue get-tables --query="TableList[].{name:Name,columns:length(StorageDescriptor.Columns),paritionKeys:PartitionKeys,type:TableType}" --database-name $@'
alias awsglue-lcm='aws --profile=$profile glue get-crawler-metrics --query=CrawlerMetricsList | jq "map({crawlerName:.CrawlerName,stillEstimating:.StillEstimating,lastRuntimeMins:(.LastRuntimeSeconds/60),medianRuntimeMins:(.MedianRuntimeSeconds/60),remainingMins:(.TimeLeftSeconds/60),tablesCreated:.TablesCreated,tablesUpdated:.TablesUpdated,tablesDeleted:.TablesDeleted})"'

# SES

function awsSesListSuppressedDestinations() {
    # List suppressed destinations for the given domain ($1) and optional other args
    # Expects env: profile to be set

    aws sesv2 list-suppressed-destinations --profile=$profile --query="{suppressedAddresses:SuppressedDestinationSummaries[?contains(@.EmailAddress,'$1')],nextToken:NextToken}" ${@:2}
}

alias awsses-lsd='awsSesListSuppressedDestinations $@'
alias awsses-gsd='aws sesv2 get-suppressed-destination --profile=$profile --query="SuppressedDestination" --email-address $@'
alias awsses-dsd='aws sesv2 delete-suppressed-destination --profile=$profile --email-address $@'

# DynamoDB

alias awsddb-lt='aws --profile=$profile dynamodb list-tables --query="TableNames"'
alias awsddb-it='aws --profile=$profile dynamodb describe-table --table-name $@'
alias awsddb-dt='aws --profile=$profile dynamodb delete-table --table-name $@'

alias awsddb-qa='aws --profile=$profile dynamodb execute-statement --statement="select * from \"$table\""'
alias awsddb-qd='aws --profile=$profile dynamodb execute-statement --statement="delete from \"$table\" where $column = '\''$value'\''"'
alias awsddb-qi='aws --profile=$profile dynamodb execute-statement --statement="insert into \"$table\" value $value"'

alias awsddb-lb='aws --profile=$profile dynamodb list-backups'
alias awsddb-cb='aws --profile=$profile dynamodb create-backup --table-name $table --backup-name $@'
alias awsddb-ib='aws --profile=$profile dynamodb describe-backup --backup-arn $table'
alias awsddb-db='aws --profile=$profile dynamodb restore-table-from-backup --target-table-name=$table --backup-arn $@'

# SSM Parameter Store

alias awsssm-lp='aws --profile=$profile ssm describe-parameters'
alias awsssm-gp='aws --profile=$profile ssm get-parameter --with-decryption --name $@'
