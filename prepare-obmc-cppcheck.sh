#!/bin/bash
###############################################################################
#
# This script is for preparing the cppcheck repo environment for obmc-phosphor-image
#
###############################################################################
#
# Required Inputs:
#   WORKSPACE:  Directory which contains the extracted openbmc-build-scripts
#               directory
#   BRANCH:     Optional, branch or tag to build from each of the
#               openbmc repositories. default is master, which will be
#               used if input branch not provided or not found
#   REPOLIST:   List of repos to do the cppcheck.

usage()
{
	echo "usage: run-obmc-cppcheck.sh"
    echo "Example:"
    echo 'WORKSPACE=$(pwd) BRANCH=fw1120.00-1.70 ./openbmc-build-scripts/prepare-obmc-cppcheck.sh '
    echo ""
}

# Default variables
BRANCH=${BRANCH:-""}
WORKSPACE=${WORKSPACE:-$(pwd)}
REPOLIST=${REPOLIST:-""}
OBMC_BUILD_SCRIPTS="openbmc-build-scripts"

#
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

# walk-thru each repo & prepare the cppcheck
function prepare_cppcheck()
{
    for REPONAME in ${REPOLIST}
    do
        echo "===== Extract repo $REPONAME on $WORKSPACE/$REPONAME ====="
        devtool extract ${REPONAME} "$WORKSPACE/$REPONAME"
        bitbake ${REPONAME} -f -c do_fetch
        bitbake ${REPONAME} -f -c do_unpack
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
        phosphor-power \
        phosphor-state-manager \
        phosphor-user-manager \
        pldm \
        powervm-handler \
        service-config-manager \
        telemetry \
        "
fi

echo "usage:  prepare-obmc-cppcheck.sh for branch ${BRANCH}"

#prepare_workdir
prepare_openbmc_repo

#
cd ${WORKSPACE}/openbmc
. setup ${MACHINE}

prepare_cppcheck


exit 0
