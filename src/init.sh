#!/bin/bash -e

echo "# ----------------------------------------------------------"
echo "# Init the process"
echo "# ----------------------------------------------------------"
echo "ENV_IS_CACHED:      ${ENV_IS_CACHED}"
echo "ENV_CACHE:          ${ENV_CACHE}"
echo "ENV_SCRIPT:         ${ENV_SCRIPT}"
echo "ENV_SNAPSHOT:       ${ENV_SNAPSHOT}"
echo "ENV_EXCLUDE:        ${ENV_EXCLUDE}"
echo "ENV_RUNNER_TEMP:    ${ENV_RUNNER_TEMP}"
echo "GITHUB_ACTION_PATH: ${GITHUB_ACTION_PATH}"

if [ "${ENV_IS_CACHED}" = "true" ]; then
  echo "# ----------------------------------------------------------"
  echo "# Restore the cache"
  echo "# ----------------------------------------------------------"
  whereis pandoc || true
  find /home/ -iname hello.txt 2> /dev/null || true
  cp --verbose --force --recursive "${ENV_CACHE}"/. "${ENV_SNAPSHOT}"
  exit 0
fi

echo "# ----------------------------------------------------------"
echo "# Create the first snapshot"
echo "# ----------------------------------------------------------"
"${GITHUB_ACTION_PATH}"/src/snapshot.sh system_files_snapshot_01.txt

echo "# ----------------------------------------------------------"
echo "# Init the user script"
echo "# ----------------------------------------------------------"
"${ENV_SCRIPT}"

echo "# ----------------------------------------------------------"
echo "# Create the second snapshot after of the user changes"
echo "# ----------------------------------------------------------"
"${GITHUB_ACTION_PATH}"/src/snapshot.sh system_files_snapshot_02.txt

echo "# ----------------------------------------------------------"
echo "# Compare the differences and save in the cache directory"
echo "# ----------------------------------------------------------"
"${GITHUB_ACTION_PATH}"/src/cache_files.sh \
  system_files_snapshot_01.txt \
  system_files_snapshot_02.txt \
  system_files_snapshot_new_files.txt

echo "# ----------------------------------------------------------"
pwd
cat "${ENV_RUNNER_TEMP}"/system_files_snapshot_new_files.txt
echo "# ----------------------------------------------------------"
