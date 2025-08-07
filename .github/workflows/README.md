# GitHub Actions Workflows

This directory contains the CI/CD pipeline workflows for the knxd-docker project.

## Workflows Overview

### 🚀 [build-and-release.yml](build-and-release.yml)
**Main CI/CD Pipeline**

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main`
- Git tags (`v*`)
- Manual dispatch with custom KNXD version

**Jobs:**
1. **Lint** - Validates Dockerfile, docker-compose files, and shell scripts
2. **Build** - Multi-platform Docker image build (linux/amd64, linux/arm64)
3. **Test** - Comprehensive testing of different interface configurations
4. **Security** - Vulnerability scanning with Trivy
5. **Release** - Automated GitHub releases for tags
6. **Cleanup** - Removes old Docker images

**Features:**
- Multi-platform builds with Docker Buildx
- Comprehensive testing matrix (basic, TPUART, IP tunneling, USB)
- Security scanning and SARIF upload
- Automated releases with changelog
- Docker layer caching for faster builds
- Health check validation

### 📚 [documentation.yml](documentation.yml)
**Documentation Quality Assurance**

**Triggers:**
- Changes to documentation files (`docs/**`, `README.md`, `examples/**/*.md`)
- Pull requests affecting documentation
- Manual dispatch

**Jobs:**
1. **Validate Docs** - Markdown linting, link checking, structure validation
2. **Docs Metrics** - Generate documentation statistics
3. **Freshness Check** - Check for outdated information

**Features:**
- Markdown linting with configurable rules
- Internal and external link validation
- Documentation structure verification
- Metrics generation (file count, line count, examples)
- Automated detection of outdated version references

### 🔄 [dependency-updates.yml](dependency-updates.yml)
**Automated Dependency Management**

**Triggers:**
- Weekly schedule (Sundays at 6 AM UTC)
- Manual dispatch with options

**Jobs:**
1. **Check KNXD Versions** - Monitor for new KNXD releases
2. **Check Base Images** - Monitor Alpine and other base images
3. **Dependency Summary** - Generate update summary
4. **Auto Update Minor** - Automated PRs for patch versions

**Features:**
- Automatic KNXD version monitoring
- GitHub issue creation for updates
- Base image security scanning
- Automated PRs for patch version updates
- Comprehensive update summaries

## Secrets Required

The workflows require the following GitHub secrets:

| Secret | Description | Used In |
|--------|-------------|---------|
| `DOCKER_USERNAME` | Docker Hub username | build-and-release.yml |
| `DOCKER_PASSWORD` | Docker Hub password/token | build-and-release.yml |
| `GITHUB_TOKEN` | GitHub token (auto-provided) | All workflows |

## Setup Instructions

### 1. Docker Hub Integration

1. Create a Docker Hub account and repository
2. Generate an access token in Docker Hub settings
3. Add secrets to GitHub repository:
   ```
   DOCKER_USERNAME: your-dockerhub-username
   DOCKER_PASSWORD: your-dockerhub-token
   ```

### 2. Enable GitHub Actions

1. Go to repository Settings → Actions → General
2. Enable "Allow all actions and reusable workflows"
3. Set workflow permissions to "Read and write permissions"

### 3. Configure Branch Protection

For production use, configure branch protection rules:

1. Go to Settings → Branches
2. Add rule for `main` branch:
   - Require status checks to pass
   - Require branches to be up to date
   - Include administrators
   - Required status checks:
     - `Lint and Validate`
     - `Build Docker Image`
     - `Test Docker Image`

## Workflow Triggers

### Automatic Triggers

| Event | Workflow | Description |
|-------|----------|-------------|
| Push to `main` | build-and-release | Full CI/CD pipeline |
| Push to `develop` | build-and-release | Build and test only |
| Pull Request | build-and-release, documentation | Validation and testing |
| Git Tag `v*` | build-and-release | Release build and GitHub release |
| Documentation changes | documentation | Documentation validation |
| Weekly schedule | dependency-updates | Dependency monitoring |

### Manual Triggers

All workflows support manual dispatch (`workflow_dispatch`) with various options:

- **build-and-release**: Custom KNXD version, force registry push
- **documentation**: On-demand documentation validation
- **dependency-updates**: Custom dependency checking options

## Build Matrix

The build workflow uses a matrix strategy for comprehensive testing:

### Platforms
- `linux/amd64` - Standard x86_64 architecture
- `linux/arm64` - ARM64 architecture (Raspberry Pi, Apple Silicon)

### Test Types
- `basic` - Basic functionality with dummy interface
- `tpuart` - TPUART interface configuration validation
- `ip-tunneling` - IP tunneling configuration validation
- `usb` - USB interface configuration validation

## Release Process

### Automated Releases

1. Create and push a git tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. The workflow automatically:
   - Builds multi-platform images
   - Runs all tests
   - Performs security scanning
   - Creates GitHub release with changelog
   - Pushes images to Docker Hub

### Manual Releases

Use workflow dispatch to build specific versions:

1. Go to Actions → Build and Release
2. Click "Run workflow"
3. Specify KNXD version and options
4. Run the workflow

## Monitoring and Maintenance

### Workflow Status

Monitor workflow status in the Actions tab:
- ✅ Green: All checks passed
- ❌ Red: Failures require attention
- 🟡 Yellow: Warnings or partial failures

### Dependency Updates

The dependency update workflow runs weekly and:
- Checks for new KNXD versions
- Creates GitHub issues for updates
- Provides automated PRs for patch versions
- Scans for security vulnerabilities

### Security Scanning

Security scans run on every build and:
- Upload results to GitHub Security tab
- Fail builds on critical vulnerabilities
- Provide detailed vulnerability reports

## Troubleshooting

### Common Issues

1. **Docker Hub Authentication Failed**
   - Verify `DOCKER_USERNAME` and `DOCKER_PASSWORD` secrets
   - Check Docker Hub token permissions

2. **Build Failures**
   - Check Dockerfile syntax with hadolint
   - Verify KNXD version exists
   - Review build logs for specific errors

3. **Test Failures**
   - Check environment variable validation
   - Verify configuration templates
   - Review health check implementation

4. **Documentation Validation Failures**
   - Fix markdown linting issues
   - Update broken links
   - Verify file references exist

### Debug Workflows

Enable debug logging by setting repository secrets:
```
ACTIONS_STEP_DEBUG: true
ACTIONS_RUNNER_DEBUG: true
```

## Contributing

When contributing to workflows:

1. Test changes in a fork first
2. Use workflow dispatch for testing
3. Follow existing patterns and naming
4. Update this documentation
5. Consider security implications

## Workflow Metrics

The workflows provide comprehensive metrics:

- Build times and success rates
- Test coverage and results
- Security scan results
- Documentation quality metrics
- Dependency update frequency

These metrics help maintain project quality and identify areas for improvement.
