#!/bin/bash -exv

pwd
mkdir --parents "${ENV_RUNNER_TEMP}"/actions-tool-cache/
cd "${GITHUB_ACTION_PATH}"
cp --recursive ./* "${ENV_RUNNER_TEMP}"/actions-tool-cache/
cd "${ENV_RUNNER_TEMP}"/actions-tool-cache/
ls -lha /opt/hostedtoolcache/node/
ls -lha /opt/hostedtoolcache/node/14.15.1/
ls -lha /opt/hostedtoolcache/node/14.15.1/x64
ls -lha /opt/hostedtoolcache/node/12.20.0/
ls -lha /opt/hostedtoolcache/node/12.20.0/x64
ls -lha ./
npm install --scripts-prepend-node-path=auto
npm run build --scripts-prepend-node-path=auto
node build/Release/hello/index.js
node build/Release/cache/index.js
ls -lha ./
cd -

set +xv
