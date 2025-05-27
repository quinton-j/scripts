#!/bin/bash

# General

function awsOpensearchConnect() {
    # Connects to an AWS OS cluster for the given index or domain index ($1)
    # Expects env: profile to be set

    # The tr command used in the executions below are to strip out non-printable characters such as carriage returns that the command aws may generate
    # in the results in some environments (e.g. cygwin).
    local domainName=$(aws --profile=$profile opensearch list-domain-names --output=text --query="DomainNames[$1].DomainName" | tr -d "[:space:]")
    os_endpoint=$(aws --profile=$profile opensearch describe-domain --query="DomainStatus.Endpoint" --output=text --domain-name $domainName | tr -d "[:space:]")

    AWS_PROFILE=$profile ENDPOINT=$os_endpoint aws-es-kibana
}

function opensearchOp() {
    # Executes a curl request against the OpenSearch cluster with the given method ($1) and subroute ($2)
    # Expects env: os_endpoint to be set

    curl --silent --request $1 "http://$os_endpoint/$2"
}

function opensearchDataOp() {
    # Executes a curl request against the OpenSearch cluster with the given method ($1) and subroute ($2) and data ($3)
    # Expects env: os_endpoint to be set

    curl --silent --request $1 --header 'Content-Type: application/json' "http://$os_endpoint/$2" --data $3
}

function opensearchGetClusterInfo() {
    # Gets cluster info from an OS cluster
    # Expects env: os_endpoint to be set

    curl --silent --request GET "http://$os_endpoint"
}

function opensearchCat() {
    # Gets _cat subresource ($1) from an OS cluster with the given columns ($2)
    # Expects env: os_endpoint to be set

     opensearchOp GET "_cat/$1?v&h=$2"
}

# Indexes

function opensearchDeleteIndex() {
    # Deletes an index ($1) from an OS cluster
    # Expects env: os_endpoint to be set

    opensearchOp DELETE $1
}

function opensearchPostIndexOperation() {
    # Performan a POST operation ($2) on index ($1) in an OS cluster
    # Expects env: os_endpoint to be set

    opensearchOp POST "$1/_$2"
}

function opensearchCloseIndex() {
    # Closes an index ($1) in an OS cluster
    # Expects env: os_endpoint to be set

    opensearchPostIndexOperation $1 "close"
}

function opensearchCloneIndex() {
    # Clones an index ($1) in an OS cluster, the new index name is $2
    # Expects env: os_endpoint to be set

    opensearchOp PUT $1/_clone/$2
}

function opensearchOpenIndex() {
    # Opens an index ($1) in an OS cluster
    # Expects env: os_endpoint to be set

    opensearchPostIndexOperation $1 "open"
}

function opensearchShrinkIndex() {
    # Reindexes an index ($1) in an OS cluster to another index ($2) with different primary ($3) and replicas ($4) shard counts
    # Expects env: os_endpoint to be set

    opensearchDataOp POST "$1/_shrink/$2" \
        "{\"settings\":{\"index.number_of_shards\":\"$3\",\"index.number_of_replicas\":\"$4\"}}"
}

function opensearchSetBlockIndex() {
    # Set a block type ($2) to index ($1) in an OS cluster
    # Expects env: os_endpoint to be set

    opensearchOp PUT "$1/_block/$2"
}

function opensearchReindex() {
    # Reindexes an index ($1) in an OS cluster to another index ($2) with op_type ($3)
    # Expects env: os_endpoint to be set

    opensearchDataOp POST _reindex \
        "{\"source\":{\"index\":\"$1\"},\"dest\":{\"index\":\"$2\",\"op_type\":\"$3\"}}"
}

function opensearchReadOnly() {
    # Sets the block.read.only = true for the target index ($1)
    # Expects env: os_endpoint to be set

    opensearchDataOp PUT $1/_settings \
        "{\"index\":{\"blocks.read_only\":true}}"
}

function opensearchReadWrite() {
    # Sets the block.read.only = false for the target index ($1)
    # Expects env: os_endpoint to be set

    opensearchDataOp PUT $1/_settings \
        "{\"index\":{\"blocks.read_only\":false}}"
}

function opensearchCreateIndex() {
    # Create an index ($1) in an OS cluster with number of primary ($2) and replica ($3) shards
    # Expects env: os_endpoint to be set

    opensearchOp PUT  $1 \
        "{\"mappings\":{},\"settings\":{\"number_of_shards\":$2,\"number_of_replicas\":$3}}"
}

function opensearchUpdateIndexSettings() {
    # Update an index ($1) in an OS cluster with number of replica ($2) shards
    # Expects env: os_endpoint to be set

    opensearchOp PUT "$1/_settings" \
        "{\"index\":{\"number_of_replicas\":$2}}"
}


# Snapshot repositories

