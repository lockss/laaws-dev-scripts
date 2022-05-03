# Generating a Java client for a LAAWS service.

**Version 1.0-dev**

`generate-client.sh` is a script to aid in the generation of a java client to access a LAAWS service.

## `generate-client.sh`

    Usage: generate_client.sh [-h] [-v] -m <client module> -i <spec file> -o <ouput dir>

    OpenApi code generation for java client modules.

    Available options:

    -h, --help      Print this help and exit
    -v, --verbose   Print script debug info
    -m <client mod>, --module <client mod> The name of client module eg. repo, cfg, poll
    -i <spec file>, --input	<spec file>	   The location of the OpenAPI spec
    -o <ouput dir>, --output <ouput dir>   The output directory (default: out/<module>)
