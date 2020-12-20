#!/bin/bash -exv

pwd
mkdir -p "${ENV_RUNNER_TEMP}"actions-tool-cache/
cd "${GITHUB_ACTION_PATH}"
cp package.json package-lock.json cache.js "${ENV_RUNNER_TEMP}"actions-tool-cache/
cd "${ENV_RUNNER_TEMP}"actions-tool-cache/
ls -lha ./
npm install
npm run-script cache.js
cd -

set +xv
