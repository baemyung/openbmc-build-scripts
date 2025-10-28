#!/bin/bash
#
# Test for cppcheck filter
#
set -uo pipefail

args=$*

if [ -z "${UNIT_TEST_PKG}" ]
then
    echo "UNIT_TEST_PKG is not set"
    exit 1
fi

if [ -z "${WORKSPACE}" ]
then
	WORKSPACE=.
fi

printenv >  x1.env.out
echo "run-cppcheck: ARGS=$args"  | tee x2.chk.out

#cppcheck $args 2> x3.err.chk.out | tee x3.chk.out

## Note: Additional necessary opts
CPPCHK_DEF_OPTS=-D"__cppcheck__=1"

cppcheck ${CPPCHK_DEF_OPTS}  --template="{file}:{line}:{column}: {severity}: {message}" $args  2> x3.err.chk.out | tee x3.chk.out

LOGOUTPUT=${WORKSPACE}/cppchk.${UNIT_TEST_PKG}.error.out
echo "LOGOUTPUT=$LOGOUTPUT"

FAILED=0

echo "TEST:" > ${LOGOUTPUT}
while read -r filelinecol severity remaining; do
    #echo "Filename:Line:Column: $filelinecol" >> ${LOGOUTPUT}
    #echo "severity: $severity" >> ${LOGOUTPUT}
    #echo "remaining: $remaining" >> ${LOGOUTPUT}
    #echo "---" >> ${LOGOUTPUT}
    if [[ "$filelinecol" == "/"* ]]
    then
        continue
    fi
    if [[ "$severity" == "warning:" || "$severity" == "error:" ]]
    then
        echo "Filename:Line:Column: $filelinecol" >> ${LOGOUTPUT}
	echo "severity: $severity" >> ${LOGOUTPUT}
	echo "remaining: $remaining" >> ${LOGOUTPUT}
	echo "---" >> ${LOGOUTPUT}
        FAILED=1
    fi
done < x3.err.chk.out

if [[ $FAILED -ne 0 ]]
then
	echo "cppcheck failed"
	cat ${LOGOUTPUT}
	exit 1
fi
