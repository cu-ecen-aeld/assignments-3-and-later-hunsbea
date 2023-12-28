#!/bin/sh

FILESDIR="${1}"
SEARCHSTR="${2}"

if [ -z "${FILESDIR}" ]; then
	>&2 echo "ERROR: Argument 1 should be a path or file"
	exit 1
elif [ -z "${SEARCHSTR}" ]; then
	>&2 echo "ERROR: Argument 2 should be a string to search for"
	exit 1
elif [ ! -d "${FILESDIR}" ]; then
	>&2 echo "ERROR: Cannot find path or file: $1"
	exit 1
fi

# Performance could be improved by first grepping for lines and
# then inferring the number of files from the lines, but I've
# prioritized code simplicity here.
NUM_FILES=$(grep -rl "${SEARCHSTR}" "${FILESDIR}" | wc -l)
NUM_LINES=$(grep -r "${SEARCHSTR}" "${FILESDIR}" | wc -l)

echo "The number of files are ${NUM_FILES} and the number of matching lines are ${NUM_LINES}"
