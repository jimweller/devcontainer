#!/bin/bash

tmpdir=$(mktemp -d)
cd $tmpdir

apt-get -y install wget sudo

# gh
wget -nv -O- https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list

# granted
wget -nv -O- https://apt.releases.commonfate.io/gpg | gpg --dearmor -o /usr/share/keyrings/common-fate-linux.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/common-fate-linux.gpg] https://apt.releases.commonfate.io stable main" | tee /etc/apt/sources.list.d/common-fate.list

# node 20
curl -fsSL https://deb.nodesource.com/setup_20.x -o nodesource_setup.sh
bash nodesource_setup.sh

# uv
curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="/usr/local/bin" sh

apt-get update
apt-get upgrade -y
apt-get install -y gh granted nodejs

# aws cli
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# az cli
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# claude code
npm install -g @anthropic-ai/claude-code

# use npx instead. It's moving to fast to justify installing
# npm install -g claude-flow@alpha

rm -rf /var/lib/apt/lists/*
