#!/usr/bin/env bash
# ==============================================================================
# Installation de containerd + outils (nerdctl, crictl) sur Debian 12/13
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
# Pourquoi ? Disposer des derniers index APT et des outils nécessaires.
echo "📦 Mise à jour APT + installation dépendances..."
sudo apt update -y
sudo apt install -y ca-certificates curl gnupg lsb-release apt-transport-https

# --- [3] Installation de containerd -----------------------------------------
# Deux options possibles :
#  - A) paquet Debian officiel "containerd"
#  - B) paquet "containerd.io" depuis le dépôt Docker (souvent plus à jour)
# Nous prenons l'option B (recommandée pour la compatibilité outillée).

echo "🧱 Ajout de la clé GPG Docker (pour containerd.io)..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "🗂️  Ajout du dépôt Docker..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
 | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

echo "🔄 Refresh des index APT..."
sudo apt update -y

echo "🐳 Installation de containerd + outils CLI..."
# containerd (runtime) + nerdctl (CLI compatible Docker) + cri-tools (crictl/critest)
sudo apt install -y containerd.io nerdctl cri-tools

# --- [4] Configuration de containerd ----------------------------------------
# Pourquoi ? Générer un config.toml et activer cgroups systemd (recommandé pour K8s).
echo "⚙️  Génération du fichier /etc/containerd/config.toml..."
sudo mkdir -p /etc/containerd
sudo sh -c 'containerd config default > /etc/containerd/config.toml'

echo "🔧 Réglages recommandés (SystemdCgroup=true, sandbox_image pause)..."
# Activer systemd-cgroup
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
# Optionnel : image sandbox (pause) de la CRI (utile pour K8s)
sudo sed -i 's#sandbox_image = ".*"#sandbox_image = "registry.k8s.io/pause:3.9"#' /etc/containerd/config.toml

# --- [5] Démarrage & activation ---------------------------------------------
# Pourquoi ? Activer containerd au boot et démarrer maintenant.
echo "🚀 Activation du service containerd..."
sudo systemctl daemon-reload
sudo systemctl enable --now containerd

# --- [6] Vérifications & tests ---------------------------------------------
# Pourquoi ? S’assurer que tout fonctionne (containerd, nerdctl, CRI).
echo "✅ Vérifications versions..."
containerd --version
nerdctl --version
crictl --version

echo "🧪 Test d'exécution (hello-world) avec nerdctl..."
# Utilise le namespace containerd "default" (par défaut).
nerdctl run --rm hello-world

echo "🧪 Test CRI (info + images)..."
sudo crictl info | head -n 20 || true
sudo crictl images || true

echo "🎉 containerd est installé et opérationnel sur Debian."
echo "ℹ️  Astuce : 'nerdctl' accepte des commandes proches de 'docker'."
