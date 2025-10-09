#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Script : install_docker.sh
# Objet  : Installation complète de Docker Engine et Docker Compose
# Auteur : Formateur DevOps
# Usage  : sudo bash install_docker.sh
# Note: Excuter bash: sed -i 's/\r$//' install_docker.sh
# après le transfert du fichier depuis windows vers linux
# ---------------------------------------------------------------------------

set -euo pipefail

# === Fonctions utilitaires ==================================================

log() {
  echo -e "\e[1;32m[+] $*\e[0m"
}

error_exit() {
  echo -e "\e[1;31m[ERREUR] $*\e[0m" >&2
  exit 1
}

# === Vérification des privilèges ===========================================

if [[ $EUID -ne 0 ]]; then
  error_exit "Ce script doit être exécuté en root ou avec sudo."
fi

# === Étape 1 : Préparation du système ======================================

log "Mise à jour du système..."
apt update -y || error_exit "Échec de apt update"
apt install -y ca-certificates curl gnupg lsb-release || error_exit "Échec d'installation des dépendances"

# === Étape 2 : Suppression d'anciennes versions ============================

log "Suppression d'anciennes versions de Docker (si existantes)..."
apt remove -y docker docker-engine docker.io containerd runc >/dev/null 2>&1 || true

# === Étape 3 : Ajout de la clé GPG Docker ==================================

log "Ajout de la clé GPG officielle de Docker..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg || error_exit "Impossible de récupérer la clé GPG Docker"
chmod a+r /etc/apt/keyrings/docker.gpg

# === Étape 4 : Ajout du dépôt officiel Docker ==============================

DISTRO=$(lsb_release -cs)
log "Ajout du dépôt Docker stable pour la distribution : ${DISTRO}"
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") ${DISTRO} stable" \
  > /etc/apt/sources.list.d/docker.list

# === Étape 5 : Installation des paquets Docker =============================

log "Installation des paquets Docker Engine et Compose..."
apt update -y
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || \
  error_exit "Échec d'installation de Docker"

# === Étape 6 : Démarrage et activation =====================================

log "Activation du service Docker..."
systemctl enable --now docker || error_exit "Impossible de démarrer Docker"

# === Étape 7 : Vérification ===============================================

log "Vérification de l'installation..."
docker --version || error_exit "Docker CLI non détecté"
docker compose version || log "Compose plugin non détecté"
systemctl is-active --quiet docker && log "Service Docker actif "

# === Étape 8 : Test fonctionnel ===========================================

log "Exécution du test hello-world..."
docker run --rm hello-world || error_exit "Le test Docker a échoué"

# === Étape 9 : Fin =========================================================

log "Docker Engine et Docker Compose ont été installés avec succès "
log "Vous pouvez exécuter : docker ps"

exit 0
