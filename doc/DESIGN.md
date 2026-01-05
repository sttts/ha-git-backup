# Git Config Backup - Design Document

## Overview

This document describes the design of the Git Config Backup add-on for Home Assistant. The add-on provides automated version-controlled backups of Home Assistant configuration files to a Git repository.

## Problem Statement

### Why not use Home Assistant's built-in backup system?

Home Assistant's native backup system (especially since 2025.1) creates full backup archives (`.tar` files) containing:
- Configuration files
- Database (always included, cannot be excluded)
- Add-on data
- Media files

**Issues with Git for full backups:**

| Problem | Impact |
|---------|--------|
| Binary tar archives | Git stores full copies, not diffs |
| Database included | 100s MB, changes constantly |
| Encryption by default | Binary blobs, no meaningful diffs |
| Large file sizes | Repository bloats quickly |

**Conclusion:** Git is unsuitable for Home Assistant's native backup format.

### Solution: Configuration-only backups

Git excels at tracking text files with meaningful diffs. Home Assistant configuration is primarily YAML, JSON, and Python files - perfect for Git.

**Benefits:**
- See exactly what changed between versions
- Small repository size
- Meaningful commit history
- Easy to restore specific file versions
- Works with GitHub, GitLab, Bitbucket, self-hosted

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Home Assistant Host                          │
│  ┌──────────────────┐     ┌─────────────────────────────────┐  │
│  │  Home Assistant  │     │     Git Config Backup Add-on    │  │
│  │                  │     │                                 │  │
│  │  /config/        │────▶│  /config/ (read-only mount)     │  │
│  │  ├── *.yaml      │     │                                 │  │
│  │  ├── *.json      │     │  ┌─────────────────────────┐    │  │
│  │  ├── custom_*    │     │  │      run.sh             │    │  │
│  │  └── ...         │     │  │  ┌─────────────────┐    │    │  │
│  │                  │     │  │  │ rsync (sync)    │    │    │  │
│  └──────────────────┘     │  │  │ git (commit)    │    │    │  │
│                           │  │  │ ssh (push)      │    │    │  │
│                           │  │  └─────────────────┘    │    │  │
│                           │  │                         │    │  │
│                           │  │  ┌─────────────────┐    │    │  │
│                           │  │  │ inotifywait     │    │    │  │
│                           │  │  │ (file watcher)  │    │    │  │
│                           │  │  └─────────────────┘    │    │  │
│                           │  │                         │    │  │
│                           │  │  ┌─────────────────┐    │    │  │
│                           │  │  │ Python HTTP     │    │    │  │
│                           │  │  │ (Web UI)        │    │    │  │
│                           │  │  └─────────────────┘    │    │  │
│                           │  └─────────────────────────┘    │  │
│                           │                                 │  │
│                           │  /data/                         │  │
│                           │  ├── repository/  (git clone)   │  │
│                           │  ├── ssh/         (SSH keys)    │  │
│                           │  ├── status.json  (state)       │  │
│                           │  └── options.json (config)      │  │
│                           └─────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                                      │
                                      │ SSH/HTTPS
                                      ▼
                    ┌─────────────────────────────────┐
                    │     Git Remote Repository       │
                    │   (GitHub/GitLab/Bitbucket)     │
                    └─────────────────────────────────┘
```

## Components

### 1. Main Script (`run.sh`)

The main entry point orchestrates all functionality:

```
┌─────────────────────────────────────────────────────┐
│                    run.sh                           │
├─────────────────────────────────────────────────────┤
│  main()                                             │
│    ├── setup_ssh_key()      # Generate/load SSH    │
│    ├── start_webui()        # HTTP server          │
│    ├── setup_git_credentials() # HTTPS auth        │
│    ├── setup_repository()   # Clone/init repo      │
│    ├── do_backup()          # Initial backup       │
│    ├── start_file_watcher() # inotify (optional)   │
│    └── main_loop()          # Scheduled backups    │
│                                                     │
│  do_backup()                                        │
│    ├── generate_gitignore() # Create .gitignore    │
│    ├── rsync                # Sync files           │
│    ├── git add -A           # Stage changes        │
│    ├── git commit           # Commit               │
│    └── git push             # Push to remote       │
└─────────────────────────────────────────────────────┘
```

### 2. SSH Key Management

**Auto-generation flow:**

```
┌─────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Add-on      │───▶│ Check for        │───▶│ Generate new    │
│ starts     │    │ existing key     │ No │ ed25519 key     │
└─────────────┘    └──────────────────┘    └─────────────────┘
                           │ Yes                   │
                           ▼                       ▼
                   ┌──────────────────┐    ┌─────────────────┐
                   │ Use existing key │    │ Display public  │
                   └──────────────────┘    │ key in logs/UI  │
                           │               └─────────────────┘
                           ▼                       │
                   ┌──────────────────────────────────────────┐
                   │ Configure SSH: known_hosts, config file  │
                   └──────────────────────────────────────────┘
```

**Key storage:**
- Private key: `/data/ssh/id_ed25519` (persisted across restarts)
- Public key: `/data/ssh/id_ed25519.pub`
- Known hosts pre-populated for github.com, gitlab.com, bitbucket.org

### 3. File Synchronization

Uses `rsync` for efficient synchronization:

```bash
rsync -av --delete \
    --exclude='.git/' \
    --exclude='*.db' \
    --exclude='*.log' \
    # ... more excludes
    /config/ /data/repository/
