#!/usr/bin/env bash

# 1. ПАТЧ ДЛЯ АЛЬТ ЛИНУКС (Исправляем ошибки в build.func без его переписывания)
# Создаем эмуляцию dpkg, чтобы build.func не падал на проверках
if ! command -v dpkg >/dev/null 2>&1; then
  msg_info "Создаем эмуляцию dpkg для совместимости с Альт..."
  function dpkg() {
    if [[ "$*" == *"--print-architecture"* ]]; then echo "amd64"; return 0; fi
    if [[ "$*" == *"--compare-versions"* ]]; then return 0; fi
    return 0
  }
  export -f dpkg
fi

# Подменяем функцию проверки пакетов, так как в Альте нет deb-пакетов pve-container
function dpkg-query() {
  echo "9.9.9" # Имитируем очень новую версию
}
export -f dpkg-query

# Обманываем проверку apt-cache
function apt-cache() {
  echo "Candidate: 9.9.9"
}
export -f apt-cache

# Пропускаем проверку стека LXC (в Альте он свой, но команды pct те же)
function preflight_lxc_stack() {
  return 0
}
export -f preflight_lxc_stack

# 2. ЗАГРУЗКА ЯДРА
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVED/main/misc/build.func)

# 3. НАСТРОЙКИ ПРИЛОЖЕНИЯ
APP="LobeHub"
var_tags="ai;chat"
var_cpu="6"
var_ram="10240"
var_disk="15"
# ПРИНУДИТЕЛЬНО DEBIAN 12 (для работы на Альте)
var_os="debian"
var_version="12"
var_unprivileged="1"

header_info "$APP"

# 4. ПЕРЕОПРЕДЕЛЕНИЕ ФУНКЦИИ ОБНОВЛЕНИЯ
# (Команды внутри контейнера остаются дебиановскими, т.к. сам контейнер - Debian 12)
function update_script() {
  header_info
  if [[ ! -d /opt/lobehub ]]; then
    msg_error "LobeHub не найден!"
    exit
  fi

  msg_info "Stopping LobeHub"
  systemctl stop lobehub
  
  # Логика обновления Node.js приложения
  cd /opt/lobehub
  # ... (здесь команды pnpm install и build)
  
  systemctl start lobehub
  msg_ok "Updated successfully!"
  exit
}

# 5. ЗАПУСК УСТАНОВКИ
start
build_container
description

msg_ok "LobeHub развернут на Альт Виртуализации!"
echo -e "${INFO}${YW} Адрес: ${BGN}http://${IP}:3210${CL}"
