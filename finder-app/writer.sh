#!/bin/sh

WRITEFILE="${1}"
WRITESTR="${2}"

if [ -z "${WRITEFILE}" ]; then
	>&2 echo "ERROR: Argument 1 should be a file"
	exit 1
elif [ -z "${WRITESTR}" ]; then
	>&2 echo "ERROR: Argument 2 should be a string to write"
	exit 1
fi

DIRNAME=$(dirname "${1}")
if ! mkdir -p "${DIRNAME}"; then
	>&2 echo "ERROR: failed to create ${DIRNAME}"
	exit 1
elif ! echo "${WRITESTR}" > "${WRITEFILE}"; then
	>&2 echo "ERROR: failed to write ${WRITESTR} to ${WRITEFILE}"
	exit 1
fi
