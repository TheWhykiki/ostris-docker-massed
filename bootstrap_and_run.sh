#!/usr/bin/env bash

# Fehlerbehandlung: Bei Fehler nicht sofort beenden, sondern Fenster offen halten
error_handler() {
  echo ""
  echo "========================================="
  echo "=== FEHLER aufgetreten! ==="
  echo "========================================="
  echo ""
  echo "Drücke Enter zum Beenden..."
  read
  exit 1
}
trap error_handler ERR

set -uo pipefail

# ---------- helpers ----------
have() { command -v "$1" >/dev/null 2>&1; }

is_root() { [ "$(id -u)" -eq 0 ]; }

sudo_if_needed() {
  if is_root; then
    "$@"
  else
    sudo "$@"
  fi
}

detect_nvidia() {
  have nvidia-smi && nvidia-smi >/dev/null 2>&1
}

# ---------- 1) Docker installieren ----------
if ! have docker; then
  echo "[bootstrap] Docker fehlt -> installiere via get.docker.com"
  curl -fsSL https://get.docker.com | sudo_if_needed sh
  sudo_if_needed systemctl enable --now docker
else
  echo "[bootstrap] Docker vorhanden"
fi

# ---------- 2) NVIDIA Container Toolkit (für --gpus) ----------
if detect_nvidia; then
  echo "[bootstrap] NVIDIA GPU erkannt -> installiere nvidia-container-toolkit (falls nötig)"
  if ! dpkg -s nvidia-container-toolkit >/dev/null 2>&1; then
    sudo_if_needed apt-get update
    sudo_if_needed apt-get install -y --no-install-recommends curl gnupg2
    distribution=$(. /etc/os-release; echo "${ID}${VERSION_ID}")
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
      | sudo_if_needed gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L "https://nvidia.github.io/libnvidia-container/${distribution}/libnvidia-container.list" \
      | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
      | sudo_if_needed tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null
    sudo_if_needed apt-get update
    sudo_if_needed apt-get install -y nvidia-container-toolkit
    if have nvidia-ctk; then
      sudo_if_needed nvidia-ctk runtime configure --runtime=docker
    fi
    sudo_if_needed systemctl restart docker
  else
    echo "[bootstrap] nvidia-container-toolkit ist schon installiert"
  fi
else
  echo "[bootstrap] Keine NVIDIA GPU erkannt (oder nvidia-smi fehlt) -> starte ohne GPU-Setup"
fi

# ---------- 3) Compose starten ----------
if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif have docker-compose; then
  COMPOSE="docker-compose"
else
  echo "Weder 'docker compose' noch 'docker-compose' gefunden."
  echo ""
  echo "Drücke Enter zum Beenden..."
  read
  exit 1
fi

echo ""
echo "========================================="
echo "[bootstrap] Build + Run"
echo "UI wird verfügbar unter: http://localhost:8675"
echo "Auth-Token/Passwort: AI_TOOLKIT_AUTH (default: password)"
echo "========================================="
echo ""

$COMPOSE up --build

# Dieser Teil wird nur erreicht wenn der Container gestoppt wird (Ctrl+C)
echo ""
echo "========================================="
echo "Container wurde beendet."
echo "Zum erneuten Starten: $COMPOSE up"
echo "Zum Starten im Hintergrund: $COMPOSE up -d"
echo "========================================="
echo ""
echo "Drücke Enter zum Beenden..."
read
