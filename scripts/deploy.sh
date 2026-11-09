#!/usr/bin/env bash

# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]
set -euo pipefail

# Псевдоним из ~/.ssh/config (ПР № 5)
REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
LOCAL_DIR="$(git rev-parse --show-toplevel)/site/"

# 1. Разбор аргумента --dry-run
DRY_RUN=""
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN="--dry-run"
fi

# 2. Проверки по требованиям 4 и 5
if [ ! -f "${LOCAL_DIR}index.html" ]; then
    echo "Ошибка: файл site/index.html отсутствует!" >&2
    exit 1
fi

if ! git diff-index --quiet HEAD --; then
    echo "Ошибка: в репозитории есть незафиксированные изменения!" >&2
    exit 1
fi

# 3. Синхронизация каталога ${LOCAL_DIR} на ${REMOTE}:${REMOTE_DIR}
# Используем ssh -o BatchMode=yes, чтобы скрипт не зависал на запросе пароля
echo "Начинаем синхронизацию..."
rsync -avz --delete --chmod=D755,F644 -e "ssh -o BatchMode=yes -o ConnectTimeout=5" \
    ${DRY_RUN} "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/"

# 4. При --dry-run — завершение с кодом 0 без проверки доступности
if [[ -n "${DRY_RUN}" ]]; then
    echo "Режим --dry-run завершен. Изменения не вносились."
    exit 0
fi

# 5. Проверка доступности ${SITE_URL}
echo "Проверка доступности ${SITE_URL}..."
if ! curl -s -f --cacert "${CA_CERT}" -o /dev/null "${SITE_URL}"; then
    echo "Ошибка: сайт недоступен!" >&2
    exit 1
fi

echo "Деплой успешно завершен!"
exit 0
