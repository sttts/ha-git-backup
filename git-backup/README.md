# Git Config Backup Add-on for Home Assistant

Automatically backup your Home Assistant configuration to a Git repository (GitHub, GitLab, Bitbucket, etc.).

## Features

- **Auto SSH Key Generation** - No manual key management, just copy the public key from the Web UI
- **Real-time File Watching** - Optional inotify-based instant commits with exponential backoff
- **Scheduled Backups** - Configurable interval from 1-168 hours
- **Smart Exclusions** - Databases, logs, and cache files excluded by default
- **Web UI** - View status, copy SSH key, trigger manual backups
- **Meaningful Commit Messages** - Shows changed file names (e.g., "Backup: configuration.yaml, automations.yaml")

## Quick Start

1. Install and start the add-on
2. Open the **Web UI** and copy the **SSH public key**
3. Add the key to your Git provider (GitHub/GitLab/Bitbucket)
4. Create a **private repository**
5. Configure the repository URL: `git@github.com:user/repo.git`
6. Restart the add-on

See [DOCS.md](DOCS.md) for detailed configuration options and examples.

## Support

- [Documentation](DOCS.md)
- [Changelog](CHANGELOG.md)
- [Issue Tracker](https://github.com/sttts/ha-git-backup/issues)

## License

Apache License 2.0
