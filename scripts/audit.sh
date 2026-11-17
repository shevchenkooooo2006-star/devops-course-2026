#!/usr/bin/env bash
set -uo pipefail

PASS=0; FAIL=0

check() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo " [OK]  $desc"; ((PASS++))
  else
    echo " [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"; ((FAIL++))
  fi
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"
check "Вход от имени root запрещён" "no" "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"
check "Парольная аутентификация отключена" "no" "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"

# TODO 1: проверьте, что значение параметра port отлично от 22
check "Порт SSH нестандартный" "2222" "$(sudo sshd -T | awk '/^port/{print $2}')"

# TODO 2: проверьте, что значение параметра maxauthtries равно 3
check "MaxAuthTries = 3" "3" "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"


echo "[2] Межсетевой экран"
check "Межсетевой экран активен" "active" "$(sudo ufw status | awk '/^Status:/{print $2}')"

# TODO 3: проверьте, что политика по умолчанию для входящего трафика равна deny
check "Политика по умолчанию deny" "deny" "$(sudo ufw status verbose | grep '^Default:' | awk '{print $2}')"


echo "[3] Учётные записи"
awk -F: ' $3>=1000 && $3<65534 {printf " %s (uid=%s)\n",$1,$3}' /etc/passwd

echo "[4] Веб-сервер"
# б) конфигурация nginx синтаксически корректна
check "Конфигурация Nginx корректна" "0" "$(sudo nginx -t >/dev/null 2>&1; echo $?)"

# в) сертификат истекает не ранее чем через 30 дней (2592000 секунд)
check "Сертификат действителен более 30 дней" "0" "$(sudo openssl x509 -checkend 2592000 -noout -in /etc/ssl/certs/devops.crt >/dev/null 2>&1; echo $?)"

# г) нет файлов, доступных для записи всем, и права ключа 600
check "Нет файлов с правом записи для всех" "" "$(sudo find /var/www/devops-site -perm -o+w)"
check "Права ключа TLS равны 600" "600" "$(sudo stat -c '%a' /etc/ssl/private/devops.key)"

echo "[5] Контейнеризация"
# а) служба docker активна
check "Служба Docker активна" "active" "$(systemctl is-active docker)"

# б) контейнер СУБД находится в состоянии healthy
# (ищем по имени сервиса db, так как имя контейнера может меняться)
check "СУБД в состоянии healthy" "healthy" "$(docker inspect -f '{{.State.Health.Status}}' $(docker compose --project-directory ~/app ps -q db))"

# в) порты 5000 и 5432 не прослушиваются ни на одном адресе, кроме 127.0.0.1
# (проверяем, что в выводе ss нет 0.0.0.0:5000 или *:5000)
check "Порт приложения только на 127.0.0.1" "" "$(sudo ss -tlnp | grep -E ':(5000|5432)\b' | grep -v '127.0.0.1')"

# г) права файла ~/app/.env равны 600
check "Права файла .env равны 600" "600" "$(stat -c '%a' ~/app/.env)"

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