```

**Why rsync?**
- Efficient incremental sync
- Handles deletions (`--delete`)
- Preserves timestamps
- Built-in exclude patterns

### 4. Backup Triggers

Three trigger mechanisms:

| Trigger | Mechanism | Use Case |
|---------|-----------|----------|
| **Scheduled** | Sleep loop | Regular interval (e.g., every 24h) |
| **Realtime** | inotifywait | Immediate commit on file change |
| **Manual** | Web UI / API | On-demand backup |

**Realtime watching with debounce:**

```
File change → debounce timer → backup
             (30s default)

Change 1 ─┐
Change 2 ──┼─── [30s wait] ───▶ Single backup
Change 3 ─┘
```

### 5. Web UI

Simple HTTP server for status and SSH key display:

```
┌────────────────────────────────────────┐
│  Git Config Backup                     │
├────────────────────────────────────────┤
│  Status: ● Success                     │
│  Repository: git@github.com:user/repo  │
│  Branch: main                          │
│  Last commit: abc1234 - Backup 2025... │
│                                        │
│  [Run Backup Now]                      │
├────────────────────────────────────────┤
│  SSH Public Key                        │
│  ┌──────────────────────────────────┐  │
│  │ ssh-ed25519 AAAA... homeassist.. │  │
│  │                          [Copy]  │  │
│  └──────────────────────────────────┘  │
│                                        │
│  Add this key to GitHub:               │
│  Settings → SSH Keys → New SSH key     │
└────────────────────────────────────────┘
```

**Endpoints:**
- `GET /` - HTML interface
- `GET /api/status` - JSON status
- `GET /api/ssh-key` - Public key text
- `POST /api/backup` - Trigger backup

## File Exclusions

### Default Exclusions (hardcoded)

| Pattern | Reason |
|---------|--------|
| `*.db`, `*.db-shm`, `*.db-wal` | SQLite database files - large, binary, change constantly |
| `*.log`, `home-assistant.log*` | Log files - temporary, not needed for restore |
| `tts/` | Text-to-speech cache - regenerated |
| `backups/` | HA backup archives - use native backup system |
| `.cloud/` | Cloud connection data - recreated on login |
| `.storage/core.restore_state` | State file - changes constantly |
| `__pycache__/` | Python cache - regenerated |

### User-Configurable Exclusions

Users can add patterns via `exclude_patterns` option using gitignore syntax.

### Secrets Handling

**Default behavior:** `secrets.yaml` IS included.

**Rationale:**
1. Repository should be private
2. Secrets needed for full restore
3. Users can exclude via config if desired

**To exclude:**
```yaml
exclude_patterns:
  - "secrets.yaml"
  - "esphome/secrets.yaml"
```

## Security Considerations

### Authentication Methods

| Method | Security | Convenience |
|--------|----------|-------------|
| SSH Key (auto-generated) | High | High - key shown in UI |
| SSH Key (user-provided) | High | Medium |
| HTTPS + Token | High | Medium |
| HTTPS + Password | Medium | Low |

**Recommendation:** Use auto-generated SSH key with deploy key on GitHub (read/write to single repo only).

### Sensitive Data

| Data | Location | Protection |
|------|----------|------------|
| SSH private key | `/data/ssh/` | 600 permissions, add-on-only access |
| Git credentials | `/data/.git-credentials` | 600 permissions |
| Repository content | Private repo | User responsibility |

### Network Security

- SSH: Key-based authentication, known_hosts verification
- HTTPS: TLS encrypted, credential helper storage

## Configuration Options

### Minimal Configuration

```yaml
repository_url: "git@github.com:user/ha-config.git"
```

Everything else has sensible defaults:
- Branch: `main`
- Auto-generate SSH key: `true`
- Backup interval: 24 hours
- Backup on start: `true`

### Full Configuration

```yaml
# Repository
repository_url: "git@github.com:user/ha-config.git"
branch: "main"

# Authentication (choose one)
auto_generate_ssh_key: true    # Option 1: Auto SSH
ssh_key: "-----BEGIN..."       # Option 2: Provided SSH
username: "user"               # Option 3: HTTPS
password: "token"

# Git identity
commit_user_name: "Home Assistant"
commit_user_email: "ha@example.com"
commit_message: "Automated backup: {date}"

# Scheduling
backup_interval_hours: 24      # 0 to disable
backup_on_start: true
watch_realtime: false          # inotify watching
watch_debounce_seconds: 30
cron_schedule: ""              # Future: cron expression

# File selection
exclude_patterns:
  - "secrets.yaml"
include_patterns:
  - "*.yaml"
```

## Future Enhancements

### Planned

1. **Cron scheduling** - Full cron expression support
2. **Restore functionality** - UI to restore from any commit
3. **Diff viewer** - Show changes in Web UI
4. **Notifications** - HA notifications on backup success/failure
5. **Multiple remotes** - Push to multiple repositories

### Considered

1. **Branch per backup** - Create branches for major changes
2. **Signed commits** - GPG signing support
3. **LFS support** - Large file support for media
4. **Conflict resolution** - Handle remote changes

## Testing

### Manual Testing

1. Install add-on with empty config
2. Verify SSH key generation and display
3. Add SSH key to GitHub
4. Configure repository URL
5. Verify initial backup
6. Make configuration change
7. Verify scheduled/realtime backup
8. Test Web UI manual trigger

### Automated Testing (Future)

- Unit tests for git operations
- Integration tests with mock git server
- CI/CD for multi-arch builds

## References

- [Home Assistant Add-on Development](https://developers.home-assistant.io/docs/add-ons/)
- [Home Assistant Backup Integration](https://www.home-assistant.io/integrations/backup/)
- [Git Internals](https://git-scm.com/book/en/v2/Git-Internals-Plumbing-and-Porcelain)
- [inotifywait Documentation](https://linux.die.net/man/1/inotifywait)
