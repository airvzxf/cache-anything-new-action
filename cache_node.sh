#!/bin/bash -exv

pwd
echo "${ENV_IDENTIFIER} ${ENV_VERSION}" > "${ENV_SCRIPT_BASE}"/hello.txt
mkdir --parents "${ENV_RUNNER_TEMP}"/actions-tool-cache/
cd "${GITHUB_ACTION_PATH}"
cp --recursive ./* "${ENV_RUNNER_TEMP}"/actions-tool-cache/
cd "${ENV_RUNNER_TEMP}"/actions-tool-cache/
ls -lha ./
npm install --scripts-prepend-node-path=auto
npm run build --scripts-prepend-node-path=auto
node build/Release/hello/index.js
ls -lha "${ENV_SCRIPT_BASE}"/hello.txt
cat "${ENV_SCRIPT_BASE}"/hello.txt
printenv
#node build/Release/cache/index.js
node ./build/Release/restore/index.js
node ./build/Release/save/index.js
ls -lha ./
cd -

echo "ACTIONS_CACHE_URL: ${ACTIONS_CACHE_URL}"
echo "ACTIONS_RUNTIME_URL: ${ACTIONS_RUNTIME_URL}"

set +xv
