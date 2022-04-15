#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
export JAVA_POST_PROCESS_FILE="clang-format -i"

usage() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] -m <client module> -i <spec file> -o <ouput dir>

OpenApi code generation for java client modules.

Available options:

-h, --help      Print this help and exit
-v, --verbose   Print script debug info
-m <client mod>, --module <client mod> The name of client module eg. repo, cfg, poll
-i <spec file>, --input	<spec file>		 The location of the OpenAPI spec
-o <ouput dir>, --output <ouput dir>   The output directory (default: ./out/<module>)
EOF
  exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  # default values of variables set from params
  flag=0
  module=''
  input=''
  output=''

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    --no-color) NO_COLOR=1 ;;
    -m | --module)  # The client module
      module="${2-}"
      shift
      ;;
    -i | --input) # The input file
      input="${2-}"
      shift
      ;;
    -o | --output) # The output directory
      output="${2-}"
      shift
      ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")

  # check required params and arguments
  [[ -z "${module-}" ]] && die "Missing required name: module"
  [[ -z "${input-}" ]] && die "Missing required parameter: input"
  [[ -z "${output-}" ]] && output="./out/${module}"

  return 0
}

generate_code() {
	openapi-generator generate -g java \
--library=okhttp-gson \
--group-id=org.lockss.laaws \
--artifact-id=laaws-java-client \
--model-package=org.lockss.laaws.model.${module} \
--api-package=org.lockss.laaws.api.${module} \
--invoker-package=org.lockss.laaws.client.${module} \
--additional-properties=hideGenerationTimestamp=true \
--additional-properties=serializableModel=true \
--additional-properties=serializationLibrary=gson \
--additional-properties=dateLibrary=java8 \
--skip-validate-spec \
--enable-post-process-file \
-i ${input} \
-o ${output}

}
parse_params "$@"
setup_colors

# script logic here
generate_code