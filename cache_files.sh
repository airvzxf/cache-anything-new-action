#!/bin/bash -e

diff -C 1 \
  "${ENV_RUNNER_TEMP}/${1}" \
  "${ENV_RUNNER_TEMP}/${2}" \
  | grep -E "^\+" \
  | sed -E s/..// \
    > "${ENV_RUNNER_TEMP}"/"${3}"

echo "Number of files: $(wc)" < "${ENV_RUNNER_TEMP}/${3}" -l

ls -lha "${ENV_RUNNER_TEMP}"/

rm -fR "${ENV_CACHE}"
mkdir -p "${ENV_CACHE}"

while IFS= read -r LINE
do
  sudo cp -a --parent "${LINE}" "${ENV_CACHE}" 2> /dev/null || true
done < "${ENV_RUNNER_TEMP}/${3}"
