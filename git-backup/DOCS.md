# Git Config Backup

Automatically backup your Home Assistant configuration files to a Git repository.

## Why use this add-on?

- **Version History**: Track all changes to your configuration over time
- **Easy Recovery**: Restore any previous configuration version
- **Off-site Backup**: Your configuration is safely stored in the cloud
- **Meaningful Diffs**: See exactly what changed between versions (unlike binary backups)

## Quick Start (SSH - Recommended)

The easiest way to get started:

1. **Install and start** the add-on
2. **Open the Web UI** from the add-on page
3. **Copy the SSH public key** displayed
4. **Add the key** to your Git provider:
   - GitHub: Settings → SSH and GPG keys → New SSH key
   - GitLab: Preferences → SSH Keys → Add new key
5. **Create a private repository** on your Git provider
6. **Configure** the repository URL in the add-on settings:
   ```
   git@github.com:YOUR_USERNAME/ha-config-backup.git
   ```
7. **Restart** the add-on

That's it! The add-on will automatically backup your configuration.

## Authentication Methods

### Option 1: Auto-generated SSH Key (Recommended)

The simplest method. The add-on generates an SSH key pair automatically.

1. Set `auto_generate_ssh_key: true` (default)
2. Copy the public key from the Web UI
3. Add it to your Git provider
4. Use SSH URL format: `git@github.com:user/repo.git`

### Option 2: Your Own SSH Key

If you have an existing SSH key:

1. Set `auto_generate_ssh_key: false`
2. Paste your private key into the `ssh_key` field (include BEGIN/END lines)
3. Use SSH URL format: `git@github.com:user/repo.git`

### Option 3: HTTPS with Token

For HTTPS authentication:

1. Create a Personal Access Token on your Git provider:
   - GitHub: Settings → Developer settings → Personal access tokens → Generate new token (with `repo` scope)
   - GitLab: Preferences → Access Tokens → Add new token (with `write_repository` scope)
2. Configure:
   - `repository_url`: `https://github.com/user/repo.git`
   - `username`: Your username
   - `password`: Your token (not your password!)

## Configuration Reference

### Repository Settings

| Option | Default | Description |
|--------|---------|-------------|
| `repository_url` | *(required)* | Git repository URL. Use SSH format (`git@github.com:user/repo.git`) or HTTPS (`https://github.com/user/repo.git`) |
| `branch` | `main` | Git branch to use for backups |

### Authentication

| Option | Default | Description |
|--------|---------|-------------|
| `auto_generate_ssh_key` | `true` | Automatically generate an ED25519 SSH key pair. The public key is shown in the Web UI |
| `ssh_key` | | SSH private key (paste entire key including `-----BEGIN/END-----` lines). Only needed if `auto_generate_ssh_key` is false |
| `username` | | Username for HTTPS authentication |
| `password` | | Password or Personal Access Token for HTTPS authentication |

### Commit Settings

| Option | Default | Description |
|--------|---------|-------------|
| `commit_message` | `Backup: {files}` | Commit message template. Placeholders: `{date}` for timestamp, `{files}` for changed file names |
| `commit_user_name` | `Home Assistant` | Git author name for commits |
| `commit_user_email` | | Git author email for commits |

**Commit Message Examples:**

```yaml
# Default - shows changed files
commit_message: "Backup: {files}"
# Result: "Backup: configuration.yaml, automations.yaml (+2 more)"

# With timestamp
commit_message: "{date}: {files}"
# Result: "2025-01-21 14:30:00: configuration.yaml, scripts.yaml"

# Simple timestamp only
commit_message: "Backup {date}"
# Result: "Backup 2025-01-21 14:30:00"
```

### Backup Schedule

| Option | Default | Description |
|--------|---------|-------------|
| `backup_interval_hours` | `24` | Hours between automatic backups. Set to `0` to disable scheduled backups |
| `backup_on_start` | `true` | Perform a backup when the add-on starts |
| `cron_schedule` | | Optional cron expression for custom schedules (e.g., `0 2 * * *` for 2 AM daily) |

### Real-time File Watching

Enable real-time backups that trigger when files change:

| Option | Default | Description |
|--------|---------|-------------|
| `watch_realtime` | `false` | Enable inotify-based file watching for instant commits |
| `watch_min_interval` | `30` | Minimum seconds between commits (5-300) |
| `watch_max_interval` | `1800` | Maximum backoff interval in seconds (60-3600). Prevents commit loops |

**How the backoff works:**

When rapid file changes are detected (potential infinite loop), the interval increases by 1.5x each time:

```
30s → 45s → 68s → 101s → 152s → 228s → ... → 1800s (30min cap)
```

This prevents runaway commits if something keeps modifying files. The interval resets after a calm period.

### File Patterns

| Option | Default | Description |
|--------|---------|-------------|
| `exclude_patterns` | *(see below)* | Gitignore-style patterns for files to exclude |
| `include_patterns` | *(see below)* | Patterns for files to include |

## What Gets Backed Up?

### Included by Default

