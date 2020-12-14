#!/bin/bash -e

echo "GITHUB_ACTION_PATH:  ${GITHUB_ACTION_PATH}"
echo "ENV_RUNNER_TEMP:     ${ENV_RUNNER_TEMP}"
echo "inputs.identifier:   ${ENV_IDENTIFIER}"
echo "inputs.version:      ${ENV_VERSION}"
echo "inputs.directory:    ${ENV_DIRECTORY}"
echo "inputs.exclude:      ${ENV_EXCLUDE}"

FIND_INIT="sudo find"
FIND_INIT="${FIND_INIT} ${ENV_DIRECTORY}"
FIND_INIT="${FIND_INIT} -type f,l"
EXCLUDED=( "${ENV_EXCLUDE}" )
FIND_EXCLUDE=""
for EXCLUDE in ${EXCLUDED[*]}
do
  echo "EXCLUDE: ${EXCLUDE}"
  FIND_EXCLUDE="${FIND_EXCLUDE} -not \( -path \"${EXCLUDE}*\" -prune \)"
done
FIND_END=" > ${ENV_RUNNER_TEMP}/system_files_snapshot_01.txt"
FIND_END=" ${FIND_END} 2> /dev/null || true"

FIND="${FIND_INIT}${FIND_EXCLUDE}${FIND_END}"
echo "FIND: ${FIND}"
#eval ${FIND}

echo "Hello!" > "${ENV_RUNNER_TEMP}"/system_files_snapshot_01.txt
ls -lha "${ENV_RUNNER_TEMP}"/system_files_snapshot_01.txt

#sudo find / -type f,l > ${ENV_RUNNER_TEMP}/system_files.txt 2> /dev/null || true
