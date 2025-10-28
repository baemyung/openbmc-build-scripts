#!/bin/bash
###############################################################################
#
# This build script is for running the cppcheck as Docker containers.
#
###############################################################################
#
# Required Inputs:
#   WORKSPACE:      Directory which contains the extracted openbmc-build-scripts
#                  directory
#   BRANCH:          Optional, branch to build from each of the
#                    openbmc repositories. default is master, which will be
#                    used if input branch not provided or not found
#   REPOLIST:          List of repos to do the cppcheck
#
#   SKIP_CODESCAN_PREPARE=1 to skip the prepare step
#   SKIP_CODESCAN_RUN=1 to skip the analysis step

usage()
{
	echo "usage: BRANCH=<branch> run-bmc-codescan.sh"
    echo "Example:"
    echo "WORKSPACE=$(pwd) BRANCH=fw1120.00-1.67 openbmc-build-scripts/run-bmc-codescan.sh"
    echo ""
    echo "Notes:"
    echo "LOGS are under <WORKSPACE>/logs/"
}

# Default variables
BRANCH=${BRANCH:-""}
WORKSPACE=${WORKSPACE:-$(pwd)}
REPOLIST=${REPOLIST:-""}
OBMC_BUILD_SCRIPTS="openbmc-build-scripts"
SKIP_CODESCAN_PREPARE=${SKIP_CODESCAN_PREPARE:-""}
SKIP_CODESCAN_RUN=${SKIP_CODESCAN_RUN:-""}

REPOLIST=$(echo $REPOLIST)
#

[ -z "$BRANCH" ] && (usage; exit 1)

# Check workspace, build scripts, and package to be unit tested exists
if [ ! -d "${WORKSPACE}" ]; then
    echo "Workspace(${WORKSPACE}) doesn't exist, exiting..."
    exit 1
fi
if [ ! -d "${WORKSPACE}/${OBMC_BUILD_SCRIPTS}" ]; then
    echo "Package(${OBMC_BUILD_SCRIPTS}) not found in ${WORKSPACE}, exiting..."
    exit 1
fi

##

# Clone/Extract openbmc repo
function prepare_openbmc_repo()
{
    cd ${REPODIR}
    if [ ! -d ./openbmc ]
    then
        echo git clone git@github.ibm.com:openbmc/openbmc
        git clone git@github.ibm.com:openbmc/openbmc
    fi

     cd ${REPODIR}/openbmc

    ##
    git fetch --all
    git checkout ${BRANCH}
    . setup ${MACHINE}
}

# walk-thru each repo & prepare the codescan
function prepare_codescan()
{
    for REPONAME in ${REPOLIST}
    do
        echo "===== Extract repo $REPONAME on $REPODIR/$REPONAME ====="
        devtool extract ${REPONAME} "$REPODIR/$REPONAME"
        #bitbake ${REPONAME} -c cleanall
        bitbake ${REPONAME} -f -c do_fetch
        bitbake ${REPONAME} -f -c do_unpack
    done
}

# run codescan
function run_codescan()
{
    cd ${REPODIR}
    for REPONAME in ${REPOLIST}
    do
        SCAN_NAME=${GITDESC}-${REPONAME}
        echo "RUN: ~/bin/bmc-repo-codescan-prep.sh repo: $SCAN_NAME"
  
        echo WORKSPACE=${REPODIR} UNIT_TEST_PKG=$REPONAME CPPCHECK_ONLY=1 ./openbmc-build-scripts/run-unit-test-docker.sh 2>&1 | tee log-cppchk-${REPONAME}.out
        WORKSPACE=${REPODIR} UNIT_TEST_PKG=$REPONAME CPPCHECK_ONLY=1 ./openbmc-build-scripts/run-unit-test-docker.sh 2>&1 | tee logs/log-cppchk-${REPONAME}.out

    done
}


### MAIN ####


# MACHINE
MACHINE=${MACHINE:-p10bmc}
export MACHINE

# environment variables
#
# List of Repos to scan.
REPOLIST=${REPOLIST:-""}

export REPODIR=${WORKSPACE}

# Use default repos if not passed
if [ -z "${REPOLIST}" ]
then
   REPOLIST="bmcweb pldm  \
          libpldm entity-manager dbus-sensors \
          openpower-proc-control phosphor-state-manager \
          phosphor-certificate-manager phosphor-inventory-manager"
   #REPOLIST="bmcweb"
fi

echo "usage:  run-bmc-codescan.sh $BRANCH"


#prepare_workdir

[ -z "$SKIP_CODESCAN_PREPARE" ] && prepare_openbmc_repo

#
cd ${REPODIR}/openbmc
. setup p10${MACHINE}

DT=$(date +"%Y-%m%d-%H%M%S")
GITDESC=$(git describe)

[ -z "$SKIP_CODESCAN_PREPARE" ] && prepare_codescan

[ -z "$SKIP_CODESCAN_RUN" ] && run_codescan

exit 0
