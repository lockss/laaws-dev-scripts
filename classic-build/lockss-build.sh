#!/bin/sh

# Verify version syntax
function verifyrelease {
    if echo $1 | grep -Pq "^\d+\.\d+\.\d+"; then
        return 0
    fi
    return 1
}

# Verify branch syntax
function verifybranch {
    if echo $1 | grep -Pq "^\d+\.\d+"; then
        return 0
    fi
    return 1
}

# Fetch changes from remote and set HEAD; discard any changes
function gitreset {
        #cd /lockss

        # Clone the GitHub repository
        if [ ! -d lockss-daemon ]; then
            git clone git@github.com:lockss/lockss-daemon.git
            cd lockss-daemon
	else
            cd lockss-daemon
        fi

        # Fetch changes from remote and set HEAD to the release; discard any changes
        git checkout $1
        git pull 
        git reset --hard $1
}

# Creates a new branch from master
function create_branch {
    if verifybranch $1; then
        RELEASE_NUM=$1
        BRANCH="branch_`echo $RELEASE_NUM | cut -d. --output-delimiter=- -f1,2`"

        gitreset master

        git branch $BRANCH
        git push --set-upstream origin $BRANCH
    fi
}

# Tags a release
function tag_release {
    if verifyrelease $1; then
        RELEASE_NUM=$1
        BRANCH="branch_`echo $RELEASE_NUM | cut -d. --output-delimiter=- -f1,2`"
        RELEASE="release-candidate_`echo $RELEASE_NUM | tr '.' '-' | sed -r 's/-([[:digit:]]+)$/-b\1/'`"

	gitreset $BRANCH
        #git checkout $BRANCH
        #git pull

	#ant clean test-all
	# ant clean

	# Create and update tags if there were no errors
	if [ $? -eq 0 ]; then
	    # Create release branch
	    git tag $RELEASE

            # Update last_stable tag
	    git push origin :refs/tags/last_stable
	    git tag -f last_stable

            # Push changes upstream
            git push -u origin --tags
        fi
    fi
}

# Publishes an existing release
function publish_release {
    if verifyrelease $1; then
        RELEASE_NUM=$1
        RELEASE="release-candidate_`echo $RELEASE_NUM | tr '.' '-' | sed -r 's/-([[:digit:]]+)$/-b\1/'`"

        gitreset $RELEASE

        # Update last_stable tag
	git push origin :refs/tags/last_released_daemon
	git tag -f last_released_daemon
    fi
}

# Builds an RPM
function buildrpm {
    if verifyrelease $1; then
        RELEASE_NUM=$1
        RELEASE="release-candidate_`echo $RELEASE_NUM | tr '.' '-' | sed -r 's/-([[:digit:]]+)$/-b\1/'`"
        echo "Building ${RELEASE}:"

        # Fetch latest and set HEAD to ${RELEASE}
        gitreset ${RELEASE}

        # Build the RPM
        ant clean rpm -Drpmrelease=1 -Dreleasename=${RELEASE_NUM}

        # Copy the RPM to the persistent volume (ok if /lockss and /lockss/rpms are the same volume)
        mkdir -p rpms
        cp lockss-daemon/rpms/RPMS/noarch/lockss-daemon-${RELEASE_NUM}-1.noarch.rpm rpms
    else
        echo "Invalid release"
        exit 1
    fi
}

# Passthrough to ant against master
function runant {
    echo "Running ant:"
    gitreset "origin/master"
    ant $@
}

# Main entry point
case $1 in
    "create-branch")
        shift
        create_branch $@
    ;;
    "tag-release")
        shift
        tag_release $@
    ;;
    "publish-release")
        shift
        publish_release $@
    ;;
    "build-rpm")
        buildrpm $2
    ;;
    "ant")
        shift
        runant $@
    ;;
    "test-all")
        runant "test-all"
    ;;
    *)
        echo "Operation $1 is not supported"
        exit 1
esac

