# Changelog

## [1.0.12] - 2025-01-21

### Fixed

- Mask SSH private key in UI (changed schema from `str` to `password`)

## [1.0.11] - 2025-01-21

### Added

- `watch_burst_limit` option: allow N rapid backups before backing off (default 5)

### Fixed

- Backoff logic: only triggers after actual backup, not on every file event
- Backoff now properly resets after calm period (4× min interval)

### Changed

- Improved log messages: shows filename in change detection

## [1.0.10] - 2025-01-21

### Changed

- Comprehensive documentation rewrite with full configuration reference
- Added example configurations for common use cases
- Documented API endpoints, troubleshooting, and security considerations

## [1.0.9] - 2025-01-21

### Added

- Exponential backoff for file watcher to prevent infinite commit loops
- New config options: `watch_min_interval` (default 30s) and `watch_max_interval` (default 30min)

### Changed

- Renamed `watch_debounce_seconds` to `watch_min_interval`
- When rapid changes are detected, interval doubles up to max (30min default)

## [1.0.8] - 2025-01-21

### Changed

- Improved commit messages: now include file names summary (e.g., "Backup: configuration.yaml, automations.yaml (+2 more)")
- New `{files}` placeholder for commit message template
- Default commit message changed from "Automated backup: {date}" to "Backup: {files}"

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
