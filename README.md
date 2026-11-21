# Cache Anything New | Action

Run your install commands once, then cache **every file they created or changed anywhere on
the runner**: packages from `apt`, users added to `/etc/passwd`, tools in `/opt`, files in your
home directory. On the next run the files are restored and the install is skipped.

Use it for slow installs that have no dedicated cache: system packages, SDKs, toolchains or
other actions that download large tools. If a dedicated cache exists for your language (for
example `actions/setup-node` with `cache: npm`, or `Swatinem/rust-cache`), prefer that one.

## Usage

### One step

```yaml
- uses: airvzxf/cache-anything-new-action@v2
  with:
    run: |
      sudo apt-get update
      sudo apt-get install -y pandoc texlive-xetex
```

On a cache miss the commands run and everything they changed is archived and saved. On a cache
hit the files are restored and the commands do not run. The commands are part of the cache
key, so editing them rebuilds the cache.

To run a script, add its hash to the key so the cache is rebuilt when the script changes:

```yaml
- uses: airvzxf/cache-anything-new-action@v2
  with:
    key: ${{ hashFiles('ci/install.sh') }}
    run: bash ci/install.sh
```

### Around other steps or actions

`start` and `end` cache whatever the steps between them change, including other actions:

```yaml
- uses: airvzxf/cache-anything-new-action/start@v2
  id: tools
  with:
    key: cuda-12.4

- if: steps.tools.outputs.cache-hit != 'true'
  uses: Jimver/cuda-toolkit@v0.2.36
  with:
    cuda: '12.4.0'

- uses: airvzxf/cache-anything-new-action/end@v2
```

Skip the install steps with `if: steps.<id>.outputs.cache-hit != 'true'`. `end` does nothing
after a cache hit. To use more than one pair in a job, give each pair its own `name` and pass
the same value to its `start` and `end`.

### Containers

Container jobs work when the job runs as root, which is the default for most images. If the
image sets another user, add `options: --user 0`. The image needs `bash`, GNU `tar` and GNU
`find` (on Alpine: `apk add bash tar findutils`).

```yaml
jobs:
  build:
    runs-on: ubuntu-24.04
    container: debian:13
    steps:
      - uses: actions/checkout@v7
      - uses: airvzxf/cache-anything-new-action@v2
        with:
          run: apt-get update && apt-get install -y build-essential cmake
```

## Inputs

