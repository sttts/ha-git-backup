# Changelog

## [1.0.2] - 2025-01-05

### Fixed

- Fixed Dockerfile chmod failing on non-existent directory
- Fixed run.sh permissions

## [1.0.1] - 2025-01-05

### Added

- Git logo for add-on
- SSH public key saved to /share/git_backup_ssh_key.pub
- Web UI for viewing SSH key and triggering backups

### Fixed

- Removed invalid default email address

## [1.0.0] - 2025-01-05

### Added

- Initial release
- Automatic scheduled backups to Git repository
- HTTPS authentication with username/password or token
- SSH key authentication
- Configurable backup interval
- Smart default exclusions (databases, logs, cache)
- Configurable include/exclude patterns
- Support for GitHub, GitLab, Bitbucket, and self-hosted Git
