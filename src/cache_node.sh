#!/bin/bash -exv

pwd
mkdir --parents "${ENV_RUNNER_TEMP}"/actions-tool-cache/
cd "${GITHUB_ACTION_PATH}"
cp --recursive ./* "${ENV_RUNNER_TEMP}"/actions-tool-cache/
cd "${ENV_RUNNER_TEMP}"/actions-tool-cache/

ls -lha ./

npm install --scripts-prepend-node-path=auto
npm run build --scripts-prepend-node-path=auto

echo "${ENV_IDENTIFIER} ${ENV_VERSION}" > "${ENV_SCRIPT_BASE}"/hello.txt
ls -lha "${ENV_SCRIPT_BASE}"/hello.txt
cat "${ENV_SCRIPT_BASE}"/hello.txt

node ./build/Release/cache/index.js

ls -lha ./
cd -
pwd

set +xv
