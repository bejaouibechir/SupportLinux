#!/usr/bin/env bash
# ========================================================================
# Installation de Buildah (et outils rootless) sur Debian 12/13 (bookworm/trixie)
# Objectif : installer Buildah prêt à l'emploi en mode rootless (sans sudo)
# Auteur   : Vadima Entreprise
# Version  : 1.0
# ========================================================================

set -euo pipefail

# --- [1] Vérifications préalables -----------------------------------------
# Pourquoi ? S'assurer qu'on est bien sur une Debian et récupérer la version.
if ! [ -r /etc/os-release ]; then
  echo "❌ /etc/os-release introuvable. Ce script vise Debian (12/13)." >&2
  exit 1
fi
. /etc/os-release
echo "ℹ️  Distribution : $PRETTY_NAME"

# --- [2] Mise à jour + dépendances système --------------------------------
# Pourquoi ? Avoir les derniers index de paquets et installer les composants
# nécessaires au mode rootless (slirp4netns, fuse-overlayfs, uidmap, CNI).
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

# Remarque : podman est installé car il facilite l'exécution de l'image
# construite (ex: `podman run ...`). Buildah seul suffit pour la construction.

# --- [3] Préparation du mode rootless pour l'utilisateur courant ----------
# Pourquoi ? Buildah rootless nécessite des plages subuid/subgid et overlay rootless.
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"

echo "👤 Configuration rootless pour l'utilisateur: $USER_NAME"

# 3.1 Définir des subuid/subgid si absents (100000:65536 est un choix courant).
# Pourquoi ? Requis par l'isolation user namespace en rootless.
if ! grep -q "^${USER_NAME}:" /etc/subuid; then
  echo "🧩 Ajout subuid pour $USER_NAME"
  echo "${USER_NAME}:100000:65536" | sudo tee -a /etc/subuid >/dev/null
fi
if ! grep -q "^${USER_NAME}:" /etc/subgid; then
  echo "🧩 Ajout subgid pour $USER_NAME"
  echo "${USER_NAME}:100000:65536" | sudo tee -a /etc/subgid >/dev/null
fi

# 3.2 Configurer le storage overlay rootless (fuse-overlayfs).
# Pourquoi ? Améliorer performances/compatibilité du stockage des couches.
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
additionalimagestores = []
CONF
  # Remplacement des placeholders UID/USER par les vraies valeurs
  sed -i "s|UID|$(id -u ${USER_NAME})|g" "$STORAGE_CONF"
  sed -i "s|/home/USER|${USER_HOME}|g" "$STORAGE_CONF"
  chown -R "${USER_NAME}:${USER_NAME}" "${USER_HOME}/.config"
fi

# 3.3 Définir des registres par défaut (facultatif, mais pratique).
REG_CONF="${USER_HOME}/.config/containers/registries.conf"
if [ ! -f "$REG_CONF" ]; then
  echo "🗂️  Création ${REG_CONF}"
  cat > "$REG_CONF" <<'CONF'
unqualified-search-registries = ["docker.io", "quay.io", "ghcr.io"]

[[registry]]
prefix = "docker.io"
location = "registry-1.docker.io"

[[registry]]
prefix = "quay.io"
location = "quay.io"

[[registry]]
prefix = "ghcr.io"
location = "ghcr.io"
CONF
  chown "${USER_NAME}:${USER_NAME}" "$REG_CONF"
fi

# --- [4] Vérifications rapides -------------------------------------------
# Pourquoi ? Valider que buildah fonctionne et détecte le mode rootless.
echo "✅ Vérifications de base..."
sudo -u "$USER_NAME" bash -lc '
  echo "• buildah version : $(buildah version | head -n1)"
  echo "• info stockage   :"; buildah info | grep -E "rootless|driver" || true
'

# --- [5] Test de construction minimal (rootless) --------------------------
# Pourquoi ? Prouver que la construction d’image fonctionne réellement.
echo "🧪 Test : construction d\'une image minimaliste (alpine -> echo)..."
sudo -u "$USER_NAME" bash -lc '
  set -e
  # Tirer une base alpine et y ajouter une "preuve de build"
  ctr=$(buildah from docker.io/library/alpine:3.20)
  mnt=$(buildah mount "$ctr")
  echo "Hello from Buildah rootless" > "$mnt/HELLO.txt"
  buildah config --cmd "[\"cat\",\"/HELLO.txt\"]" "$ctr"
  img_ref="local/buildah-hello:latest"
  buildah commit "$ctr" "$img_ref"
  buildah unmount "$ctr"
  buildah rm "$ctr"
  echo "▶ Exécution du conteneur avec podman (rootless) :"
  podman run --rm "$img_ref"
'

# --- [6] Conseils & fin ---------------------------------------------------
echo "🎉 Buildah (rootless) est prêt."
echo "ℹ️  Note : Aucun groupe 'docker' n'est requis pour Buildah/Podman."
echo "ℹ️  Astuce : Pour éviter les soucis de réseau rootless, assurez-vous que 'slirp4netns' est bien installé (fait)."
