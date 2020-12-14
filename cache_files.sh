#!/bin/bash

diff -C 1 \
      "${ENV_RUNNER_TEMP}/${1}" \
      "${ENV_RUNNER_TEMP}/${2}" \
      | grep -E "^\+" \
      | sed -E s/..// \
      > "${ENV_RUNNER_TEMP}"/"${3}"
< "${ENV_RUNNER_TEMP}/${3}" wc -l

ls -lha "${ENV_RUNNER_TEMP}"/

echo "# --------------------------------------------------------"
echo "# Make cache directory"

#rm -fR "${ENV_CACHE}"
#mkdir -p "${ENV_CACHE}"
#
#while IFS= read -r LINE
#do
#  sudo cp -a --parent "${LINE}" "${ENV_CACHE}"
#done < "${ENV_RUNNER_TEMP}/${3}"
