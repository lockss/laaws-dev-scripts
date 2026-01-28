#!/bin/sh
#
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

# Nightly build script of the classic LOCKSS daemon

export JAVA_HOME='/usr/lib/jvm/java'
#export JAVA_HOME='/usr/lib/jvm/jdk1.7.0_80/'
export PATH="${JAVA_HOME}/bin:$PATH"
export LANG='en_US.UTF-8'

PCT_SWAP_USED_THRESHOLD=90  # Integer percentage (0-100)
TMPROOT=$(mktemp -t -d lockss-nightly.XXXX)
LOGFILE=${TMPROOT}/lockss-nightly.log
RPMS=/tmp/rpms/
ANT=/usr/bin/ant

JAVATMP=${TMPROOT}/javatmp
mkdir -p ${JAVATMP}

EMAIL=tortoise@lockss.org
#EMAIL=dlvargas@stanford.edu
#EMAIL=tal@lockss.org
#EMAIL=lockss-sysadmin@lockss.org

send_failure_email() {
    REASON="$1"
    BODY="$2"

    printf "LOCKSS daemon nightly build failure on %s in %s at %s:\n\n%s\n" \
        "$(hostname)" \
        "${TMPROOT}" \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "${BODY}" \
    | mailx -s "[ERROR] Nightly build failure: ${REASON}" "${EMAIL}"
}

# Check that there are no running LOCKSS daemons from previous builds
LOCKSS_DAEMON_INSTANCES=$(jps -l 2>/dev/null | grep -c 'LockssDaemon')

if [ "${LOCKSS_DAEMON_INSTANCES}" -gt 0 ]; then
    JAVA_PIDS_LSTART="$(printf "\n\n%s" "$(ps -o pid,lstart -p "$(jps -l | grep LockssDaemon | awk '{print $1}' | xargs echo | tr ' ' ',')")")"

    send_failure_email \
        "Previous LOCKSS daemon instances still running" \
        "Found ${LOCKSS_DAEMON_INSTANCES} LOCKSS daemon instance(s) from a previous nightly build:${JAVA_PIDS_LSTART}"
    exit 1
fi

# Check that swap usage is below threshold
SWAP_TOTAL=$(awk '/^SwapTotal:/ {print $2}' /proc/meminfo)
SWAP_FREE=$(awk '/^SwapFree:/ {print $2}' /proc/meminfo)
SWAP_USED=$((SWAP_TOTAL - SWAP_FREE))
PCT_SWAP_USED=$((SWAP_USED * 100 / SWAP_TOTAL))

if [ "${PCT_SWAP_USED}" -gt "${PCT_SWAP_USED_THRESHOLD}" ]; then
    SWAP_STATS="$(printf "\n\nSwap total: %s KB\nSwap used: %s KB\nSwap free: %s KB\n" \
                 ${SWAP_TOTAL} \
                 ${SWAP_USED} \
                 ${SWAP_FREE})"

    send_failure_email \
        "Swap usage exceeded threshold" \
        "Swap space usage at ${PCT_SWAP_USED}% (threshold: ${PCT_SWAP_USED_THRESHOLD}%)${SWAP_STATS}"
    exit 1
fi

echo "Starting build at `date`" >> ${LOGFILE}
# Check out tree
( cd ${TMPROOT}; git clone --depth=1 --branch master https://github.com/lockss/lockss-daemon.git ) >> ${LOGFILE} 2>&1
if [ $? -ne 0 ]; then
    ( echo "`date`: LOCKSS daemon nightly build failure on `hostname` in ${TMPROOT}"
      echo "Build failed: Could not clone LOCKSS daemon Git repository"
      cat ${LOGFILE};
      echo
    ) | mailx -s "[ERROR] Nightly build failure: Git clone failed" ${EMAIL}
    exit 1
fi

# Build and test-all
( cd ${TMPROOT}/lockss-daemon; env; ${ANT} test-all -Djava.io.tmpdir=${JAVATMP} ) >> ${LOGFILE} 2>&1

# Notify Tortoise of any failures from running test-all
if grep -q -E '^BUILD FAILED$' ${LOGFILE}; then

	# Yes "BUILD FAILED" in log: Test whether there are any unit test result logs
	if [ -n "$(find {$TMPROOT}/lockss-daemon/test/results -maxdepth 1 -type f -iname '*.txt' 2> /dev/null)" ]; then

		# YES: Determine which unit test failed and attach its log to the email
		( cd ${TMPROOT}/lockss-daemon/test/results;
		  echo "`date`: LOCKSS daemon build failure on `hostname` in ${TMPROOT}:";
		  for A in `grep -L -E "(Failures|Errors): 0" *.txt`; do
			echo;
			echo "${A}:";
			# cat ${A};
			tr -d '\015' < ${A};
			echo;
		  done;
		  echo; 
		) | mailx -s "[ERROR] Nightly build failure: Failed running test-all" ${EMAIL}

	else

		# NO: Ant did not reach the unit tests; attach the entire ant output instead
		( echo "`date`: LOCKSS daemon build failure on `hostname` in ${TMPROOT}:";
		  echo;
		  echo "${LOGFILE}:";
		  echo;
		  cat ${LOGFILE};
		  echo 
		) | mailx -s "[ERROR] Nightly build failure: Failed running test-all" ${EMAIL}

	fi

else

	# No "BUILD FAILED" in log: Run test-stf
	( cd ${TMPROOT}/lockss-daemon; env; ${ANT} test-stf -Dsuite=postTagTests -Djava.io.tmpdir=${JAVATMP} ) >> ${LOGFILE} 2>&1

	if grep -q -E '^BUILD FAILED$' ${LOGFILE}; then

		# YES: test-stf did not pass; send an email notification
		( echo "`date`: The LOCKSS nightly build failed while running test-stf on `hostname` in ${TMPROOT}:";
		  echo;
		  echo "${LOGFILE}:";
		  echo;
		  cat ${LOGFILE};
		  echo 
		) | mailx -s "[ERROR] Nightly build failure: Failed running test-stf" ${EMAIL}

	else

		# NO: test-all and test-stf passed; build an RPM and clean up

		# Build RPM
		RELEASE_NUM=`grep -P '^\d+\.\d+\.\d+$' ${TMPROOT}/lockss-daemon/src/defaultreleasename`
		( cd ${TMPROOT}/lockss-daemon && ${ANT} clean rpm -Drpmrelease=1 -Dreleasename=${RELEASE_NUM} &&
		  mkdir -p ${RPMS} && cp ${TMPROOT}/lockss-daemon/rpms/RPMS/noarch/*.rpm ${RPMS}
		) >> ${LOGFILE} 2>&1
		if [ $? -ne 0 ]; then
		    ( echo "`date`: LOCKSS daemon build failure on `hostname` in ${TMPROOT}"
		      echo "RPM build failed:"
		      cat ${LOGFILE};
		      echo
		    ) | mailx -s "[ERROR] Nightly build failure: Failed to build RPM" ${EMAIL}
		    exit 1
		fi

		# Clean up
		( cd /tmp; rm -rf ${TMPROOT} )

	fi

fi
