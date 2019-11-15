#!/bin/sh

# Copyright (c) 2019, Board of Trustees of Leland Stanford Jr. University
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation and/or
# other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# -- Configuration -------------------------------------------------------------

EMAIL=tortoise@lockss.org

export JAVA_HOME='/usr/lib/jvm/java'
export LANG='en_US'

MAVEN=/usr/bin/mvn
MAVEN_REPO=~/.m2.nightly
MVN_OPTS="-Dmaven.repo.local=${MAVEN_REPO}"

TMPROOT=`mktemp -t -d lockss-nightly.XXXX`
LOGFILE=${TMPROOT}/laaws-nightly.log

# -- Functions -----------------------------------------------------------------

# Bootstraps a build environment
function bootstrapBuildEnv() {
  if [ ! -d ${MAVEN_REPO} ]; then
    # Create nightly build Maven repository path exists
    mkdir -p ${MAVEN_REPO}

    # Checkout laaws-build project
    cd ${TMPROOT}
    git clone --depth=1 --branch develop git@code.stanford.edu:lockss/engineering/laaws-build.git 

    if [ $? -ne 0 -o ! -d ${TMPROOT}/laaws-build ]; then
      echo "Failed to checkout laaws-build"
      exit 1
    fi

    # Checkout laaws-build modules and switch them to the develop branch
    ( cd ${TMPROOT}/laaws-build; bin/clone; bin/foreach git checkout develop )

    # Bootstrap build environment by installing lockss-parent-pom
    ( cd ${TMPROOT}/laaws-build/lockss-parent-pom; ${MAVEN} ${MVN_OPTS} install )
  fi
}

# Runs the `mvn test` in the laaws-build project
function runAllTests() {
  # Change working directory to laaws-build
  cd ${TMPROOT}/laaws-build

  # Ensure we have the latest from develop
  bin/foreach git pull

  # Run `mvn test`
  ${MAVEN} ${MVN_OPTS} test > ${LOGFILE} 2>&1

  if [ $? -ne 0 ]; then
    # Detected Maven exit error
    sendBuildLog
    exit 1
  fi
}

# Sends an alert via email with the build log
function sendBuildLog() {
  ( echo "`date`: LAAWS build failure on `hostname` in ${TMPROOT}:";
    echo;
    echo "${LOGFILE}:";
    echo;
    cat ${LOGFILE};
    echo 
  ) | mailx -s "Nightly LAAWS build failure" ${EMAIL}
}

# -- Main ----------------------------------------------------------------------

bootstrapBuildEnv
runAllTests

if grep -q -E 'BUILD FAILURE$' ${LOGFILE}; then

  # Send log to mailing list
  echo "Build failure detected"
  sendBuildLog	
  exit 1

else

  # Cleanup temporary directory
  echo "Success"
  rm -rf ${TMPROOT}

fi
