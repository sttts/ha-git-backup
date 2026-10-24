# Backup regression tests

Run from the repository root with Bash, Git, jq, Python 3, and upstream rsync:

```sh
bash -n git-backup/rootfs/run.sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
```

On macOS, put upstream rsync on PATH first; Apple's openrsync does not implement
receiver protection with `--delete-excluded` like the Alpine add-on's rsync.
The CI workflow runs these tests with Alpine 3.19, matching the add-on base.

Tests create temporary source trees, isolated Git configuration, and local bare
remotes. They do not access Home Assistant, SSH keys, or network repositories.
