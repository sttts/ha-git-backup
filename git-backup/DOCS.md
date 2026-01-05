# Git Config Backup

Automatically backup your Home Assistant configuration files to a Git repository.

## Why use this add-on?

- **Version History**: Track all changes to your configuration over time
- **Easy Recovery**: Restore any previous configuration version
- **Off-site Backup**: Your configuration is safely stored in the cloud
- **Meaningful Diffs**: See exactly what changed between versions (unlike binary backups)

## What gets backed up?

By default, this add-on backs up:

- All YAML configuration files (`.yaml`, `.yml`)
- JSON configuration files
- Custom components
- Themes
- Scripts and blueprints
- Lovelace dashboards
- WWW folder contents

## What is excluded?

The following are excluded by default (for good reasons):

| Excluded | Reason |
|----------|--------|
| `*.db` files | Database files are large, binary, and change constantly |
| `*.log` files | Log files are temporary and not needed for recovery |
| `tts/` folder | Text-to-speech cache, regenerated automatically |
| `backups/` | Use Home Assistant's backup system for full backups |
| `.cloud/` | Cloud connection data, recreated on login |
| `.storage/core.restore_state` | Changes constantly, not needed |

## Setup

### Option 1: GitHub with Personal Access Token (Recommended)

1. Create a new **private** repository on GitHub
2. Generate a [Personal Access Token](https://github.com/settings/tokens) with `repo` scope
3. Configure the add-on:
   - **Repository URL**: `https://github.com/USERNAME/REPO.git`
   - **Username**: Your GitHub username
   - **Password**: Your Personal Access Token

### Option 2: GitHub with SSH Key

1. Create a new **private** repository on GitHub
2. Generate an SSH key: `ssh-keygen -t ed25519 -C "homeassistant"`
3. Add the public key to your GitHub account ([Settings > SSH Keys](https://github.com/settings/keys))
4. Configure the add-on:
   - **Repository URL**: `git@github.com:USERNAME/REPO.git`
   - **SSH Private Key**: Paste your entire private key

### Option 3: GitLab / Bitbucket

Similar to GitHub, use either HTTPS with token or SSH key authentication.

## Configuration

### Basic Configuration

```yaml
repository_url: https://github.com/username/ha-config.git
branch: main
username: your-username
password: your-personal-access-token
commit_message: "Automated backup: {date}"
backup_interval_hours: 24
backup_on_start: true
```

### Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `repository_url` | (required) | Git repository URL |
| `branch` | `main` | Branch to use |
| `username` | | Username for HTTPS auth |
| `password` | | Password/token for HTTPS auth |
| `ssh_key` | | SSH private key (alternative to username/password) |
| `commit_message` | `Automated backup: {date}` | Commit message template |
| `commit_user_name` | `Home Assistant` | Git author name |
| `commit_user_email` | `homeassistant@local` | Git author email |
| `backup_interval_hours` | `24` | Hours between automatic backups |
| `backup_on_start` | `true` | Backup when add-on starts |
| `exclude_patterns` | (see below) | Additional patterns to exclude |
| `include_patterns` | (see below) | Patterns to include |

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
  - ".storage/core.restore_state"
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
  - ".storage/lovelace*"
```

## Security Considerations

### Secrets

Your `secrets.yaml` file **is included** by default. This is intentional because:

1. The repository should be **private**
2. You need secrets to fully restore your configuration
3. Without secrets, your configuration won't work after restore

If you prefer to exclude secrets:

```yaml
exclude_patterns:
  - "secrets.yaml"
  - "esphome/secrets.yaml"
```

### Private Repository

**Always use a private repository!** Your configuration contains:

- Network information
- Device names and locations
- Automation logic
- Potentially sensitive integrations

## Troubleshooting

### "Failed to push to remote"

- Check your credentials are correct
- Ensure the repository exists
- Verify you have write access

### "Could not clone"

- For new repositories, the add-on will initialize an empty repo
- Check the repository URL is correct
- Verify network connectivity

### Large Repository Size

If your repository grows large:

1. Check if any large files snuck in
2. Consider excluding more patterns
3. You can start fresh: delete the repo and create a new one

## Manual Backup

The add-on backs up automatically on the configured interval. To trigger a manual backup, restart the add-on.

## Restoring Configuration

To restore from your Git backup:

1. Clone your repository
2. Copy the files to your Home Assistant config directory
3. Restart Home Assistant

Or use the Git restore workflow on a fresh installation.
