#!/usr/bin/env bash
set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
LOCAL_DIR="$(git rev-parse --show-toplevel)/site"

DRY_RUN=""
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN="yes"
fi

if [ ! -f "${LOCAL_DIR}/index.html" ]; then
    echo "Ошибка: файл site/index.html отсутствует!" >&2
    exit 1
fi

if ! git diff-index --quiet HEAD --; then
    echo "Ошибка: в репозитории есть незафиксированные изменения!" >&2
    exit 1
fi

if [[ -n "${DRY_RUN}" ]]; then
    echo "[DRY-RUN] Будут скопированы файлы:"
    scp -r -o BatchMode=yes "${LOCAL_DIR}"/* "${REMOTE}:${REMOTE_DIR}/"
    echo "Режим --dry-run завершен."
    exit 0
fi

echo "Начинаем синхронизацию..."
ssh -o BatchMode=yes "${REMOTE}" "rm -rf ${REMOTE_DIR}/*"
scp -r -o BatchMode=yes "${LOCAL_DIR}"/* "${REMOTE}:${REMOTE_DIR}/"
ssh -o BatchMode=yes "${REMOTE}" "chmod 755 ${REMOTE_DIR} && chmod 644 ${REMOTE_DIR}/*.html"

echo "Проверка доступности ${SITE_URL}..."
if ! curl -s -f --cacert "${CA_CERT}" -o /dev/null "${SITE_URL}"; then
    echo "Ошибка: сайт недоступен!" >&2
    exit 1
fi

echo "Деплой успешно завершен!"
exit 0
