# Cache Anything New | Action

This GitHub action scan the Linux container to check if anything new was added after you run your custom script then it
will cache all the new files. Optional, you can get the live version which has the last commits using the `main` branch
like this `uses: airvzxf/cache-anything-new-action@main`.

Based on the solution that I posted in [Stack Overflow][StackOverflowPost] and the implementation in some personal
project.

## Usage example

Create your script as `.github/workflows/install.sh` to install or make an application, also you can add files into
specific directories.

```bash
#!/bin/bash -e

sudo apt update
sudo apt install -y pandoc
echo "Hello World!" > hello.txt
```

Add the action in `.github/workflows/your_action.yml`.

```yaml
- uses: airvzxf/cache-anything-new-action@v1.0.1
  with:
    script: 'install.sh'
    is_cached: ${{ steps.cache-id.outputs.cache-hit }}
    cache: ${{ runner.temp }}/cache-directory-example
    snapshot: '/'
    exclude: '/boot /data /dev /mnt /proc /run /sys'
```

The complete example:

```yaml
name: CI - Testing Cache Anything New | Action
on:
  workflow_dispatch:
jobs:
  testing_actions:
    name: Testing Actions | Job
    runs-on: ubuntu-18.04
    steps:
      - uses: actions/checkout@v2
      # Required action
      - uses: actions/cache@v2
        id: cache-id
        with:
          path: ${{ runner.temp }}/cache-directory-example
          key: ${{ runner.os }}-cache-hello-world-key-v1.0
      # Required action
      - uses: airvzxf/cache-anything-new-action@v1.0.1
        with:
          script: 'install.sh'
          is_cached: ${{ steps.cache-id.outputs.cache-hit }}
          cache: ${{ runner.temp }}/cache-directory-example
          snapshot: '/'
          exclude: '/boot /data /dev /mnt /proc /run /sys'
      # Not required action
      - name: Step -> Use the cache
        run: |
          find /home/ -iname hello.txt 2> /dev/null || true
          whereis pandoc || true
```

I created a dummy example here:

- [Workflows directory][workflows]
  - [cache_anything_new_action.yml][actionYml]
  - [install.sh][installScript]
- [Action: Workflow][actions]

## Settings

The `uses: actions/cache` is required because it needs this external action to store the cache,
the `cache anything action` only find the new created files and store in a temporal directory which will be cached
by `actions/cache`.

Option | Description | Required | Default | Example
---    | ---         | ---      | ---     | ---
script | Create your bash script to execute the commands. They will be generated files and it will stored in the cached.<br> This script needs to be the same directory as your action: `.github/workflows/`. | Yes | N/A | hello-world.sh
is_cached | Boolean value to check if the cache was created.<br> It should be the same as the `actions/cache` `id`. | Yes | N/A | ${{ steps.cache-id.outputs.cache-hit }}
cache | The directory where the new detected files will be stored.<br> It should be the same as the `actions/cache` `path`. | Yes | N/A | /home/my-cache/directory
snapshot | The path of the scanner entry point.<br> It can scan from the main path `/` or some specific directory. | No | / | /home/runner
exclude | Exclude directories or files during the scanner.<br> Separate with spaces. | No | /boot /data /dev /mnt /proc /run /sys | /root /home/github /actions /home/runner/.bashrc

## More examples

The basic setup, using the default values.

```yaml
name: CI - Testing Cache Anything New | Action
on:
  workflow_dispatch:
jobs:
  testing_actions:
    name: Testing Actions | Job
    runs-on: ubuntu-18.04
    steps:
      - uses: actions/checkout@v2
      # Required action
      - uses: actions/cache@v2
        id: cache-id
        with:
          path: ${{ runner.temp }}/cache-directory-example
          key: ${{ runner.os }}-cache-hello-world-key-v1.0
      # Required action
      - uses: airvzxf/cache-anything-new-action@v1.0.1
        with:
          script: 'install.sh'
          is_cached: ${{ steps.cache-id.outputs.cache-hit }}
          cache: ${{ runner.temp }}/cache-directory-example
      # Not required action
      - name: Step -> Use the cache
        run: |
          find /home/ -iname hello.txt 2> /dev/null || true
          whereis pandoc || true
```

## To-Do's

General:

- Add input `post_install` which try to emulate the basic triggers after the installation (Running post-transaction
  hooks). Maybe added a `post-install.sh` script which execute some `systemctl restart` stuff, the user can run anything
  if the validation of the existed cache is true.

[StackOverflowPost]: https://stackoverflow.com/a/65274407/1727383

[GitHubSecrets]: https://docs.github.com/en/actions/configuring-and-managing-workflows/creating-and-storing-encrypted-secrets

[actionYml]: https://github.com/airvzxf/testing-actions-github/blob/main/.github/workflows/cache_anything_new_action.yml

[installScript]: https://github.com/airvzxf/testing-actions-github/blob/main/.github/workflows/install.sh

[actions]: https://github.com/airvzxf/testing-actions-github/actions?query=workflow%3A%22CI+-+Testing+Cache+Anything+New+%7C+Action%22

[workflows]: https://github.com/airvzxf/testing-actions-github/tree/main/.github/workflows
