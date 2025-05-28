# Bash it up

These are bash scripts for executiong various AWS and CloudLink actions.

## AWS API script

These are maintained in the module [aws_api.sh](./aws_api.sh), and consist of the following functionality:
- TBD

## CloudLink API script

These are maintained in the module [cloudlink_api.sh](./cloudlink_api.sh), and consist of the following functionality:
- TBD

## OpenSearch API script

Consisting of functions for accessing the AWS OpenSearch service, these are maintained inside the script [opensearch_api.sh](./opensearch_api.sh).
The concept is to run a Kibana daemon process (`aws-es-kibana`) separately in its own Bash shell, and then run the OpenSearch commands from other Bash shells, which communicate with the aforementioned Kibana daemon via local network connections.
This uses the credentials defined in your AWS profiles to send requests to AWS services.

The commands below deals with OpenSearch snapshots, among other things.
In OpenSearcch snapshots are stored in _snapshot repositories_, in this context we simply refer to them as repositories.
We will not explain the concept of snapshot here, for more information please consult OpenSearch documentation. 

### How to use the script

1. Source the script, i.e. execute it in the current Bash shell, it will set up functions, aliases, and global variables for that Bash shell:
   - `. ./opensearch_api.sh` (note the dot followed by a space at the beginning of the command, they are important!)
1. Run the Kibana daemon (this will block the current shell from further use):
   - In regions where there is a single OpenSearch domain, you can simply execute:
     - `profile=<your AWS profile> awsos-c`
   - In regions where there are more than one domain, you must specify the name of the target domain:
     - `profile=<your AWS profile> awsos-c "?DomainName == 'the name of your domain'"`
1. Switch to another Bash shell, don't forget to source the script in every new shell:
   - `. ./opensearch_api.sh`
1. Set the Kibana connection info for all subsequent OpenSearch commands (repeat steps 3 and 4 for every new shell):
   - `oscon-sl`
1. Now you are ready to execute OpenSearch commands. Below are some examples:
   - `osind-l`
   - `osclu-g`
   - ...

### OpenSearch commands

|Command|Args|Category|Description|
|--|--|--|--|
|awsos-c|`"?DomainName == '<target domain name>'"` or omit if there's only one domain in the target cloud|Init|Launch the `aws-es-kibana` daemon against a target OpenSearch domain|
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

The recipes below assumes that steps 1-4 in the [how to](#how-to-use-the-script) section above have been performed.

#### List the the names of all snapshots in a repository

List the names of snapshots in  a repository and output as a JSON array:

`osss-l <repository-name> | jq "[.snapshots.[].snapshot]"`

Example:

List the names of snapshots in the automatic snapshot repository (`cs-automated-enc`) of the target OpenSearch domain.

`osss-l cs-automated-enc | jq "[.snapshots.[].snapshot]"`