# Running LOCKSS 2.0 in a Development Environment

**Version 6-dev**

`runcluster` is a framework to run a set of LOCKSS services (a cluster)
comprising a single LOCKSS node, in a development environment.  It's a work
in progress; details are likely to change.

### Note: currently Java 8 is required.

## Optional Database Setup

By default, an internal Derby database is used.  This should be sufficient
for normal development use, and requires no setup.  For better performance
and larger databases, PostgreSQL may be used instead.  It requires some
one-time setup.  Install, initialize and start PostgreSQL as appropriate
for your OS.  Then create the LOCKSS role with:

    sudo -u postgres createuser -d -P LOCKSS -S -R
    Enter password for new role: goodPassword
    Enter it again: goodPassword

If you are using a port other than 5432, uncomment and edit all the
`portNumber` attributes in `config/postgres.xml`.

Add `-pg` to the `./start` command line.

## Running a cluster

The individual services may be run from release or snapshot artifacts
downloaded from a Maven repository, or locally built from source.  To run
snapshot versions, change to this directory and run `./start`, or `./start
-pg` to use PostgreSQL.  (Note: the first time this is done Maven will
fetch JARs totalling .7-1.1GB.)  To use locally built JARs in sibling
directories run `./start -local [-pg]`.  (See `config/services.snapshot` or
`config/services.local`.)  The three essential services (config service,
repository service, poller/crawler service) are run by default; to add the
metadata services or SOAP uncomment those lines in `config/services.xxx`.  Run
`./start -h` for more options.

To test a plugin without signing and uploading it to a plugin registry,
package the plugin with `mvn package -Dtesting` in the plugin project, then
supply the name of the plugin JAR with `-jar`.  (E.g., if the plugin
project is in a sibling dir to this project, `-jar
../../<plugin-project>/target/pluginjars/fully.qualified.NamePlugin.jar`.)
Repeat the `-jar` argument for addtional plugins.

To load title DBs, place the `.tdb` files in or below `src/main/tdb` in the
plugin project (or otherwise process them with `lockss-tdbxml-maven-plugin`
or `lockss-tdb-processor` to produce `.xml` files) and point to them
individually with `-c` or load all tdb .xml files in a directory with `-x`,
e.g., `-x ../../<plugin-project>/target/tdbxml`.

Additional config parameters may be placed in `config/cluster.opt`.  This
file is not under source control so is a better place for users to set
params than either `lockss.xml` or `cluster.xml`.  It's a Java Properties file,
not XML, so only simple assignments are allowed.  E.g., to set the log
level of `MyClass` to debug3:

    org.lockss.log.MyClass.level=debug3

## Version 6 Changes

*   The repository disk layout has changed, as well as the Solr
    schema.  Content collected with runcluster 5 or earlier will not
    work unmodified, and should be deleted before starting, with
    `rm -rf  data/repo data/repo-files data/solr-files`.

    (It is possible to convert old content.  If you need to do this
    either contact us or look at the upgrade script in
    lockss-installer to see what steps are needed.)

## Version 5 Changes

*   Added support to run as part of a LOCKSS network, by using -id <file>
    to load a custom config file with real identity information.  See the
    reuncluster help (./start -h) and the comments in
    config/identity-template.xml

*   Version numbering changed to integral, for uninteresting technical
    reasons.

## Version 1.4 Changes

*   Derby is supported, and is the default.  Use `-pg` for PostgreSQL.

## Version 1.3 Changes

*   `config/services` replaced by `config/services.snapshot` and
    `config/services.local`. Format has changed again.

*   Service JARs may be fetched from a maven repository.

## Version 1.2 Changes

*   `config/services` format has changed.

*   PostgreSQL used by default, must be installed, configured and started.
    Derby available

*   All config and data are now stored below `runcluster` dir.  Service project
    source trees are no longer used (but are still needed to build the uber
    JARs).  (Location of PostgreSQL data is separately configured during
    PostgreSQL installation.)

*   Any AUs added and collected with the previous version will be gone, as
    well as any local configuration made through the UI.  The content in the
    repository may be preserved by copying `laaws-repository-service/data/repo`
    to `laaws-dev-scripts/runcluster/data/repo`, then starting the cluster and
    re-adding the AUs.
