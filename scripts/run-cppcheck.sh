#!/bin/bash -xe
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

printenv >  x1.env.out
echo "run-cppcheck: ARGS=$args"  | tee x2.chk.out

#cppcheck $args 2> x3.err.chk.out | tee x3.chk.out


cppcheck --template="{file}:{line}:{column}: {severity}: {message}" $args 2> x3.err.chk.out | tee x3.chk.out

FAILED=0

echo "TEST:" > x3.err.parsed.out
while read -r filelinecol severity remaining; do
    echo "Filename:Line:Column: $filelinecol" >> x3.err.parsed.out
    echo "severity: $severity" >> x3.err.parsed.out
    echo "remaining: $remaining" >> x3.err.parsed.out
    echo "---" >> x3.err.parsed.out
    if [[ "$filelinecol" == "/"* ]]
    then
        continue
    fi
    if [[ "$severity" == "warning:" || "$severity" == "error:" ]]
    then
        FAILED=1
        exit 1
    fi
done < x3.err.chk.out
