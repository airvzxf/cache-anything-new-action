#!/bin/bash -e

echo "# ----------------------------------------------------------"
echo "# Init the process"
echo "# ----------------------------------------------------------"
echo "ENV_IDENTIFIER:     ${ENV_IDENTIFIER}"
echo "ENV_VERSION:        ${ENV_VERSION}"
echo "ENV_CACHE:          ${ENV_CACHE}"
echo "ENV_SCRIPT:         ${ENV_SCRIPT}"
echo "ENV_SNAPSHOT:       ${ENV_SNAPSHOT}"
echo "ENV_EXCLUDE:        ${ENV_EXCLUDE}"
echo "ENV_RUNNER_TEMP:    ${ENV_RUNNER_TEMP}"
echo "GITHUB_ACTION_PATH: ${GITHUB_ACTION_PATH}"
echo "ENV_IS_CACHED:      ${ENV_IS_CACHED}"

echo "----------------------------------------"
echo "Directory GITHUB_ACTION_PATH: ${GITHUB_ACTION_PATH}"
echo "----------------------------------------"
ls -lha "${GITHUB_ACTION_PATH}"

echo "----------------------------------------"
echo "Directory ENV_SCRIPT_BASE: ${ENV_SCRIPT_BASE}"
echo "----------------------------------------"
ls -lha "${ENV_SCRIPT_BASE}"

echo "# ----------------------------------------------------------"
echo "# Create the first snapshot"
echo "# ----------------------------------------------------------"
#"${GITHUB_ACTION_PATH}"/src/snapshot.sh system_files_snapshot_01.txt

echo "# ----------------------------------------------------------"
echo "# Init the user script"
echo "# ----------------------------------------------------------"
"${ENV_SCRIPT}"

echo "# ----------------------------------------------------------"
echo "# Create the second snapshot after of the user changes"
echo "# ----------------------------------------------------------"
#"${GITHUB_ACTION_PATH}"/src/snapshot.sh system_files_snapshot_02.txt

echo "# ----------------------------------------------------------"
echo "# Compare the differences and save in the cache directory"
echo "# ----------------------------------------------------------"
#"${GITHUB_ACTION_PATH}"/src/cache_files.sh \
#  system_files_snapshot_01.txt \
#  system_files_snapshot_02.txt \
#  system_files_snapshot_new_files.txt

echo "# ----------------------------------------------------------"
echo "ENV_IS_CACHED: ${ENV_IS_CACHED}"
echo "# ----------------------------------------------------------"
