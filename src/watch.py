#!/usr/bin/env python3
"""Records every file created or changed on a file system, as a fast replacement of the scan.

Usage (as root):
    watch.py STATE_DIR WATCH_PATH

Marks the whole file system that holds WATCH_PATH with fanotify, writes STATE_DIR/watch.pid
and STATE_DIR/watch.ready once events are being recorded, and reads events until SIGTERM.
Then it writes, NUL-separated, every entry that the find scan of cache-anything-new.sh would
report to STATE_DIR/watch.list: files, symbolic links and directories under WATCH_PATH, on
its file system, outside the patterns in STATE_DIR/excludes, whose change time is newer than
STATE_DIR/marker. Directories that were created or moved in are walked, because entries
moved in with them raise no event of their own.

STATE_DIR/watch.done is written last and holds "ok", or "overflow" when the kernel dropped
events (the caller then falls back to the scan).

Needs Linux 5.9 or newer (FAN_REPORT_DFID_NAME) and CAP_SYS_ADMIN. Exits with status 2 when
fanotify cannot be used.
"""

import ctypes
import fnmatch
import os
import select
import signal
import struct
import sys

FAN_CLASS_NOTIF = 0x0
FAN_UNLIMITED_QUEUE = 0x10
FAN_REPORT_DFID_NAME = 0xC00
FAN_MARK_ADD = 0x1
FAN_MARK_FILESYSTEM = 0x100
FAN_MODIFY = 0x2
FAN_ATTRIB = 0x4
FAN_CLOSE_WRITE = 0x8
FAN_MOVED_TO = 0x80
FAN_CREATE = 0x100
FAN_Q_OVERFLOW = 0x4000
FAN_ONDIR = 0x40000000
AT_FDCWD = -100
INFO_DFID_NAME = 2
INFO_NEW_DFID_NAME = 12

# Writes through mmap raise no FAN_MODIFY, but the file was opened for writing, so
# FAN_CLOSE_WRITE covers them.
MASK = FAN_MODIFY | FAN_ATTRIB | FAN_CLOSE_WRITE | FAN_MOVED_TO | FAN_CREATE | FAN_ONDIR

METADATA = struct.Struct("=IBBHQii")  # event_len, vers, reserved, metadata_len, mask, fd, pid
INFO_HEADER = struct.Struct("=BBH")  # info_type, pad, len
FSID_SIZE = 8
HANDLE_HEADER = struct.Struct("=Ii")  # handle_bytes, handle_type

S_IFMT, S_IFREG, S_IFLNK, S_IFDIR = 0o170000, 0o100000, 0o120000, 0o040000

libc = ctypes.CDLL(None, use_errno=True)
libc.fanotify_init.argtypes = [ctypes.c_uint, ctypes.c_uint]
libc.fanotify_mark.argtypes = [ctypes.c_int, ctypes.c_uint, ctypes.c_uint64, ctypes.c_int,
                               ctypes.c_char_p]
libc.open_by_handle_at.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int]

stopping = False


def on_signal(_signum, _frame):
    global stopping
    stopping = True


def unavailable(what: str) -> None:
    print(f"fanotify is not available ({what}: {os.strerror(ctypes.get_errno())})",
          file=sys.stderr)
    sys.exit(2)


def write_atomic(path: str, data: bytes) -> None:
    with open(path + ".tmp", "wb") as f:
        f.write(data)
    os.rename(path + ".tmp", path)


def parse(buffer: bytes, entries: dict) -> bool:
    """Merges the events in the buffer into entries, a map of (parent directory handle,
    name) to the union of event masks. Returns False when the queue overflowed."""
    complete = True
    offset = 0
    while offset + METADATA.size <= len(buffer):
        event_len, _vers, _res, metadata_len, mask, _fd, _pid = METADATA.unpack_from(buffer, offset)
        if event_len < METADATA.size:
            break
        if mask & FAN_Q_OVERFLOW:
            complete = False
        end = offset + event_len
        info = offset + metadata_len
        while info + INFO_HEADER.size <= end:
            info_type, _pad, length = INFO_HEADER.unpack_from(buffer, info)
            if length == 0:
                break
            if info_type in (INFO_DFID_NAME, INFO_NEW_DFID_NAME):
                handle_at = info + INFO_HEADER.size + FSID_SIZE
                handle_bytes, _type = HANDLE_HEADER.unpack_from(buffer, handle_at)
                name_at = handle_at + HANDLE_HEADER.size + handle_bytes
                name = buffer[name_at:buffer.index(b"\0", name_at, info + length)]
                key = (buffer[handle_at:name_at], name)
                entries[key] = entries.get(key, 0) | mask
            info += length
        offset = end
    return complete


