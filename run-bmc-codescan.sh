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
    echo 'WORKSPACE=$(pwd) BRANCH=fw1120.00-1.70 openbmc-build-scripts/run-bmc-codescan.sh'
    echo ""
    echo "Notes:"
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
[ -z "$SKIP_CODESCAN_PREPARE" ] && [ -z "$BRANCH" ] && (usage; exit 1)

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
    cd ${WORKSPACE}
    if [ ! -d ./openbmc ]
    then
        echo git clone git@github.ibm.com:openbmc/openbmc
        git clone git@github.ibm.com:openbmc/openbmc
    fi

     cd ${WORKSPACE}/openbmc

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
        echo "===== Extract repo $REPONAME on $WORKSPACE/$REPONAME ====="
        devtool extract ${REPONAME} "$WORKSPACE/$REPONAME"
        bitbake ${REPONAME} -f -c do_fetch
        bitbake ${REPONAME} -f -c do_unpack
    done
}

# run codescan
function run_codescan()
{
    cd ${WORKSPACE}
    for REPONAME in ${REPOLIST}
    do
        UNIT_TEST_PKG=$REPONAME CPPCHECK_ONLY=1 ./openbmc-build-scripts/run-unit-test-docker.sh
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

# Use default repos if not passed
if [ -z "${REPOLIST}" ]
then
   REPOLIST="
        bmcweb \
        dbus-sensors \
        entity-manager \
        ibm-acf \
        ibm-panel \
        ipl \
        libpldm \
        obmc-console \
        openpower-debug-collector \
        openpower-hw-diags \
        openpower-hw-isolation \
        openpower-occ-control \
        openpower-vpd-parser \
        phosphor-bmc-code-mgmt \
        phosphor-certificate-manager \
        phosphor-dbus-interfaces \
        phosphor-debug-collector \
        phosphor-host-ipmid \
        phosphor-inventory-manager \
        phosphor-led-manager \
        phosphor-logging \
        phosphor-networkd \
        phosphor-power \
        phosphor-state-manager \
        phosphor-user-manager \
        pldm \
        powervm-handler \
        service-config-manager \
        telemetry \
        "
fi

echo "usage:  run-bmc-codescan.sh $BRANCH"


#prepare_workdir

[ -z "$SKIP_CODESCAN_PREPARE" ] && prepare_openbmc_repo

#
cd ${WORKSPACE}/openbmc
. setup p10${MACHINE}

DT=$(date +"%Y-%m%d-%H%M%S")
GITDESC=$(git describe)

[ -z "$SKIP_CODESCAN_PREPARE" ] && prepare_codescan

[ -z "$SKIP_CODESCAN_RUN" ] && run_codescan

exit 0
