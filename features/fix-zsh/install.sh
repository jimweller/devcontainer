#!/bin/sh
# This script runs as root during the container build.
# The default non-root user in dev containers is 'vscode' with home dir /home/vscode.
# tar -czvf devcontainer-feature-fix-zsh-feature.tgz -C fix-zsh-feature .

# make a temporary .zshrc that just waits for dotbot to create a symlink
cat > /home/vscode/.zshrc << 'EOF'
if [[ ! -L ~/.zshrc ]]; then
  while [[ ! -L ~/.zshrc ]]; do sleep 1; done
  exec zsh
fi
EOF