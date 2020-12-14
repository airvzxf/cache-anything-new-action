#!/bin/bash -e

echo "ENV_RUNNER_TEMP:    ${ENV_RUNNER_TEMP}"
echo "ENV_DIRECTORY:      ${ENV_DIRECTORY}"
echo "ENV_EXCLUDE:        ${ENV_EXCLUDE}"
echo "Parameter #1:       ${1}"

FIND_INIT="sudo find"
FIND_INIT="${FIND_INIT} ${ENV_DIRECTORY}"
FIND_INIT="${FIND_INIT} -type f,l"
EXCLUDED=("${ENV_EXCLUDE}")
FIND_EXCLUDE=""
for EXCLUDE in ${EXCLUDED[*]}; do
  echo "EXCLUDE: ${EXCLUDE}"
  FIND_EXCLUDE="${FIND_EXCLUDE} -not \( -path \"${EXCLUDE}*\" -prune \)"
done
FIND_END=" > ${ENV_RUNNER_TEMP}/${1}"
FIND_END="${FIND_END} 2> /dev/null || true"

FIND="${FIND_INIT}${FIND_EXCLUDE}${FIND_END}"
echo "FIND: ${FIND}"
eval "${FIND}"

ls -lha "${ENV_RUNNER_TEMP}"/"${1}"
