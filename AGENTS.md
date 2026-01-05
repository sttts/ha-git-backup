# Agent Instructions

## Release Procedure

1. **Bump version** in `git-backup/config.yaml`
2. **Update changelog** in `git-backup/CHANGELOG.md`
3. **Commit and tag:**
   ```bash
   git commit -am "Release vX.Y.Z"
   git tag -a vX.Y.Z -m "Release vX.Y.Z"
   git push && git push --tags
   ```
4. **Verify build** at https://github.com/sttts/ha-git-backup/actions
5. **Ensure packages are public** at https://github.com/sttts?tab=packages

## Project Structure

```
ha-git-backup/
├── repository.json          # Add-on repository metadata
├── git-backup/              # The add-on
│   ├── config.yaml          # Add-on config & version
│   ├── Dockerfile
│   ├── rootfs/run.sh        # Main script
│   ├── CHANGELOG.md
│   └── translations/
├── doc/DESIGN.md            # Architecture documentation
└── .github/workflows/       # CI/CD
```

## Testing Changes

After pushing changes:
1. Wait for CI build to complete
2. In Home Assistant: Add-on Store → ⋮ → Check for updates
3. Update/reinstall the add-on
