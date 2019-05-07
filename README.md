# LOCKSS Development Scripts

`laaws-dev-scripts` is a collection of scripts involved in the development of LOCKSS software.

For more developer information, please visit the [Developers](https://lockss.github.io/developers) section of the [LOCKSS Documentation Portal](https://lockss.github.io/)

## Git

This project's stable branch is the `master` branch:

    git clone https://github.com/lockss/laaws-dev-scripts

This project's development branch is the `develop` branch:

    git clone --branch develop git@github.com:lockss/laaws-dev-scripts

## `runclass`

    Usage: runclass <args> <java-args> <class-name> <class-args>
    Runs <class-name> <class-args>
    Must be run in a Maven project base dir.
      -q                  Quiet
      -classpath <path>   Appends <path> to classpath
      -testcp             Use target/test-classpath (default)
      -runcp              Use target/run-classpath
      -warn | -warning    Set default log level to WARNING
      -debug              Set default log level to DEBUG
      -debug2             Set default log level to DEBUG2
      -<n>  (e.g., -9)    run with Java version <n>.  Expects JAVA_<n>_HOME
                          env var to point to Java <n> install dir

## `runservice`

    Run LAAWS service.
    By default, runs the service in the current project dir or the
    closest parent that contains a pom.xml.  The -dir argument may be
    used to specify an alternate project directory.
    By default, runs the service using Maven.  With the -j arg, runs
    the service directly in java using the fat JAR.
    Usage: runservice [-options]
    Options:
      -o           Invoke maven in offline mode
      -j           Run using fat jar instead of maven
      -dir <dir>   Run in <dir>
      -p <url>     Load config from prop server <url>
      -p <name>    Load config from http://props.lockss.org:8001/<name>/lockss.xml
      -c <url>     Load config from ConfigSvc at <url>
      -c <host>    Load config from ConfigSvc at <host>:24620
      -c <host:port> Load config from ConfigSvc at <host>:<port>
      -g <group>    Set polling group to <group>
      -Dprop=val    Set System property
