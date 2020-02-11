# Running LOCKSS in a Development Environment
Version 3

`runcluster` is a framework to run a set of LOCKSS services (a cluster)
comprising a single LOCKSS node, in a development environment.  It's a work
in progress; details are likely to change.

## Database Setup (once):

By default, a PostgreSQL database is required.  Derby may be used instead
by editing config/cluster.xml, but the metadata query service is not yet
supported with Derby.

To use PostgreSQL, install, initialize and start PostgreSQL as appropriate
for your OS.  Then create the LOCKSS role with:

    sudo -u postgres createuser -d -P LOCKSS -S -R
    Enter password for new role: goodPassword
    Enter it again: goodPassword

If you are using a port other than 5432, uncomment and edit all the
portNumber attributes in config/postgres.xml.

## Running a cluster

The individual services may be run from release or snapshot artifacts
downloaded from a Maven repository, or locally built from source.  To run
snapshot versions, change to this directory and run `./start`.  (Note: the
first time this is done Maven will fetch jars totalling .7-1.1GB.)  To use
locally built jars in sibling directories run `./start -local`.  (See
config/services.snapshot or config/services.local.)  The three essential
services (config service, repository service, poller/crawler service) are
run by default; to add the metadata services uncomment those lines in
config/services.xxx.  Run `./start -h` for more options.

## V3 Changes:

- config/services replaced by config/services.snapshot and
  config/services.local.  Format has changed again.

- Service jars may be fetched from a maven repository.

## V2 Changes:

- config/services format has changed.

- PostgreSQL used by default, must be installed, configured and started.
  Derby available

- All config and data are now stored below runcluster dir.  Service project
  source trees are no longer used (but are still needed to build the uber
  jars).  (Location of PostgreSQL data is separately configured during
  PostgreSQL installation.)

- Any AUs added and collected with the previous version will be gone, as
  well as any local configuration made through the UI.  The content in the
  repository may be preserved by copying laaws-repository-service/data/repo
  to laaws-dev-scripts/runcluster/data/repo, then starting the cluster and
  re-adding the AUs.