function opensearchAddS3Repository() {
    # Registers an S3 repository ($1) in the OS cluster with the given bucket ($2), bucket region ($3) base path ($4), and role arn ($5)
    # Expects env: os_endpoint to be set

    opensearchDataOp PUT "_snapshot/$1" \
        "{\"type\":\"s3\",\"settings\":{\"bucket\":\"$2\",\"region\":\"$3\",\"base_path\":\"$4\",\"role_arn\":\"$5\"}}"
}

function opensearchDeleteS3Repository() {
    # Deletes an S3 repository ($1) from the OS cluster
    # Expects env: os_endpoint to be set

    opensearchOp DELETE "_snapshot/$1"
}

# Snapshots

function opensearchGetSnapshots() {
    # Get all the snapshots for the given repository ($1) from an OS cluster
    # Expects env: os_endpoint to be set

    opensearchOp GET "_snapshot/$1/_all"
}

function opensearchGetSnapshot() {
    # Get a snapshot ($2) for the given repository ($1) from an OS cluster
    # Expects env: os_endpoint to be set

    opensearchOp PUT "_snapshot/$1/$2" | jq '.snapshots[0]'
}

function opensearchTakeSnapshot() {
    # Create a snapshot with name ($2) for the given repository ($1) in an OS cluster
    # Expects env: os_endpoint to be set

    opensearchOp PUT "_snapshot/$1/$2"
}

function opensearchRestoreSnapshot() {
    # Restore a snapshot with name ($2) for the given repository ($1) in an OS cluster
    # Expects env: os_endpoint to be set

    local timestamp=$(date --utc +%Y-%m-%dt%Hh%Mm%Ssz);
    opensearchDataOp POST "_snapshot/$1/$2/_restore" \
        "{\"rename_pattern\":\"(.+)\",\"rename_replacement\":\"restore_${timestamp}_\$1\"}";
}

# Queries

function opensearchQuery() {
    # Run an OS query ($2) against the given index ($1)
    # Expects env: os_endpoint to be set

    opensearchDataOp POST "$1/_search" $2
}

function opensearchQueryDocsByYear() {
    # Query count of docs by year in index ($1)
    # Expects env: os_endpoint to be set

    opensearchQuery $1 \
        "{\"size\":0,\"aggs\":{\"docsTimeAggregate\":{\"date_histogram\":{\"field\":\"createdOn\",\"calendar_interval\":\"year\",\"order\":{\"_key\":\"asc\"},\"min_doc_count\":1},\"aggs\":{\"oldestBucket\":{\"min\":{\"field\":\"createdOn\"}}}}}}" \
        | jq '{took,docsByYear:(.aggregations.docsTimeAggregate.buckets | map({ year:.key_as_string,count:.doc_count,oldest:.oldestBucket.value_as_string}))}'
}

alias awsos-c='awsOpensearchConnect $@'
alias oscon-sl='os_endpoint=localhost:9200'

alias osclu-g='opensearchGetClusterInfo'
alias oschea-g='opensearchCat health timestamp,cluster,status,node.total,node.data,discovered_master,shards,pri,relo,init,unassign,pending_tasks,max_task_wait_time,active_shards_percent'
alias osnod-l='opensearchCat nodes pid,name,id,version,jdk,node.role,master,disk.used_percent,heap.percent,ram.percent,load_1m'
alias osallo-l='opensearchCat allocation node,shards,disk.indices,disk.used,disk.avail,disk.total,disk.percent'
alias osshar-l='opensearchCat shards index,shard,prirep,state,node,id,unassigned.reason,unassigned.details'
alias osrec-l='opensearchCat recovery index,shard,time,type,stage,source_node,target_node,repository,snapshot,files_percent,bytes_percent,translog_ops_percent'

alias osind-l='opensearchOp GET _cat/indices?v'
alias osind-c='opensearchCreateIndex $@'
alias osind-u='opensearchUpdateIndexSettings $@'
alias osind-d='opensearchDeleteIndex $@'
alias osind-o='opensearchOpenIndex $@'
alias osind-cls='opensearchCloseIndex $@'
alias osind-cln='opensearchCloneIndex $@'
alias osind-s='opensearchShrinkIndex $@'
alias osind-b='opensearchSetBlockIndex $@'
alias osind-r='opensearchReindex $@'
alias osind-ro='opensearchReadOnly $@'
alias osind-rw='opensearchReadWrite $@'

alias osali-l='opensearchCat aliases alias,index,filter,routing.index,routing.search,is_write_index'

alias osssr-l='opensearchOp GET _snapshot'
alias osssr-as3='opensearchAddS3Repository $@'
alias osssr-d='opensearchDeleteS3Repository $@'

alias osss-l='opensearchGetSnapshots $@'
alias osss-c='opensearchTakeSnapshot $@'
alias osss-r='opensearchRestoreSnapshot $@'
alias ossss-l='opensearchOp GET _snapshot/_status'

alias osq-r='opensearchQuery $@'
alias osq-dby='opensearchQueryDocsByYear $@'
