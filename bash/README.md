# Bash it up

Bash scripts for interacting with various cloud hosted APIs.  Example operations assume the corresponding script has been loaded which sets various aliases.  It is recommended to add them to your `.bash_alias` file if they're frequently used.
     
## AWS API

A set of scripts for interacting with the AWS service via AWS CLI.  These are maintained in the file [aws_api.sh](./aws_api.sh).

## CloudLink API

A set of scripts for interacting with the Mitel CloudLink Platform.  These are maintained in the file [cloudlink_api.sh](./cloudlink_api.sh).

## OpenSearch API

A set of scripts for interacting with the OpenSearch distributed database.  These are maintained inside the file [opensearch_api.sh](./opensearch_api.sh).  For interacting with AWS OpenSearch, first a signing proxy, such as `aws-es-kibana`, must be ran locally.  The proxy will receive the requests and forward them to the connected AWS OpenSearch instance.

In OpenSearch snapshots are stored in _snapshot repositories_, in this context we simply refer to them as repositories.
We will not explain the concept of snapshot here, for more information please consult [OpenSearch documentation](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/managedomains-snapshots.html). 

### AWS OpenSearch proxy setup

Start the proxy with.
```bash
$ profile=$profile awsos-c "?DomainName == '$osDomain'"
```
In regions where there is a single OpenSearch domain the Domain name doesn't need to be specified.
```bash
$ profile=$profile awsos-c
```
Set the OpenSearch connection URL variable to local to forward requests to the proxy.
```
$ oscon-sl
```

### OpenSearch commands

|Command|Args|Category|Description|
|--|--|--|--|
|awsos-c|`"?DomainName == '$domain'"` or omit if there's only one domain in the target cloud|Init|Launch the `aws-es-kibana` daemon against a target OpenSearch domain|
|oscon-sl|None|Init|Setup the Kibana connection for subsequent OpenSearech commands|
|osclu-g|None|Domain|Get (display) detailed information about the target OpenSearch cluster (domain)|
|osssr-l|None|Repository|List all snapshot repositories registered with the target OpenSearch domain|
|osssr-as3|`<repository-name> <bucket-name> <region> <object-path> <role-arn>`|Repository|Register a new repository with the target domain|
|osssr-d|`<repository-name>`|Repository|Deregister a snapshot repository from the target domain|
|ossss-l|None|Snapshot?|Not sure what this is supposed to do|
|osss-l|`<repository-name>`|Snapshot|Get the snapshots for a specific repository|
|osss-c|`<repository-name> <snapshot-name>`|Snapshot|Take a snapshot|
|osss-r|`<repository-name> <snapshot-name>`|Snapshot|Restore a snapshot|
|osind-l|None|Index|List all indices in the target domain|
|osind-c|`<index-name> <number-of-shards> <number-of-replicas>`|Index|Create a new index|
|osind-u|`<index-name> <number-of-replicas>`|Index|Update an existing index|
|osind-d|`<index-name>`|Index|Delete an existing index|
|osind-cl|`<index-name>`|Index|Close an existing index, preventing it from being accessed (e.g. indexing, searching, ...)|
|osind-o|`<index-name>`|Index|Open a closed index|
|osind-sro|`<index-name>`|Index|Set read-only, making an index read-only|
|osind-srw|`<index-name>`|Index|Set read/write, making an index read-writable|
|osind-cfi|`<source-index-name> <target-index-name>`|Index|Clone an existing index (source) to a new index (target). The target index must not exist|

### Recipes

#### List the the names of all snapshots in a repository

List the names of snapshots in  a repository and output as a JSON array:
```bash
$ osss-l <repository-name> | jq "[.snapshots.[].snapshot]"
```
It's often useful to convert the output to CSV format for compactness.  It can be redirected to a file if desired.
```bash
$ osss-l <repository-name> | jq --raw-output '.snapshots.[].snapshot | @csv'
```
