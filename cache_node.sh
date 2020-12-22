#!/bin/bash -exv

pwd
mkdir --parents "${ENV_RUNNER_TEMP}"/actions-tool-cache/
cd "${GITHUB_ACTION_PATH}"
cp --recursive ./* "${ENV_RUNNER_TEMP}"/actions-tool-cache/
cd "${ENV_RUNNER_TEMP}"/actions-tool-cache/
ls -lha ./
npm install --scripts-prepend-node-path=auto
npm run build --scripts-prepend-node-path=auto
node build/Release/hello/index.js
node build/Release/cache/index.js
ls -lhaR ./
cd -

set +xv
