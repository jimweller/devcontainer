# devcontainer

Custom Docker-based development environment (0jimbox) managed via `devcontainer.sh` script.

## Overview

Ubuntu 24.04-based development container with pre-configured tools for cloud infrastructure work (AWS, Azure, Terraform, Kubernetes, etc.).

Containers are managed via the `devc` alias (points to `scripts/devcontainer.sh`), not VSCode's devcontainer feature.

## AWS Credentials Setup

This devcontainer uses a simplified AWS credential approach that works seamlessly on both host and container.

### How It Works

**Host Side:**
1. Long-lived SSO session token obtained via `aws sso login --profile mcg`
2. `scripts/aws-refresh-token.sh` runs via launchd (scheduled job)
3. Script periodically refreshes temporary token to `~/assets/aws/aws-token.json`
4. Token stays fresh automatically (runs every 8h, token valid for 12h)

**Container Side:**
1. Host `~/assets` directory mounted read-only to `/home/vscode/assets`
2. AWS config uses `credential_process = cat $HOME/assets/aws/aws-token.json`
3. Container reads fresh credentials automatically
4. No AWS SSO or authentication needed in container

### Prerequisites

1. Install and configure `aws-refresh-token.sh` on host:
   ```bash
   # One-time SSO login
   aws sso login --profile mcg
   
   # Install launchd job (macOS)
   cp scripts/aws-refresh-token.plist ~/Library/LaunchAgents/
   launchctl load ~/Library/LaunchAgents/com.user.refreshawstoken.plist
   
   # Verify token file exists
   cat ~/assets/aws/aws-token.json
   ```

2. Ensure `dotfiles/aws_config` has the default profile configured

### Usage

AWS credentials work automatically without any profile configuration:

```bash
# All commands use default profile (auto-refreshed token)
aws s3 ls
aws sts get-caller-identity
terraform plan
kubectl get nodes --context aws-cluster
```

### Named Profiles

The `[default]` profile uses the auto-refreshed token. Named profiles (mcg, granted, etc.) still work when explicitly specified:

```bash
# Use SSO directly when needed
aws sso login --profile mcg
aws s3 ls --profile mcg
```

### Troubleshooting

**No credentials found:**
- Check token file exists: `cat ~/assets/aws/aws-token.json`
- Verify launchd job running: `launchctl list | grep refreshawstoken`
- Check refresh log: `cat ~/assets/aws/refresh.log`

**Expired credentials:**
- Ensure SSO session valid: `aws sso login --profile mcg`
- Check launchd job executed recently: `cat ~/assets/aws/refresh.log`

**Container mount issues:**
- Verify assets directory mounted: `ls -la ~/assets/aws/` (in container)
- Check devcontainer.json has mount configuration

## Building and Usage

```bash
# Build the image
devc build

# Connect to container (interactive shell)
devc connect

# Execute command in container
devc exec aws s3 ls

# Show status
devc status

# See all options
devc help
```

The `devc` command (alias for `scripts/devcontainer.sh`) handles:
- Building the image
- Managing container lifecycle
- Auto-installing dotfiles on first connection
- Mounting workspace, Granted credentials, and AWS assets automatically

## Container Mounts

Each container automatically mounts:
- Current directory → `/workspace`
- Named volume for home directory (persists dotfiles, shell history, etc.)
- `~/.granted/secure-storage` → `/home/vscode/.granted/secure-storage` (if exists)
- `~/assets` → `/home/vscode/assets` (read-only, for AWS credentials)
