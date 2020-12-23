#!/bin/bash -e

echo "# ----------------------------------------------------------"
echo "# Generated cache directory"
echo "# ----------------------------------------------------------"
echo "ENV_RUNNER_TEMP:    ${ENV_RUNNER_TEMP}"
echo "ENV_CACHE:          ${ENV_CACHE}"
echo "Parameter #1:       ${1}"
echo "Parameter #2:       ${2}"
echo "Parameter #3:       ${3}"

diff -C 1 \
  "${ENV_RUNNER_TEMP}/${1}" \
  "${ENV_RUNNER_TEMP}/${2}" \
  | grep -E "^\+" \
  | sed -E s/..// \
    > "${ENV_RUNNER_TEMP}"/"${3}"

echo "Number of files: $(wc -l < "${ENV_RUNNER_TEMP}/${3}")"

echo "----------------------------------------"
echo "Directory ENV_RUNNER_TEMP: ${ENV_RUNNER_TEMP}"
echo "----------------------------------------"
ls -lha "${ENV_RUNNER_TEMP}"/

rm -fR "${ENV_CACHE}"
mkdir -p "${ENV_CACHE}"

while IFS= read -r LINE; do
  sudo cp -a --parent "${LINE}" "${ENV_CACHE}" 2> /dev/null || true
done < "${ENV_RUNNER_TEMP}/${3}"

echo "----------------------------------------"
echo "Directory ENV_CACHE: ${ENV_CACHE}"
echo "----------------------------------------"
ls -lha "${ENV_CACHE}"

echo "----------------------------------------"
echo "List all the cached files"
echo "----------------------------------------"
sudo du -h "${ENV_CACHE}"

echo "# ----------------------------------------------------------"
