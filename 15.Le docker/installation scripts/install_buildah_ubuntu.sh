#!/usr/bin/env bash
# ==============================================================================
# Installation de Buildah (et outils rootless) sur Ubuntu 22.04 / 24.04
# Objectif : installer Buildah prêt à l'emploi en mode rootless (sans sudo)
# Auteur   : Vadima Entreprise
# Version  : 1.0
# ==============================================================================

set -euo pipefail

# --- [1] Vérifications préalables -------------------------------------------
# Pourquoi ? Afficher la distribution pour le journal et éviter les surprises.
if ! [ -r /etc/os-release ]; then
  echo "❌ /etc/os-release introuvable. Script prévu pour Ubuntu 22.04/24.04." >&2
  exit 1
fi
. /etc/os-release
echo "ℹ️  Distribution : $PRETTY_NAME"

# --- [2] Mise à jour + dépendances système ----------------------------------
# Pourquoi ? Avoir des index récents et installer les outils nécessaires au rootless.
echo "🔧 Mise à jour APT..."
sudo apt update -y
sudo apt upgrade -y

echo "📦 Installation des paquets requis (buildah + outils rootless)..."
sudo apt install -y \
  buildah \
  podman \
  uidmap \
  slirp4netns \
  fuse-overlayfs \
  containernetworking-plugins \
  iptables \
  curl ca-certificates

# Remarque : podman facilite l'exécution des images construites avec Buildah.

# --- [3] Activer les user namespaces si nécessaire --------------------------
# Pourquoi ? Le mode rootless s'appuie sur les user namespaces.
# Sur Ubuntu récents, c'est normalement déjà activé, mais on s'assure.
echo "🛡️  Vérification de kernel.unprivileged_userns_clone..."
if [ "$(sysctl -n kernel.unprivileged_userns_clone)" != "1" ]; then
  echo "➡️  Activation temporaire..."
  sudo sysctl kernel.unprivileged_userns_clone=1
  echo "➡️  Activation persistante..."
  echo "kernel.unprivileged_userns_clone=1" | sudo tee /etc/sysctl.d/99-userns.conf >/dev/null
  sudo sysctl --system >/dev/null
fi

# --- [4] Préparation rootless pour l'utilisateur courant --------------------
# Pourquoi ? Buildah rootless requiert des plages subuid/subgid et overlay rootless.
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"

echo "👤 Configuration rootless pour l'utilisateur: $USER_NAME"

# 4.1 Déclarer subuid/subgid si absents (100000:65536 est une plage courante).
if ! grep -q "^${USER_NAME}:" /etc/subuid; then
  echo "🧩 Ajout subuid pour $USER_NAME"
  echo "${USER_NAME}:100000:65536" | sudo tee -a /etc/subuid >/dev/null
fi
if ! grep -q "^${USER_NAME}:" /etc/subgid; then
  echo "🧩 Ajout subgid pour $USER_NAME"
  echo "${USER_NAME}:100000:65536" | sudo tee -a /etc/subgid >/dev/null
fi

# 4.2 Configurer le stockage overlay rootless (fuse-overlayfs) côté utilisateur.
mkdir -p "${USER_HOME}/.config/containers"
STORAGE_CONF="${USER_HOME}/.config/containers/storage.conf"
if [ ! -f "$STORAGE_CONF" ]; then
  echo "🗄️  Création ${STORAGE_CONF}"
  cat > "$STORAGE_CONF" <<'CONF'
[storage]
driver = "overlay"
runroot = "/run/user/UID/containers"
