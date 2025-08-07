# GitHub Secrets Setup for Docker Hub Authentication

This guide explains how to set up Docker Hub authentication secrets in GitHub to enable automated Docker image publishing in the CI/CD pipeline.

## Prerequisites

1. **Docker Hub Account**: You need a Docker Hub account
2. **GitHub Repository**: Admin access to your GitHub repository
3. **Docker Hub Repository**: A repository on Docker Hub where images will be pushed

## Step 1: Create Docker Hub Access Token

### 1.1 Log in to Docker Hub
1. Go to [Docker Hub](https://hub.docker.com/)
2. Sign in with your credentials

### 1.2 Generate Access Token
1. Click on your username in the top-right corner
2. Select **"Account Settings"**
3. Go to the **"Security"** tab
4. Click **"New Access Token"**
5. Provide a description (e.g., "GitHub Actions CI/CD")
6. Select permissions:
   - **Read, Write, Delete** (recommended for full CI/CD functionality)
   - Or **Read, Write** (minimum required for pushing images)
7. Click **"Generate"**
8. **IMPORTANT**: Copy the token immediately - you won't be able to see it again!

## Step 2: Add Secrets to GitHub Repository

### 2.1 Navigate to Repository Settings
1. Go to your GitHub repository
2. Click on **"Settings"** tab
3. In the left sidebar, click **"Secrets and variables"**
4. Click **"Actions"**

### 2.2 Add Docker Hub Username
1. Click **"New repository secret"**
2. **Name**: `DOCKER_USERNAME`
3. **Secret**: Your Docker Hub username (e.g., `michelmu`)
4. Click **"Add secret"**

### 2.3 Add Docker Hub Access Token
1. Click **"New repository secret"**
2. **Name**: `DOCKER_PASSWORD`
3. **Secret**: Paste the access token you generated in Step 1.2
4. Click **"Add secret"**

## Step 3: Verify Secrets Configuration

After adding the secrets, you should see:
- ✅ `DOCKER_USERNAME` - Added [timestamp]
- ✅ `DOCKER_PASSWORD` - Added [timestamp]

## Step 4: Update Workflow Configuration (if needed)

The current workflow in `.github/workflows/build-and-release.yml` is already configured to use these secrets:

```yaml
- name: Log in to Docker Hub
  if: github.event_name != 'pull_request'
  uses: docker/login-action@v3
  with:
    registry: ${{ env.REGISTRY }}
    username: ${{ secrets.DOCKER_USERNAME }}
    password: ${{ secrets.DOCKER_PASSWORD }}
```

## Step 5: Test the Setup

### 5.1 Trigger a Build
1. Push a commit to the `main` branch, or
2. Create a tag (e.g., `git tag v1.0.0 && git push origin v1.0.0`), or
3. Manually trigger the workflow:
   - Go to **Actions** tab
   - Select **"Build and Release"** workflow
   - Click **"Run workflow"**
   - Choose branch and options
   - Click **"Run workflow"**

### 5.2 Monitor the Build
1. Go to the **Actions** tab
2. Click on the running workflow
3. Check the **"Build Docker Image"** job
4. Look for the **"Log in to Docker Hub"** step - it should show:
   ```
   Login Succeeded
   ```

## Troubleshooting

### Common Issues and Solutions

#### 1. "Username and password required" Error
**Cause**: Secrets not properly configured or workflow trying to push without authentication.

**Solutions**:
- Verify secrets are named exactly: `DOCKER_USERNAME` and `DOCKER_PASSWORD`
- Check that the Docker Hub access token has write permissions
- Ensure the workflow condition `if: github.event_name != 'pull_request'` is working

#### 2. "Authentication failed" Error
**Cause**: Invalid credentials or expired token.

**Solutions**:
- Regenerate Docker Hub access token
- Update the `DOCKER_PASSWORD` secret with the new token
- Verify the username is correct (case-sensitive)

#### 3. "Repository does not exist" Error
**Cause**: Docker Hub repository doesn't exist or wrong repository name.

**Solutions**:
- Create the repository on Docker Hub first
- Verify the `IMAGE_NAME` in the workflow matches your Docker Hub repository
- Check the registry URL is correct (`docker.io`)

#### 4. "Permission denied" Error
**Cause**: Access token doesn't have sufficient permissions.

**Solutions**:
- Regenerate token with **Read, Write** or **Read, Write, Delete** permissions
- Update the `DOCKER_PASSWORD` secret

### Debugging Steps

1. **Check Secret Names**:
   ```bash
   # In workflow logs, look for:
   # "Secret DOCKER_USERNAME is set: true"
   # "Secret DOCKER_PASSWORD is set: true"
   ```

2. **Verify Docker Hub Repository**:
   - Go to Docker Hub
   - Ensure repository `michelmu/knxd-docker` exists
   - Check repository visibility (public/private)

3. **Test Local Authentication**:
   ```bash
   # Test locally with same credentials
   echo "YOUR_TOKEN" | docker login --username YOUR_USERNAME --password-stdin
   ```

## Security Best Practices

### 1. Token Management
- **Use access tokens** instead of passwords
- **Limit token permissions** to minimum required
- **Rotate tokens regularly** (every 6-12 months)
- **Delete unused tokens** immediately

### 2. Secret Management
- **Never commit secrets** to code
- **Use repository secrets** for repository-specific credentials
- **Use organization secrets** for shared credentials across repositories
- **Regularly audit** who has access to secrets

### 3. Workflow Security
- **Limit secret access** to necessary jobs only
- **Use conditions** to prevent secret exposure in pull requests
- **Monitor workflow runs** for unauthorized access attempts

## Alternative: GitHub Container Registry

If you prefer to use GitHub Container Registry instead of Docker Hub:

### Update Workflow
```yaml
env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}
```

### Use GitHub Token
```yaml
- name: Log in to Container Registry
  uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

### Benefits
- **No additional secrets** required
- **Automatic authentication** with GitHub token
- **Integrated** with GitHub ecosystem
- **Free** for public repositories

## Verification Checklist

- [ ] Docker Hub account created
- [ ] Docker Hub access token generated with write permissions
- [ ] `DOCKER_USERNAME` secret added to GitHub repository
- [ ] `DOCKER_PASSWORD` secret added to GitHub repository
- [ ] Docker Hub repository exists (e.g., `michelmu/knxd-docker`)
- [ ] Workflow triggered and login step succeeds
- [ ] Docker images successfully pushed to Docker Hub

## Support

If you continue to experience issues:

1. **Check GitHub Actions logs** for detailed error messages
2. **Verify Docker Hub repository** settings and permissions
3. **Test authentication locally** with the same credentials
4. **Review workflow conditions** that might prevent authentication
5. **Consider using GitHub Container Registry** as an alternative

The CI/CD pipeline should now successfully authenticate with Docker Hub and push multi-platform images automatically!
