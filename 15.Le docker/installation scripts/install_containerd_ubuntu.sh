#!/usr/bin/env bash
# ==============================================================================
# Installation de containerd + outils (nerdctl, crictl) sur Ubuntu 22.04/24.04
# Objectif : installer un runtime prêt pour Kubernetes/CRI et tests CLI
# Auteur   : Vadima Entreprise
# Version  : 1.0
# ==============================================================================

set -euo pipefail

# --- [1] Pré-requis noyau & sysctl ------------------------------------------
# Pourquoi ? containerd (et K8s) nécessitent overlayfs + br_netfilter.
echo "🔧 Préparation noyau et sysctl..."
sudo modprobe overlay
sudo modprobe br_netfilter

# Activer le forwarding IPv4 et le traitement iptables sur les bridges.
sudo tee /etc/sysctl.d/99-k8s.conf >/dev/null <<'SYSCTL'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
SYSCTL
sudo sysctl --system >/dev/null

# --- [2] Mise à jour & dépendances ------------------------------------------
echo "📦 Mise à jour APT + installation dépendances..."
sudo apt update -y
sudo apt install -y ca-certificates curl gnupg lsb-release apt-transport-https

# --- [3] Installation de containerd -----------------------------------------
# Même logique que Debian : on privilégie le paquet "containerd.io" du dépôt Docker.

echo "🧱 Ajout de la clé GPG Docker..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "🗂️  Ajout du dépôt Docker..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
 | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

echo "🔄 Refresh des index APT..."
sudo apt update -y

echo "🐳 Installation de containerd + outils CLI..."
sudo apt install -y containerd.io nerdctl cri-tools

# --- [4] Configuration de containerd ----------------------------------------
echo "⚙️  Génération du fichier /etc/containerd/config.toml..."
sudo mkdir -p /etc/containerd
sudo sh -c 'containerd config default > /etc/containerd/config.toml'

echo "🔧 Réglages recommandés (SystemdCgroup=true, sandbox_image pause)..."
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo sed -i 's#sandbox_image = ".*"#sandbox_image = "registry.k8s.io/pause:3.9"#' /etc/containerd/config.toml

# --- [5] Démarrage & activation ---------------------------------------------
echo "🚀 Activation du service containerd..."
sudo systemctl daemon-reload
sudo systemctl enable --now containerd

# --- [6] Vérifications & tests ---------------------------------------------
echo "✅ Vérifications versions..."
containerd --version
nerdctl --version
crictl --version

echo "🧪 Test d'exécution (hello-world) avec nerdctl..."
nerdctl run --rm hello-world

echo "🧪 Test CRI (info + images)..."
sudo crictl info | head -n 20 || true
sudo crictl images || true

echo "🎉 containerd est installé et opérationnel sur Ubuntu."
echo "ℹ️  Astuce : vous pouvez aussi utiliser 'ctr' (CLI bas niveau) : 'sudo ctr images ls'."
