#!/usr/bin/env bash
# Changes the system the way a typical install script does. tests/verify.sh checks that every
# change is present again after the cache is restored on a fresh machine.
set -euo pipefail

if [[ "$(id -u)" == 0 ]]; then sudo() { "$@"; }; fi

# A package: new files with old modification times, plus changes to the dpkg database.
sudo apt-get update -qq
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends cowsay

# A new system user: changes /etc/passwd, /etc/group and /etc/shadow. No home directory,
# because hosted runners copy several hundred MB of toolchains from /etc/skel into it.
sudo useradd --system --no-create-home can-test

# Ownership, permissions, special bits, symbolic links and empty directories.
sudo mkdir -p /opt/can-test/empty /opt/excluded
echo 'secret' | sudo tee /opt/can-test/secret >/dev/null
sudo chown can-test: /opt/can-test/secret
sudo chmod 600 /opt/can-test/secret
printf '#!/bin/sh\necho can-test-ok\n' | sudo tee /opt/can-test/tool >/dev/null
sudo chmod 4755 /opt/can-test/tool
sudo ln -s /opt/can-test/tool /usr/local/bin/can-test-tool

# A change to a file that already existed.
echo '# can-test' | sudo tee -a /etc/environment >/dev/null

# Files that must not be cached.
echo 'excluded' | sudo tee /opt/excluded/file >/dev/null
echo 'build output' >can-test-workspace-file
