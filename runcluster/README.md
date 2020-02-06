# Running LOCKSS in a Development Environment

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

Each service to be run must be locally built from source.  To run a minimal
cluster (config service, repository service, and poller/crawler service),
git clone laaws-configservice, laaws-repository-service, and laaws-poller
into sibling dirs of this project, mvn package each one, cd to this dir and
run "./start".  Additional services can be added by editing config/services
or by pointing to a different services file.  Run ./start -h for options.



## Changes from V1:

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
