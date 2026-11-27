#!/usr/bin/env bash
# Installs eksctl, kubectl and helm into ~/bin in AWS CloudShell.
# ~/bin is in your home folder, which CloudShell KEEPS between sessions
# (/usr/local/bin is wiped when CloudShell restarts).
set -euo pipefail
mkdir -p "$HOME/bin"
grep -q 'HOME/bin' "$HOME/.bashrc" || echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
export PATH="$HOME/bin:$PATH"
cd /tmp

echo "== eksctl"
curl -sSLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz"
tar -xzf eksctl_Linux_amd64.tar.gz -C /tmp && install -m 0755 /tmp/eksctl "$HOME/bin/eksctl"
rm -f eksctl_Linux_amd64.tar.gz

echo "== kubectl"
KVER=$(curl -sSL https://dl.k8s.io/release/stable.txt)
curl -sSLo kubectl "https://dl.k8s.io/release/${KVER}/bin/linux/amd64/kubectl"
install -m 0755 kubectl "$HOME/bin/kubectl" && rm -f kubectl

echo "== helm"
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o get_helm.sh
HELM_INSTALL_DIR="$HOME/bin" USE_SUDO=false bash get_helm.sh
rm -f get_helm.sh

echo; eksctl version; kubectl version --client; helm version --short
echo "Done. Tools are in ~/bin."
