## 8. Веб-сервер
- Устанавливаемый пакет: `nginx` (устанавливался командой `sudo apt install nginx`).
- Путь к конфигурации ресурса: `/etc/nginx/sites-available/devops-site` (активирован симлинком в `/etc/nginx/sites-enabled/`).
- Каталог ресурса: `/var/www/devops-site`, владелец `devops:devops`, права `755` для каталога и `644` для файлов.
- Пути к сертификату и ключу: `/etc/ssl/certs/devops.crt` (права 644, владелец root) и `/etc/ssl/private/devops.key` (права 600, владелец root).
- Команда формирования сертификата:
  `sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/devops.key -out /etc/ssl/certs/devops.crt -subj "/CN=devops.local" -addext "subjectAltName=DNS:devops.local"`
- Срок действия сертификата: 365 дней.
