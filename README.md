# Home Assistant Git Config Backup

Home Assistant add-on that automatically commits your configuration files to a Git repository with SSH key generation, real-time file watching, and a web UI for setup.

## Features

- **Auto SSH Key Generation** - No manual key management, just copy the public key from the Web UI
- **Real-time File Watching** - Optional inotify-based instant commits on file changes
- **Scheduled Backups** - Configurable interval from 1-168 hours
- **Smart Exclusions** - Databases, logs, and cache files excluded by default
- **Web UI** - View status, copy SSH key, trigger manual backups
- **Multi-arch** - Supports armhf, armv7, aarch64, amd64, i386

## Installation

1. In Home Assistant, go to **Settings → Add-ons → Add-on Store**
2. Click **⋮** (menu) → **Repositories**
3. Add this repository URL:
   ```
   https://github.com/sttts/ha-git-backup
   ```
4. Find "Git Config Backup" and click **Install**

## Quick Start

1. Start the add-on
2. Open the **Web UI** (from the add-on page)
3. Copy the **SSH public key** displayed
4. Add the key to your Git provider:
   - **GitHub**: Settings → SSH and GPG keys → New SSH key
   - **GitLab**: Preferences → SSH Keys → Add new key
5. Create a **private repository** for your backups
6. Configure the add-on with your repository URL:
   ```
   git@github.com:YOUR_USERNAME/ha-config-backup.git
   ```
7. Restart the add-on

## Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `repository_url` | (required) | Git repository URL (SSH or HTTPS) |
| `branch` | `main` | Git branch |
| `backup_interval_hours` | `24` | Hours between backups (0 to disable) |
| `watch_realtime` | `false` | Commit on file changes (inotify) |
| `auto_generate_ssh_key` | `true` | Auto-generate SSH key pair |

See [full documentation](git-backup/DOCS.md) for all options.

## What Gets Backed Up?

**Included:** YAML configs, JSON, scripts, blueprints, custom_components, themes, www

**Excluded:** Databases (*.db), logs, TTS cache, backups folder, .cloud

## Documentation

- [Full Documentation](git-backup/DOCS.md)
- [Design Document](doc/DESIGN.md)
- [Changelog](git-backup/CHANGELOG.md)

## License

MIT
