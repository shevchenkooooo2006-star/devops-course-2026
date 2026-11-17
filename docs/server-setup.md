## 8. Веб-сервер
- Устанавливаемый пакет: `nginx` (устанавливался командой `sudo apt install nginx`).
- Путь к конфигурации ресурса: `/etc/nginx/sites-available/devops-site` (активирован симлинком в `/etc/nginx/sites-enabled/`).
- Каталог ресурса: `/var/www/devops-site`, владелец `devops:devops`, права `755` для каталога и `644` для файлов.
- Пути к сертификату и ключу: `/etc/ssl/certs/devops.crt` (права 644, владелец root) и `/etc/ssl/private/devops.key` (права 600, владелец root).
- Команда формирования сертификата:
  `sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/devops.key -out /etc/ssl/certs/devops.crt -subj "/CN=devops.local" -addext "subjectAltName=DNS:devops.local"`
- Срок действия сертификата: 365 дней.
## 9. Контейнеризация
- **Способ установки Docker Engine**: официальный репозиторий Docker (команды `apt install docker-ce ...`).
- **Версия Docker**: 28.x (или ваша версия, посмотрите командой `docker version`).
- **Участники группы docker**: пользователь `devops`.
- **Расположение проекта на сервере**: `/home/devops/app`.
- **Расположение файла `.env` и его права**: `/home/devops/app/.env`, права `600` (владелец `devops`).
- **Публикуемые порты и адреса**: только `127.0.0.1:5000` (порт приложения). Порт базы данных (5432) не публикуется.
- **Именованные тома**: `app_db_data` (хранит данные PostgreSQL в `/var/lib/postgresql/data`).
- **Конфигурация обратного прокси-сервера**: Nginx проксирует запросы с `https://devops.local/app/` на `http://127.0.0.1:5000/`, передавая заголовки `Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`.