| Input          | Action          | Default     | Description                                                                                                                                           |
|----------------|-----------------|-------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| `run`          | one step        | (required)  | Bash commands to run on a cache miss, with `set -eo pipefail`, in the workspace.                                                                     |
| `key`          | one step, start | `''`        | Extra text for the cache key. Required in `start`. See [Cache key](#cache-key).                                                       |
| `path`         | one step, start | `/`         | Directory to scan. A narrower path, such as `/opt` or `/usr/local`, scans faster.                                                                    |
| `exclude`      | one step, start | `''`        | Extra paths to leave out, added to the [built-in list](#excluded-paths). Separate them with spaces, or with new lines for paths that contain spaces. Shell patterns are allowed. |
| `detection`    | one step, start | `auto`      | `auto` records the changes with fanotify while they happen when the runner allows it, and scans otherwise. `scan` always scans. See [How it works](#how-it-works). |
| `post-restore` | one step, start | `''`        | Bash commands to run after a restore, for example `sudo systemctl start postgresql`. `ldconfig` always runs after a restore.                         |
| `name`         | all             | `default`   | Identifier of the cache when the action is used more than once in a job.                                                                             |

## Outputs

| Output      | Action          | Description                                         |
|-------------|-----------------|-----------------------------------------------------|
| `cache-hit` | one step, start | `true` when the files were restored from the cache. |
| `key`       | one step, start | The cache key.                                      |
| `files`     | one step, end   | Number of files and directories archived.           |
| `size`      | one step, end   | Size of the archive.                                |

## How it works

1. **Start.** The action computes the cache key and asks `actions/cache` for it. On a hit, it
   extracts the archive over `path` as root, keeping owners, permissions, special bits,
   extended attributes and ACLs, then runs `ldconfig` and `post-restore`. On a miss, it starts
   watching the file system and creates a marker file.
2. **Install.** Your commands or steps run.
3. **End.** The action lists every file, symbolic link and directory under `path` whose inode
   change time (ctime) is newer than the marker, archives them as root with GNU `tar` and saves
   the archive with `actions/cache`.

The change time is updated whenever a file is created, written, renamed or has its owner or
permissions changed, and unlike the modification time it cannot be set back. That is why files
that packages install with their original dates are still found, and why files that already
existed but were modified (such as `/var/lib/dpkg/status` or `/etc/passwd`) are cached too.

There are two ways to find those files, chosen with `detection`:

- **fanotify** (`auto`, the default, where the runner allows it). A small Python program marks
  the file system of `path` with [fanotify][Fanotify] and records every entry that is created,
  written, renamed or has its metadata changed. At the end only those entries, and the
  directories that were created or moved in, are checked with the same rules as the scan. This
  takes about a second. It needs root or passwordless sudo, Linux 5.9 or newer and `python3`,
  which GitHub-hosted runners have. Container jobs usually lack `python3` or the
  `CAP_SYS_ADMIN` capability, and then the action scans. The log says which way was used and
  why.
- **Scan** (`scan`, or when fanotify is not available). `find` reads the metadata of every
  file under `path`, which takes one or two minutes for `/` on a hosted runner. The
  directories below the second level are scanned by several `find` processes at once, because
  reading file metadata is bound by disk latency.

The tests of this repository run both on every hosted runner and check that the watcher finds
every entry that the scan finds. Both stay on the file system of `path` (like `find -xdev`), so
mounted disks such as `/mnt` and the container's bind mounts are left out. Archived paths are relative to `/`, so files are always restored where they were
found. The log lists the largest directories and files in the archive, which helps to spot
paths worth excluding.

### Cache key

```
cache-anything-new-v2-<os>-<version>-<arch>[-<key>]-<digest>
```

The digest covers the `run` commands, `path`, the excluded paths, the runner image
(`ImageOS`, `ImageVersion`) and a digest of the installed package database (dpkg, apk, pacman
or rpm), taken before anything is installed. When GitHub updates the runner image, or a
container image is updated, the key changes and the cache is rebuilt, so old files are never
restored over newer system files.

### Excluded paths

These paths are never scanned. Add your own with `exclude`.

- Virtual and temporary file systems: `/proc`, `/sys`, `/dev`, `/run`, `/tmp`, `/var/tmp`.
- Logs and package manager caches: `/var/log`, `/var/cache/apt`, `/var/lib/apt/lists`.
- State written by services in the background: `/var/lib/waagent`, `/var/lib/systemd`,
  `/var/lib/docker`, `/var/lib/containerd`, `/var/lib/snapd`, `/snap`, `/var/lib/dhcp`,
  `/var/lib/logrotate`, `/var/backups`, `/var/crash`.
- Files managed by the container runtime: `/etc/hostname`, `/etc/hosts`, `/etc/resolv.conf`,
  `/etc/mtab`, `/__w`, `/__e`, `/__t`, `/github`.
- The runner itself: `$RUNNER_TEMP`, the work directory (the checkout and downloaded actions),
  the directory of the runner program (found from its process), `~/actions-runner` and
  `~/runners`.

## Benchmarks

[cache-anything-new-benchmarks](https://github.com/airvzxf/cache-anything-new-benchmarks) builds
real projects (C++ with Boost and SDL2, XeLaTeX, Python with GDAL, Rust with OpenSSL and protoc,
CUDA, and C++ in a Debian container) without a cache and with this action and
[cache-apt-pkgs-action](https://github.com/awalsh128/cache-apt-pkgs-action).
[Results](https://github.com/airvzxf/cache-anything-new-benchmarks/blob/main/RESULTS.md),
median of five runs with fanotify detection:

- Every restore built and passed its checks, including TeX Live fonts and the BLAS
  alternatives of GDAL, which break after a restore with cache-apt-pkgs-action.
- A miss costs about the same as installing without a cache (3–7 s more on hosted runners;
  v2.0.0 scanned for 1–2 minutes). A hit takes 1–7 s.
- The cache pays off from the first hit. Job time without a cache → on a hit: Boost and SDL2
  85 → 22 s, TeX Live 84 → 12 s, GDAL 43 → 13 s, CUDA 45 → 18 s.

## Limitations

- **Linux only.** macOS and Windows runners fail with a clear error.
- **Files only.** Services started by the install are not running after a restore; start them
  in `post-restore`. Kernel modules, mounts and changes to environment variables
  (`$GITHUB_ENV`, `$GITHUB_PATH`) are not restored either; set them again in a later step.
- **Deleted files are not tracked.** A file the install removes comes back from the runner
  image on the next run.
- **Background writes are cached too.** Anything another process changes between start and
  end is archived. Add such paths to `exclude`.
- **Without fanotify, the scan reads the metadata of every file under `path`.** Hosted runner
  images hold millions of files; a scan of `/` takes about 1–2 minutes on `ubuntu-24.04` and
  under a minute on `ubuntu-24.04-arm`. In a container job, a narrower `path` scans faster.
- **One cache per runner variant.** The key includes the image version and the installed
  packages, so a hit needs the same image build as the miss. GitHub runs `ubuntu-24.04` on two
  clouds, with different image builds, kernels and cloud packages (for example
  `walinuxagent` and `linux-azure` on one, `ec2-hibinit-agent` and `linux-aws` on the other),
  so each variant builds its own cache on its first miss and restores it from then on. The
  archive holds the whole package database (`/var/lib/dpkg/status`), so restoring a cache
  from the other variant would replace its package list; that is why the key does not ignore
  the difference. Expect one miss per variant after every image update.

## Security

A cache hit writes files anywhere under `path` as root. Anyone who can save a cache entry for
your repository with the same key can change what is restored. GitHub limits which branches
can read a cache (see [cache access restrictions][CacheAccess]), but treat the cache like any
other code that runs in your workflow: avoid this action in workflows that run untrusted code
before the cache is saved.

## Migrating from v1

v2 calls `actions/cache` itself, so the separate `actions/cache` step and the `is_cached` and
`cache` inputs are gone.

```yaml
# v1
- uses: actions/cache@v2
  id: cache-id
  with:
    path: ${{ runner.temp }}/cache-directory
    key: ${{ runner.os }}-install-v1
- uses: airvzxf/cache-anything-new-action@v1.0.1
  with:
    script: 'install.sh'
    is_cached: ${{ steps.cache-id.outputs.cache-hit }}
    cache: ${{ runner.temp }}/cache-directory
    snapshot: '/'
    exclude: '/boot /data /dev /mnt /proc /run /sys'

# v2
- uses: airvzxf/cache-anything-new-action@v2
  with:
    key: ${{ hashFiles('.github/workflows/install.sh') }}
    run: bash .github/workflows/install.sh
```

| v1          | v2                                                                                   |
|-------------|--------------------------------------------------------------------------------------|
| `script`    | `run`. The script no longer has to be in `.github/workflows/`.                       |
| `is_cached` | Removed. Read the `cache-hit` output instead.                                        |
| `cache`     | Removed. The archive is stored in `$RUNNER_TEMP`.                                    |
| `snapshot`  | `path`.                                                                              |
| `exclude`   | `exclude`. The built-in list is always applied; list only your extra paths.          |

Other changes in v2:

- Files that already existed and were modified by the install are cached, not only new files.
- New files are no longer missed when the file list changes order between scans.
- Owners, permissions, special bits, extended attributes and ACLs are kept. Files readable
  only by root no longer make `actions/cache` fail with `Permission denied`.
- A `path` other than `/` is restored to the same place it was read from.
- The runner image and installed packages are part of the cache key.
- Works in container jobs without `sudo`.

## License

[AGPL-3.0](LICENSE)

[Fanotify]: https://man7.org/linux/man-pages/man7/fanotify.7.html
[CacheAccess]: https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows#restrictions-for-accessing-a-cache
