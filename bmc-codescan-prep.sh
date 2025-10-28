#!/bin/bash

usage()
{
	echo usage: bmc-codescan-prep.sh TAG_OR_BRANCH
	echo bmc-codescan-prep.sh fw1120.00-1.67
    echo ""
    echo Enviromment Variables
    echo "CODESCANDIR=<workdir-for-scan>". If not passed, ./codescan is used
    echo "OUTPUTDIR=<dir-to-save-scan-report>".  If not passed, ./CODESCANDIR/report/ is used
    echo "SKIP_CODESCAN_PREPARE=1 to skip the prepare step"
    echo "SKIP_CODESCAN_RUN=1 to skip the analysis step"
}


### Create the workdir & outputdir
function prepare_workdir()
{
    # Code scan working dir. If not defined, use "./cppchkscan"
    mkdir -p ${CODESCANDIR}
    export CODESCANDIR=$(cd $CODESCANDIR; pwd)

    # Output dir. Use CODESCANDIR/report is not defined
   mkdir -p ${OUTPUTDIR}
   export OUTPUTDIR=$(cd $OUTPUTDIR; pwd)

   # DIRECTORIES (full absolute path)
   REPODIR=${CODESCANDIR}/${BRANCHSHORT}
   mkdir -p ${REPODIR}
   export REPODIR=$(cd ${REPODIR}; pwd)

}


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
    git pull
    . setup ${MACHINE}
}

# walk-thru each repo & prepare the codescan
function prepare_codescan()
{
    for REPONAME in ${REPOS}
    do
        SCAN_NAME=${GITDESC}-${REPONAME}
        echo "PREP: ~/bin/bmc-repo-codescan-prep.sh scan_name: $SCAN_NAME"

        #
        bitbake -e ${REPONAME} | grep "^WORKDIR=" > ./test.workdir.env
        WORKDIR=$(. ./test.workdir.env; echo $WORKDIR)
        [ -z "${WORKDIR}" ] && ( echo "NO REPO ${REPONAME}" && exit 1 )

        echo "========= Prepare codescan for repo $REPONAME ============"
        echo REPONAME=$REPONAME
        echo GITDESCR=${GITDESC}
        echo SCAN_NAME=${SCAN_NAME}
        echo WORKDIR=${WORKDIR}

        #
        # Location to extract under REPODIR/REPONAME so that it can be run for cppcheck
        devtool extract ${REPONAME} "$REPODIR/$REPONAME"

        bitbake ${REPONAME} -c cleanall
        bitbake ${REPONAME} -f -c do_fetch
        bitbake ${REPONAME}  -c do_unpack -f

    done
}

# run codescan
function run_codescan()
{
    cd ${REPODIR}
    for REPONAME in ${REPOS}
    do
        SCAN_NAME=${GITDESC}-${REPONAME}
        echo "RUN: ~/bin/bmc-repo-codescan-prep.sh repo: $SCAN_NAME"
  
        echo WORKSPACE=${REPODIR} UNIT_TEST_PKG=$REPONAME CPPCHECK_ONLY=1 ./openbmc-build-scripts/run-unit-test-docker.sh 2>&1 | tee log-cppchk-${REPONAME}.out
        WORKSPACE=${REPODIR} UNIT_TEST_PKG=$REPONAME CPPCHECK_ONLY=1 /home/myungbae/Codes/cppchk-ghe-1120/openbmc-build-scripts/run-unit-test-docker.sh 2>&1 | tee log-cppchk-${REPONAME}.out

    done
}


echo "PREP... ${REPOS}"
#exit 0

### MAIN ####
BRANCH=$1
[ -z "$BRANCH" ] && (usage; exit 1)

# SCAN Method
SKIP_CODESCAN_PREPARE=${SKIP_CODESCAN_PREPARE:-""}
SKIP_CODESCAN_RUN=${SKIP_CODESCAN_RUN:=""}

# MACHINE
MACHINE=${MACHINE:-p10bmc}

# Short branch name
BRANCHSHORT=$( echo "${BRANCH}" | awk -F  '.'  '{print $1}' )

#
# environment variables
#
CODESCANDIR=${CODESCANDIR:-./codescan}
# Output dir. Use CODESCANDIR/report is not defined
OUTPUTDIR=${OUTPDIR:-${CODESCANDIR}/report}
# List of Repos to scan.
REPOS=${REPOS:-""}

REPODIR=${CODESCANDIR}/${BRANCHSHORT}
mkdir -p ${REPODIR}
export REPODIR=$(cd ${REPODIR}; pwd)

# Use default repos if not passed
if [ -z "${REPOS}" ]
then
   REPOS="bmcweb pldm  \
          libpldm entity-manager dbus-sensors \
          openpower-proc-control phosphor-state-manager \
          phosphor-certificate-manager phosphor-inventory-manager"
   REPOS="bmcweb"
fi

echo "usage:  bmc-codescan-prep.sh $BRANCHSHORT"


prepare_workdir

[ -z "$SKIP_CODESCAN_PREPARE" ] && prepare_openbmc_repo

#
cd ${REPODIR}/openbmc
. setup p10${MACHINE}

DT=$(date +"%Y-%m%d-%H%M%S")
GITDESC=$(git describe)

[ -z "$SKIP_CODESCAN_PREPARE" ] && prepare_codescan

[ -z "$SKIP_CODESCAN_RUN" ] && run_codescan

exit 0


