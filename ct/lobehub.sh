#!/usr/bin/env bash

# Скрипт для развертывания LobeHub в Альт Виртуализации (PVE)
# Контейнер: Debian 12 (т.к. 13 не поддерживается)

# Подтягиваем функции сборки (они совместимы с Альт Виртуализацией, так как API PVE совпадает)
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVED/main/misc/build.func)

APP="LobeHub"
var_tags="ai;chat"
var_cpu="6"
var_ram="10240"
var_disk="15"

# ВАЖНО: Устанавливаем Debian 12 для совместимости с Альт Виртуализацией
var_os="debian"
var_version="12" 

var_unprivileged="1"

header_info "$APP"

# Функция для корректного определения среды Альт Виртуализации
function check_alt_pve() {
  if ! command -v pveversion >/dev/null 2>&1; then
    msg_error "Это не среда Альт Виртуализации (PVE)!"
    exit 1
  fi
}

variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/lobehub ]]; then
    msg_error "Установка ${APP} не найдена!"
    exit
  fi

  if check_for_gh_release "lobehub" "lobehub/lobehub"; then
    msg_info "Остановка сервисов"
    systemctl stop lobehub
    
    msg_info "Резервное копирование данных"
    cp /opt/lobehub/.env /opt/lobehub.env.bak
    
    # Мы используем кастомную установку для Debian 12
    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "lobehub" "lobehub/lobehub" "tarball"

    msg_info "Восстановление конфигурации"
    cp /opt/lobehub.env.bak /opt/lobehub/.env
    rm -f /opt/lobehub.env.bak

    msg_info "Сборка приложения (Node.js)"
    cd /opt/lobehub
    export NODE_OPTIONS="--max-old-space-size=8192"
    # В Debian 12 используем актуальный pnpm
    $STD pnpm install
    $STD pnpm run build:docker
    unset NODE_OPTIONS

    msg_info "Миграция базы данных"
    set -a && source /opt/lobehub/.env && set +a
    $STD node /opt/lobehub/.next/standalone/docker.cjs
    
    msg_info "Запуск сервисов"
    systemctl start lobehub
    msg_ok "Обновление завершено!"
  fi
  exit
}

# Запуск процесса
check_alt_pve
start
build_container
description

msg_ok "Установка успешно завершена на Альт Виртуализации!\n"
echo -e "${CREATING}${GN}${APP} настроен и запущен!${CL}"
echo -e "${INFO}${YW} Доступ по адресу:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:3210${CL}"