class Rules:
    """The rules of the find scan: -mindepth 1, -xdev, -path EXCLUDE -prune, the entry types
    and -cnewer MARKER."""

    def __init__(self, state_dir: str, watch_path: str):
        self.root = os.fsencode(watch_path)
        self.prefix = self.root if self.root == b"/" else self.root + b"/"
        self.device = os.stat(watch_path).st_dev
        self.marker = os.stat(os.path.join(state_dir, "marker")).st_mtime_ns
        with open(os.path.join(state_dir, "excludes"), "rb") as f:
            self.excludes = [line for line in f.read().split(b"\n") if line]
        self.pruned: dict = {}

    def is_pruned(self, path: bytes) -> bool:
        """True when the path or one of its parents below the root matches an exclude."""
        if len(path) <= len(self.prefix):
            return False
        if path not in self.pruned:
            self.pruned[path] = (any(fnmatch.fnmatchcase(path, p) for p in self.excludes)
                                 or self.is_pruned(os.path.dirname(path)))
        return self.pruned[path]

    def stat(self, path: bytes):
        """The lstat of a path inside the scan, or None when find would not visit it."""
        if not path.startswith(self.prefix) or path == self.root or self.is_pruned(path):
            return None
        try:
            info = os.lstat(path)
        except OSError:
            return None
        return info if info.st_dev == self.device else None

    def changed(self, info) -> bool:
        return (info.st_mode & S_IFMT in (S_IFREG, S_IFLNK, S_IFDIR)
                and info.st_ctime_ns > self.marker)


def walk(rules: Rules, top: bytes, found: set) -> None:
    """Adds the changed entries below a directory, like find TOP -xdev -mindepth 1."""
    stack = [top]
    while stack:
        directory = stack.pop()
        try:
            names = os.listdir(directory)
        except OSError:
            continue
        for name in names:
            path = os.path.join(directory, name)
            info = rules.stat(path)
            if info is None:
                continue
            if rules.changed(info):
                found.add(path)
            if info.st_mode & S_IFMT == S_IFDIR:
                stack.append(path)


def resolve(mount_fd: int, handle: bytes, cache: dict):
    """The current path of a directory handle, or None when the directory is gone."""
    if handle not in cache:
        path = None
        fd = libc.open_by_handle_at(mount_fd, handle, os.O_PATH | os.O_DIRECTORY)
        if fd >= 0:
            try:
                target = os.readlink(f"/proc/self/fd/{fd}")
                if target.startswith("/") and not target.endswith(" (deleted)"):
                    path = os.fsencode(target)
            finally:
                os.close(fd)
        cache[handle] = path
    return cache[handle]


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit("usage: watch.py STATE_DIR WATCH_PATH")
    state_dir, watch_path = sys.argv[1], sys.argv[2]

    fan = libc.fanotify_init(FAN_CLASS_NOTIF | FAN_UNLIMITED_QUEUE | FAN_REPORT_DFID_NAME,
                             os.O_RDONLY | os.O_CLOEXEC)
    if fan < 0:
        unavailable("fanotify_init")
    if libc.fanotify_mark(fan, FAN_MARK_ADD | FAN_MARK_FILESYSTEM, MASK, AT_FDCWD,
                          os.fsencode(watch_path)) < 0:
        unavailable("fanotify_mark")
    # open_by_handle_at rejects an O_PATH descriptor here (EBADF).
    mount_fd = os.open(watch_path, os.O_RDONLY | os.O_DIRECTORY)

    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT, on_signal)
    write_atomic(os.path.join(state_dir, "watch.pid"), f"{os.getpid()}\n".encode())
    write_atomic(os.path.join(state_dir, "watch.ready"), b"ready\n")

    entries: dict = {}
    complete = True
    os.set_blocking(fan, False)
    poller = select.poll()
    poller.register(fan, select.POLLIN)
    while True:
        # After SIGTERM, read what is already queued and stop.
        draining = stopping
        if not poller.poll(0 if draining else 500):
            if draining:
                break
            continue
        try:
            buffer = os.read(fan, 1 << 20)
        except (BlockingIOError, InterruptedError):
            continue
        complete = parse(buffer, entries) and complete

    rules = Rules(state_dir, watch_path)
    directories: dict = {}
    candidates: set = set()
    new_trees: set = set()
    for (handle, name), mask in entries.items():
        parent = resolve(mount_fd, handle, directories)
        if parent is None:
            continue
        path = parent if name in (b"", b".") else os.path.join(parent, name)
        # The parent changed too (an entry was added, removed or renamed), and find reports it.
        candidates.update((path, parent))
        if mask & FAN_ONDIR and mask & (FAN_CREATE | FAN_MOVED_TO):
            new_trees.add(path)

    found: set = set()
    for path in candidates:
        info = rules.stat(path)
        if info is not None and rules.changed(info):
            found.add(path)
    walked: set = set()
    for top in sorted(new_trees, key=len):
        # A directory inside one already walked is covered.
        parent = os.path.dirname(top)
        while parent not in walked and len(parent) > len(rules.prefix):
            parent = os.path.dirname(parent)
        if parent in walked:
            continue
        info = rules.stat(top)
        if info is not None and info.st_mode & S_IFMT == S_IFDIR:
            walk(rules, top, found)
            walked.add(top)

    write_atomic(os.path.join(state_dir, "watch.list"), b"".join(p + b"\0" for p in sorted(found)))
    print(f"{len(entries)} events on {len(directories)} directories, {len(walked)} new directory "
          f"trees walked, {len(found)} changed entries.", file=sys.stderr)
    write_atomic(os.path.join(state_dir, "watch.done"), b"ok\n" if complete else b"overflow\n")


if __name__ == "__main__":
    main()