- Configuration files: `*.yaml`, `*.yml`, `*.json`
- Scripts: `*.py`, `*.sh`, `*.js`
- Directories: `scripts/`, `blueprints/`, `custom_components/`, `themes/`, `www/`
- Lovelace dashboards: `.storage/lovelace*`
- Core config: `.storage/core.config`

### Excluded by Default

| Excluded | Reason |
|----------|--------|
| `*.db`, `*.db-shm`, `*.db-wal` | Database files are large, binary, change constantly |
| `*.log`, `home-assistant.log*` | Log files are temporary, not needed for recovery |
| `tts/` | Text-to-speech cache, regenerated automatically |
| `backups/` | Use Home Assistant's backup system for full backups |
| `.cloud/` | Cloud connection data, recreated on login |
| `.storage/*` (except whitelist) | Most storage files are regenerated or contain transient state |

### Default Exclude Patterns

```yaml
exclude_patterns:
  - "*.db"
  - "*.db-shm"
  - "*.db-wal"
  - "*.log"
  - "home-assistant.log*"
  - "OZW_Log.txt"
  - "tts/*"
  - ".storage/*"
  - "backups/*"
  - ".cloud/*"
```

### Default Include Patterns

```yaml
include_patterns:
  - "*.yaml"
  - "*.yml"
  - "*.json"
  - "*.js"
  - "*.py"
  - "*.sh"
  - "scripts/*"
  - "blueprints/*"
  - "custom_components/*"
  - "themes/*"
  - "www/*"
  - "!.storage/lovelace*"
  - "!.storage/core.config"
```

## Web UI

The add-on includes a web interface accessible from the Home Assistant sidebar or the add-on page. Features:

- **Status display**: Current backup status, last commit, repository info
- **SSH public key**: Copy the auto-generated public key to add to your Git provider
- **Manual backup**: Trigger a backup immediately

## Example Configurations

### Minimal (SSH with auto-generated key)

```yaml
repository_url: "git@github.com:username/ha-backup.git"
```

### Daily backup with custom message

```yaml
repository_url: "git@github.com:username/ha-backup.git"
branch: "main"
backup_interval_hours: 24
commit_message: "Daily backup: {date}"
```

### Real-time watching

```yaml
repository_url: "git@github.com:username/ha-backup.git"
backup_interval_hours: 0
watch_realtime: true
watch_min_interval: 60
watch_max_interval: 1800
commit_message: "Config update: {files}"
```

### HTTPS with token

```yaml
repository_url: "https://github.com/username/ha-backup.git"
username: "username"
password: "ghp_xxxxxxxxxxxxxxxxxxxx"
backup_interval_hours: 12
```

### Exclude secrets

```yaml
repository_url: "git@github.com:username/ha-backup.git"
exclude_patterns:
  - "secrets.yaml"
  - "esphome/secrets.yaml"
  - ".storage/auth*"
```

## Security Considerations

### Secrets

Your `secrets.yaml` file **is included** by default. This is intentional because:

1. The repository should be **private**
2. You need secrets to fully restore your configuration
3. Without secrets, your configuration won't work after restore

To exclude secrets, add them to `exclude_patterns`.

### Private Repository

**Always use a private repository!** Your configuration may contain:

- Network information and IP addresses
- Device names and locations
- Automation logic revealing your habits
- API keys and tokens (in secrets.yaml)
- Integration credentials

### SSH Key Security

The auto-generated SSH key is stored in `/data/ssh/` within the add-on's persistent storage. The public key is also copied to `/share/git_backup_ssh_key.pub` for easy access.

## Troubleshooting

### "Failed to push to remote"

- Verify your credentials/SSH key are correct
- Check that the repository exists and you have write access
- For SSH: ensure the public key is added to your Git provider
- For HTTPS: ensure you're using a token, not your password

### "Could not clone"

- The add-on will initialize an empty repo if the remote is empty
- Check the repository URL format is correct
- Verify network connectivity
- For SSH: check the host key is accepted

### No changes detected

- The backup only commits when files actually change
- Check that your files aren't in the exclude patterns
- Verify the files are in the Home Assistant config directory

### Repository growing too large

1. Check if any large files were accidentally included
2. Add more patterns to `exclude_patterns`
3. Consider starting fresh: delete and recreate the repository

### Real-time watching not triggering

- Ensure `watch_realtime: true` is set
- Check that the file type isn't excluded
- The debounce interval may be delaying commits
- Check the add-on logs for "File change detected" messages

## Restoring Configuration

To restore from your Git backup:

1. Clone your repository locally
2. Copy the files to your Home Assistant config directory (`/config/`)
3. Restart Home Assistant

For a fresh installation:

```bash
cd /config
git clone git@github.com:username/ha-backup.git .
```

## API

The add-on provides a simple HTTP API on port 8099 (accessible via Ingress):

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Web UI |
| `/api/status` | GET | JSON status (status, message, last_commit, repository, branch) |
| `/api/ssh-key` | GET | Public SSH key as text |
| `/api/backup` | POST | Trigger a manual backup |

## Support

- [Issue Tracker](https://github.com/sttts/ha-git-backup/issues)
- [Changelog](CHANGELOG.md)
