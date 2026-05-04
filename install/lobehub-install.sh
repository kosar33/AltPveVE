#!/usr/bin/env bash
# Автор адаптации: kosar33
# Источник оригинала: community-scripts/ProxmoxVED (lobehub-install.sh)
# Адаптировано для: Альт Виртуализация PVE — install-скрипт выполняется внутри
#                   LXC-контейнера Debian 12, поэтому apt-команды корректны.
# Лицензия: MIT

# ==============================================================================
# Этот скрипт выполняется ВНУТРИ LXC-контейнера (Debian 12).
# Хост-система — Альт Виртуализация PVE, но сам контейнер — стандартный Debian.
# ==============================================================================

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# ------------------------------------------------------------------------------
msg_info "Установка системных зависимостей"
$STD apt-get install -y \
  curl \
  git \
  ca-certificates \
  gnupg \
  build-essential \
  python3 \
  unzip
msg_ok "Системные зависимости установлены"

# ------------------------------------------------------------------------------
msg_info "Установка Node.js 22 LTS"
NODE_VERSION="22"
setup_nodejs
msg_ok "Node.js ${NODE_VERSION} установлен"

# ------------------------------------------------------------------------------
msg_info "Установка pnpm"
$STD npm install -g pnpm@latest
msg_ok "pnpm установлен"

# ------------------------------------------------------------------------------
msg_info "Скачивание последней версии LobeHub"
mkdir -p /opt/lobehub
RELEASE=$(curl -fsSL "https://api.github.com/repos/lobehub/lobehub/releases/latest" \
  | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
echo "${RELEASE}" > /opt/lobehub_version.txt

curl -fsSL "https://github.com/lobehub/lobehub/archive/refs/tags/${RELEASE}.tar.gz" \
  | tar -xz --strip-components=1 -C /opt/lobehub
msg_ok "LobeHub ${RELEASE} скачан"

# ------------------------------------------------------------------------------
msg_info "Создание конфигурации (.env)"
cat > /opt/lobehub/.env <<'ENVEOF'
# LobeHub конфигурация
# Документация: https://lobehub.com/docs/self-hosting/environment-variables

# Порт приложения
PORT=3210

# Ключ для подписи сессий (ОБЯЗАТЕЛЬНО смените в продакшене!)
AUTH_SECRET=change_me_please_generate_a_random_string_32chars

# База данных (по умолчанию — встроенная SQLite)
# Для PostgreSQL раскомментируйте и настройте:
# DATABASE_URL=postgresql://user:password@localhost:5432/lobehub

# Провайдер ИИ (раскомментируйте нужный):
# OPENAI_API_KEY=sk-...
# ANTHROPIC_API_KEY=sk-ant-...
# OLLAMA_PROXY_URL=http://localhost:11434
ENVEOF
msg_ok "Конфигурация создана (/opt/lobehub/.env)"

# ------------------------------------------------------------------------------
msg_info "Установка зависимостей Node.js"
cd /opt/lobehub
export NODE_OPTIONS="--max-old-space-size=8192"
$STD pnpm install --frozen-lockfile 2>/dev/null || $STD pnpm install
msg_ok "Зависимости установлены"

# ------------------------------------------------------------------------------
msg_info "Сборка приложения (это займёт несколько минут)"
$STD pnpm run build:docker
unset NODE_OPTIONS
msg_ok "Приложение собрано"

# ------------------------------------------------------------------------------
msg_info "Инициализация базы данных"
set -a
source /opt/lobehub/.env
set +a
$STD node /opt/lobehub/.next/standalone/docker.cjs
msg_ok "База данных инициализирована"

# ------------------------------------------------------------------------------
msg_info "Создание systemd-службы"
cat > /etc/systemd/system/lobehub.service <<'SVCEOF'
[Unit]
Description=LobeHub AI Chat Platform
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/lobehub
EnvironmentFile=/opt/lobehub/.env
ExecStart=/usr/bin/node /opt/lobehub/.next/standalone/server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=lobehub

# Ограничения ресурсов
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl enable --now lobehub
msg_ok "Служба lobehub создана и запущена"

# ------------------------------------------------------------------------------
motd_ssh
customize

# Добавляем информационное сообщение в MOTD
cat >> /etc/motd <<'MOTDEOF'

  ╔══════════════════════════════════════╗
  ║         LobeHub AI Platform          ║
  ║  Веб-интерфейс: http://<IP>:3210    ║
  ║  Конфиг:  /opt/lobehub/.env         ║
  ║  Логи:    journalctl -u lobehub -f  ║
  ╚══════════════════════════════════════╝

MOTDEOF

cleanup_lxc
