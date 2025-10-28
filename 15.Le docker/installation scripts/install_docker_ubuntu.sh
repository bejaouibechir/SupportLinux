#!/usr/bin/env bash
# ============================================================
# Script d'installation automatique de Docker sur Ubuntu
# Auteur  : Bechir (Vadima Entreprise)
# Version : 1.0
# Objectif: Installer Docker proprement sur Ubuntu (20.04, 22.04, 24.04)
# ============================================================

set -euo pipefail

echo "🔧 Mise à jour du système..."
sudo apt update -y
sudo apt upgrade -y

echo "📦 Installation des dépendances nécessaires..."
sudo apt install -y ca-certificates curl gnupg lsb-release

echo "🧱 Ajout de la clé GPG officielle de Docker..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "🗂️ Ajout du dépôt Docker officiel à APT..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "🔄 Mise à jour de la liste des paquets..."
sudo apt update -y

echo "🐳 Installation de Docker Engine et des composants associés..."
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "🚀 Démarrage et activation du service Docker..."
sudo systemctl enable docker
sudo systemctl start docker

echo "👤 Ajout de l'utilisateur courant au groupe docker..."
sudo usermod -aG docker "$USER"

echo "⚙️ Activation immédiate du groupe (sans redémarrage de session)..."
newgrp docker <<EOC
echo "✅ Vérification :"
docker --version
docker run --rm hello-world
EOC

echo "🎉 Installation terminée avec succès ! Vous pouvez maintenant utiliser Docker sans sudo."
