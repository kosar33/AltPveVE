#!/usr/bin/env bash
# =============================================================================
# LobeHub — CT-скрипт для Альт Виртуализация PVE
# Источник: https://github.com/lobehub/lobehub
# Адаптация: kosar33 / AltPveVE
# Лицензия: MIT
# =============================================================================
#
# Использование:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/kosar33/AltPveVE/main/ct/lobehub.sh)"
#
# Отличие от оригинала (community-scripts/ProxmoxVED):
#   - Загружает misc/build.func из нашего форка (адаптирован под Альт, без dpkg)
#   - install/lobehub-install.sh тоже берётся из нашего форка
#   - Параметры контейнера не меняются
# =============================================================================

# Указываем наш форк — build.func подхватит это как COMMUNITY_SCRIPTS_URL
# и будет брать install-скрипт оттуда же
export ALT_SCRIPTS_URL="https://raw.githubusercontent.com/kosar33/AltPveVE/main"

# Загружаем наш адаптированный build.func
source <(curl -fsSL "${ALT_SCRIPTS_URL}/misc/build.func")

# --- Параметры приложения (идентичны оригиналу) ---
APP="LobeHub"
var_tags="${var_tags:-ai;chat}"
var_cpu="${var_cpu:-6}"
var_ram="${var_ram:-10240}"
var_disk="${var_disk:-15}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

# --- Функция обновления (для уже установленного контейнера) ---
function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -d /opt/lobehub ]]; then
    msg_error "Установка ${APP} не найдена!"
    exit 1
  fi

  if check_for_gh_release "lobehub" "lobehub/lobehub"; then
    msg_info "Останавливаем службу"
    systemctl stop lobehub
    msg_ok "Служба остановлена"

    msg_info "Резервная копия конфигурации"
    cp /opt/lobehub/.env /opt/lobehub.env.bak
    msg_ok "Резервная копия создана"

    CLEAN_INSTALL=1 fetch_and_deploy_gh_release "lobehub" "lobehub/lobehub" "tarball"

    msg_info "Восстанавливаем конфигурацию"
    cp /opt/lobehub.env.bak /opt/lobehub/.env
    rm -f /opt/lobehub.env.bak
    msg_ok "Конфигурация восстановлена"

    msg_info "Сборка приложения"
    cd /opt/lobehub
    export NODE_OPTIONS="--max-old-space-size=8192"
    $STD pnpm install
    $STD pnpm run build:docker
    unset NODE_OPTIONS
    msg_ok "Приложение собрано"

    msg_info "Миграция базы данных"
    set -a && source /opt/lobehub/.env && set +a
    $STD node /opt/lobehub/.next/standalone/docker.cjs
    msg_ok "Миграция выполнена"

    msg_info "Запускаем службу"
    systemctl start lobehub
    msg_ok "Служба запущена"
    msg_ok "Обновление успешно завершено!"
  fi
  exit
}

# --- Запуск ---
start
build_container
description

msg_ok "Установка завершена!\n"
echo -e "${CREATING}${GN}${APP} развёрнут на Альт Виртуализация PVE!${CL}"
echo -e "${INFO}${YW} Адрес веб-интерфейса:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:3210${CL}"
