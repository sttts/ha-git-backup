# Changelog

## [1.0.7] - 2025-01-05

### Changed

- Exclude entire .storage/ directory, whitelist lovelace dashboards and core.config

## [1.0.6] - 2025-01-05

### Changed

- Exclude .storage/core.*_registry and core.restore_state by default

## [1.0.4] - 2025-01-05

### Fixed

- Fixed copy button with fallback for non-secure contexts

## [1.0.3] - 2025-01-05

### Fixed

- Fixed Web UI API calls to use relative paths for ingress compatibility

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
