#!/bin/bash -exv

pwd
mkdir -p /home/runner/work/_temp/actions-tool-cache/
cd "${GITHUB_ACTION_PATH}"
cp package.json package-lock.json cache.js /home/runner/work/_temp/actions-tool-cache/
cd /home/runner/work/_temp/actions-tool-cache/
npm install
npm node cache.js
cd -

set +xv
