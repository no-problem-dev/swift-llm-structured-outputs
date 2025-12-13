# Release Process

This document describes the release process for swift-llm-structured-outputs.

## Versioning

This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html):

- **MAJOR** version for incompatible API changes
- **MINOR** version for new features (backward compatible)
- **PATCH** version for bug fixes (backward compatible)

## Release Flow

### 1. Prepare Release Branch

```bash
# Create release branch from main
git checkout main
git pull origin main
git checkout -b release/v1.0.4
```

### 2. Update CHANGELOG

1. Move items from `[Unreleased]` to new version section
2. Add release date in format `YYYY-MM-DD`
3. Update comparison links at the bottom

Example:
```markdown
## [Unreleased]

## [1.0.4] - 2025-12-14

### Added
- New feature description

### Fixed
- Bug fix description
```

### 3. Run Tests

```bash
# Run all tests
swift test

# Run tests with verbose output
swift test --verbose
```

### 4. Create Pull Request

1. Push the release branch
2. Create a PR to `main` with title: `Release v1.0.4`
3. Include CHANGELOG updates in PR description
4. Request review if needed

### 5. Merge and Release

When the PR is merged to `main`, the GitHub Action will automatically:

1. Detect the version from CHANGELOG.md
2. Create a git tag (e.g., `v1.0.4`)
3. Create a GitHub Release with:
   - Release notes from CHANGELOG
   - Source code archives

## Manual Release (if needed)

If automatic release fails, you can create a release manually:

```bash
# Tag the release
git checkout main
git pull origin main
git tag v1.0.4

# Push the tag
git push origin v1.0.4
```

Then create a release on GitHub:
1. Go to Releases → New Release
2. Select the tag
3. Copy release notes from CHANGELOG.md
4. Publish release

## Pre-release Versions

For pre-release versions, use suffixes:

- Alpha: `1.0.4-alpha.1`
- Beta: `1.0.4-beta.1`
- Release Candidate: `1.0.4-rc.1`

## Checklist

Before releasing:

- [ ] All tests pass
- [ ] CHANGELOG.md is updated
- [ ] Documentation is up to date
- [ ] Breaking changes are documented
- [ ] Version number follows semver

## Documentation Updates

After releasing:

1. DocC documentation is automatically generated via GitHub Actions
2. Verify documentation at: https://no-problem-dev.github.io/swift-llm-structured-outputs/

## Rollback

If a release needs to be reverted:

```bash
# Delete the tag locally and remotely
git tag -d v1.0.4
git push origin :refs/tags/v1.0.4

# Delete the GitHub Release manually from the web interface
```
