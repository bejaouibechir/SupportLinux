#!/usr/bin/env bash
# ==============================================================================
# Installation complète de Podman (rootless) sur Ubuntu 22.04 / 24.04
# Auteur   : Vadima Entreprise
# Version  : 1.0
# Objectif : Installer Podman prêt à l'emploi pour les utilisateurs non-root
# ==============================================================================

set -euo pipefail

# --- [1] Vérification de la distribution ------------------------------------
if ! [ -r /etc/os-release ]; then
  echo "❌ Ce script est prévu pour Ubuntu." >&2
  exit 1
fi
. /etc/os-release
echo "ℹ️  Distribution détectée : $PRETTY_NAME"

# --- [2] Mise à jour du système --------------------------------------------
echo "🔧 Mise à jour du système..."
sudo apt update -y
sudo apt upgrade -y

# --- [3] Installation de Podman et dépendances -----------------------------
echo "📦 Installation de Podman et des dépendances rootless..."
sudo apt install -y podman uidmap slirp4netns fuse-overlayfs iptables curl ca-certificates

# --- [4] Activation des user namespaces si nécessaire ----------------------
if [ "$(sysctl -n kernel.unprivileged_userns_clone)" != "1" ]; then
  echo "🧩 Activation du support userns..."
  sudo sysctl kernel.unprivileged_userns_clone=1
  echo "kernel.unprivileged_userns_clone=1" | sudo tee /etc/sysctl.d/99-userns.conf >/dev/null
  sudo sysctl --system >/dev/null
fi

# --- [5] Configuration rootless pour l’utilisateur -------------------------
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
echo "👤 Configuration rootless pour $USER_NAME"

if ! grep -q "^${USER_NAME}:" /etc/subuid; then
  echo "${USER_NAME}:100000:65536" | sudo tee -a /etc/subuid >/dev/null
fi
if ! grep -q "^${USER_NAME}:" /etc/subgid; then
  echo "${USER_NAME}:100000:65536" | sudo tee -a /etc/subgid >/dev/null
fi

mkdir -p "${USER_HOME}/.config/containers"
STORAGE_CONF="${USER_HOME}/.config/containers/storage.conf"
if [ ! -f "$STORAGE_CONF" ]; then
  echo "🗄️  Création ${STORAGE_CONF}"
  cat > "$STORAGE_CONF" <<'CONF'
[storage]
driver = "overlay"
runroot = "/run/user/UID/containers"
graphroot = "/home/USER/.local/share/containers/storage"
[storage.options]
mount_program = "/usr/bin/fuse-overlayfs"
CONF
  sed -i "s|UID|$(id -u ${USER_NAME})|g" "$STORAGE_CONF"
  sed -i "s|/home/USER|${USER_HOME}|g" "$STORAGE_CONF"
  sudo chown -R "${USER_NAME}:${USER_NAME}" "${USER_HOME}/.config"
fi

# --- [6] Vérification et test ----------------------------------------------
sudo -u "$USER_NAME" bash -lc '
  echo "✅ Version de Podman : $(podman --version)"
  echo "🧪 Test : exécution d’un conteneur hello-world..."
  podman run --rm docker.io/library/hello-world
'

echo "🎉 Podman rootless est installé et fonctionnel sur Ubuntu."
