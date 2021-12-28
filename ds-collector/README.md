DataStax Diagnostic Collector for Apache Cassandra and DSE
==========================================================

The Diagnostic Collector bundle provides the script, and necessary files, to collect a diagnostic snapshot over all nodes in an Apache Cassandra, or DataStax Enterprise, cluster.

Quick Start
-----------

```
# extract the bundle on the jumpbox/bastion server (this cannot be a Cassandra node)
tar -xvf ds-collector.*.tar.gz
cd collector

# if an encryption file has been provided, copy it to this folder
cp <some-path>/*_secret.key .

# carefully read through the configuration file, ensuring all options are correct
edit collector.conf

# test connections to all nodes can be made, replace <CASSANDRA_CONTACT_POINT> with ip of Cassandra node. if "NOTOK" appears, troubleshoot…

./ds-collector -T -f collector.conf -n <CASSANDRA_CONTACT_NODE>

# collect diagnostics from every node. if "NOTOK" appears, troubleshoot…

./ds-collector -X -f collector.conf -n <CASSANDRA_CONTACT_NODE>
```


Full Instructions
-----------------

The collector tool (the ds-collector script and associated files) is used to collect diagnostic snapshots from every node in a cluster from the command line. Provided is either a casandra_contact_node or the path to the collector.hosts file. With a casandra_contact_node specified the script will discover and collect diagnostics from all nodes in the cluster. With a collector.hosts file specified the script will collect diagnostics only from those nodes listed in the file. For each node the script performs a number of steps: connect to a target host and upload script, binary and configuration files, execute the script in client mode collecting all diagnostic information, generate an artifact tarball of all this information, and then transfer that bundle back to the execution host. Once all nodes have been collected, the script on the bastion/jumpbox then may encrypt all the diagnostic node tarballs, and upload them to the configured S3 bucket.

Files of note in the bundle are:

* `ds-collector` the script that does the work.
* `collector.conf` configuration settings, see help in the file. Must be configured before first run.
* `collector.hosts` optional, list of hosts to get information from, skips the discovery process.
* `collector-*.jar` custom jar of the jmx_exporter library, from which JmxExporter.class is used.
* `dstat` vanilla upstream copy of the dstat binary, bundled for systems without it installed.
* `collect-info` custom binary used for most of the diagnostic execution.
* `rust-commands/` source code to the `collect-info` binary, only provided for (optional) auditing purposes.


Usage
-----

```
usage: ds-collector [option1] [option2] [option...] [mode]

options:
-n=[CASSANDRA_CONTACT_NODE | HOST_FILE_PATH] IP address, hostname, docker container ID, or K8s container name,
                                              of a Cassandra node. Unless `-d` is specified, this specified contact node is used to obtain the list of hosts to run collector on. Can also specify path to file with list of nodes or ip addresses.
-f=CONFIG_FILE_PATH     Path to a configuration file. Will override all defaults and options.
-a=ARTIFACT_PATH        Path to single artifact to upload to s3.
-p                      Ping the host prior to connecting to it. Can only be used with Test Mode.
-d                      Run script on a single node only, disabling auto discovery when the -n
                          option specifies a hostname or IP address. Can only be used with
                          Test Mode and Execute Mode.
-h                      Print this help and exit.

modes:
-T  Test Mode:      Complete a connection test.
-X  Execute Mode:   Execute collector on a cluster using arguments passed above.
-C  Client Mode:    Execute collector for only the node this script is run on. (internal use only)
```

Directions
----------

* Extract the three files to your central host (e.g. bastion or jumpbox). Do not try run this script on a Cassandra/DSE node.
* Copy the generated encryption key to the same extracted directory (where the ds-collector script is found).
* Make sure the correct permissions are set on the ds-collector so it is executable.
```
ls -l ds-collector
chmod +x ds-collector
```
* Update `collector.conf`, carefully read through the file and configure each option if and as neccessary. Do not change `issueId`, `keyId`, or `keySecret`.
* Test the connection with command
```
./ds-collector -T -f collector.conf -n <CASSANDRA_CONTACT_NODE>
```
* If test returns `NOTOK` please notify us including the message.
* Run the script to collect data. If enabled the script will encrypt the diagnostic tarballs, and upload them to a secure S3 bucket.
```
./ds-collector -X -f collector.conf -n <CASSANDRA_CONTACT_NODE>
```
* If the run returns `NOTOK` please notify us including the message.


The script, with the same configuration and encryption key, can be run multiple times as diagnostic snapshots are timestamped.

Recipes
-------

* To run the collector against a single node only, use the `-d` option.
```
./ds-collector -X -d -f collector.conf -n <CASSANDRA_NODE>
```

* To run the collector against a specified list of nodes only, disabling the discovery of all nodes, use the `collector.hosts` file.
```
./ds-collector -X -d -f collector.conf -n collector.hosts
```

* To collect diagnostics from nodes in different data centers, where one bastion/jumpbox cannot access all. Run the collector separately in each data center, nodes that are unreachable will be ignored. Let us know when the collector has been run against all data centers.

* To manually transfer all files in a directory, use the `-a` option followed by the path to the directory
```
./ds-collector -f collector.conf -a /tmp/datastax
```

* To manually transfer a single file, use the `-a` option followed by the path to the file
```
./ds-collector -f collector.conf -a /tmp/datastax/some-node_artifacts_some_timestamp.tar.gz.enc
```

* To run the collector on a Cassandra/DSE node (and only that node).
```
mkdir /tmp/
tar -xvf <bundle>.tar.gz
mv collector datastax
cd datastax
./ds-collector -C -f collector.conf -n collector.hosts
./ds-collector -f collector.conf -a some-node_artifacts_some_timestamp.tar.gz.enc
```

* Auditing the diagnostic tarballs before uploading them. If you need to audit the contents of the tarballs before they are securely uploaded to us, do the following
```
sed -i 's/^#?keepArtifact=.*/keepArtifact=\"true\"/'
sed -i 's/^#?skipS3=.*/skipS3=\"true\"/'

./ds-collector -X -f collector.conf -n <CASSANDRA_CONTACT_NODE>

# audit files in /tmp/datastax/

# when ready to upload to s3
./ds-collector -f collector.conf -a /tmp/datastax
```

Troubleshooting
---------------

* The script is failing and the error message is not clear. Please enable debug in the script by uncommenting the following line:
```
set -x
```
And run the script again. If the failure is still unclear, contact us for further help.

* The bastion/jumpbox does not have an internet access and the s3 upload fails. In this scenario, pull the diagnostic tarballs onto a machine that does have internet access and upload from there.
```
scp -r <bastion/jumpbox>:/path-to-collector-folder> .
scp -r <bastion/jumpbox>:/tmp/datastax .

cd collector
./ds-collector -f collector.conf -a "$(pwd)/../datastax"
```

* Disabling the s3 upload. The artifacts will be left in the `/tmp/datastax/` folder.
```
sed -i 's/^#?skipS3=.*/skipS3=\"true\"/'
```

* Keeping the artifacts on disk after the s3 upload
```
sed -i 's/^#?keepArtifact=.*/keepArtifact=\"true\"/'
```


Limitations
-----------

* The collector script can run on a Linux or MacOS bastion/jumpbox.
* The collector script can only collect from Cassandra/DSE nodes that are running Linux.
* The collector script can only collect from Cassandra versions 1.2 and above.

For other limitations, please see the list of open [Issues](https://github.com/datastax/diagnostic-collection/issues) and [PRs](https://github.com/datastax/diagnostic-collection/pulls).