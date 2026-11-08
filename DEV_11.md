| | |
|---|---|
| **ДИСЦИПЛИНА** | Инструменты девопс |
| **ИНСТИТУТ** | ИРИП |
| **КАФЕДРА** | Индустриального программирования |
| **ВИД УЧЕБНОГО МАТЕРИАЛА** | Методические указания к практическим занятиям |
| **ПРЕПОДАВАТЕЛЬ** | Гиматдинов Дамир Маратович |
| **СЕМЕСТР** | 5 семестр, 2026/2027 учебный год |

Ссылка на материал:
https://gitverse.ru/dgimatdinov/DevOps_2026/content/master/DEV_11.md

---

# ПРАКТИЧЕСКАЯ РАБОТА № 11

**Тема: Управление конфигурациями. Ansible, роли, идемпотентность, автоматический деплой**

| | |
|---|---|
| **Дисциплина** | DevOps-практикум |
| **Курс** | 3 |
| **Занятие** | 11 из 16 |
| **Блок** | Автоматизация конфигураций и CI/CD (занятие 3 из 4) |
| **Форма работы** | Индивидуальная |
| **Продолжительность аудиторной части** | До 90 минут |

Работа выполняется на существующей VM `devops-vm`, возвращаемой к снимку `01-clean-install`. Вторая VM не требуется. Управляющий узел — хостовая система с Linux/macOS или ранее подготовленная WSL; управляемый узел — VM. Приложение не собирается на сервере: используется проверенный GHCR-образ из практической работы № 10.

---

## 1 Цель и задачи работы

Цель работы — сформировать практические навыки воспроизводимой настройки удалённого сервера и развёртывания контейнеризированного приложения средствами Ansible.

Задачи:

а) настроить inventory и безопасный переход от первичного доступа по паролю к последующим запускам по SSH-ключу;

б) реализовать роли `base`, `ssh`, `nginx` и `app` с разделением обязанностей;

в) установить Docker Engine из официального репозитория, настроить Nginx как reverse proxy и запустить образ GHCR по полному SHA;

г) проверить идемпотентность повторным запуском без изменений;

д) обнаружить и устранить ручное расхождение конфигурации (drift);

е) исследовать поведение плейбука при недоступной новой версии образа и сохранении текущего работающего контейнера.

**Связь с предыдущими работами.** Роли автоматизируют операции, которые ранее выполнялись вручную в работах № 5–7. Роль `app` использует образ, проверенный конвейером работы № 10. Документ `docs/server-setup.md` помогает определить требуемое конечное состояние, но само развёртывание теперь описывается декларативно.

**Связь с контрольной работой № 3.** В следующем занятии этот плейбук будет запускаться из GitHub Actions после изменения в `main`. Поэтому уже в настоящей работе повторный запуск не должен требовать интерактивного ввода пароля, а версия приложения должна быть задана переменной.

**Границы занятия.** HTTPS повторно не настраивается: TLS подробно исследован в работе № 6, а на чистой VM потребовал бы дополнительных задач с сертификатом. SSH остаётся на порту 22 в сегменте Host-only, чтобы не менять правила VirtualBox. В работе исследуются Ansible и воспроизводимость, а не повтор прежнего hardening.

---

## 2 Теоретическая часть

### 2.1 Управляющий и управляемый узлы

Ansible обычно работает по модели push: управляющий узел читает inventory, подключается к управляемым узлам по SSH, передаёт и выполняет модули. На управляемом узле нужны Python и SSH; отдельный постоянно работающий агент не требуется.

В настоящей работе:

- управляющий узел — Linux, macOS или WSL с Ansible;
- управляемый узел — чистая Ubuntu Server 24.04 на VM;
- первичный доступ — `student` по паролю;
- последующий доступ — `devops` по ключу `~/.ssh/devops_vm`.

**Важно.** Модули `docker_image` и `docker_container` выполняются на управляемом узле. Коллекция `community.docker` устанавливается на управляющем узле, а Python-зависимость модулей — на VM. Начиная с версии 3 коллекции эти модули не используют Docker SDK for Python: они обращаются к Docker API через клиент, встроенный в коллекцию, и требуют на VM только библиотеку `requests` (пакет `python3-requests`). Установка зависимостей только на управляющий узел недостаточна.

**Вход по паролю.** Для параметра `--ask-pass` Ansible передаёт пароль SSH-клиенту через утилиту `sshpass` на управляющем узле. Без неё первичный запуск завершается ошибкой `to use the 'ssh' connection type with passwords, you must install the sshpass program`. Последующие запуски по ключу `sshpass` не используют.

### 2.2 Inventory, переменные и плейбук

Inventory сопоставляет логическое имя узла параметрам подключения. Используются два файла:

- `bootstrap.ini` — первичный запуск от `student` с `--ask-pass` и `--ask-become-pass`;
- `prod.ini` — последующие запуски от `devops` по ключу, без интерактивного ввода.

Версия образа вынесена в `group_vars/all.yml`. Плейбук не содержит конкретный SHA внутри роли: новая версия меняется одной переменной.

Файл `site.yml` назначает роли всем узлам группы `vm` и включает `become: true`. Это означает выполнение административных задач через sudo. После первичной настройки учётная запись `devops` получает `NOPASSWD` для неинтерактивных запусков.

**Ограничение учебной конфигурации.** `devops ALL=(ALL) NOPASSWD:ALL` удобно для автоматизации, но даёт полный административный доступ без второго подтверждения. В промышленной среде перечень разрешённых команд следует ограничивать, а ключ и учётную запись — защищать как полноценный root-доступ.

### 2.3 Роли и обработчики

Роль — самостоятельная единица конфигурации со стандартной структурой `tasks`, `handlers`, `templates`, `defaults` и других каталогов.

| Роль | Ответственность |
|---|---|
| `base` | Проверка ОС, базовые пакеты, официальный репозиторий Docker, служба Docker |
| `ssh` | Пользователь `devops`, SSH-ключ, sudo, hardening SSH, UFW |
| `nginx` | Пакет Nginx, reverse proxy, активация ресурса, проверка конфигурации |
| `app` | Загрузка образа, контейнер, проверка `/health` |

Handler вызывается только при изменении уведомившей его задачи. В работе изменение SSH вызывает restart `ssh`, а изменение Nginx — сначала `nginx -t`, затем reload. Это исключает лишние перезапуски при повторном прогоне.

Handlers выполняются не сразу после роли, а в конце play — после роли `app`. По умолчанию, если на узле позже упала любая задача, уже уведомлённые handlers на этом узле **не выполняются**. Это опасно: файл конфигурации изменён, а служба не перезапущена. При следующем запуске файл уже совпадает с шаблоном, задача возвращает `ok`, и handler больше никогда не будет вызван. Например, `sshd` продолжит принимать пароли, хотя `sshd -T` показывает `passwordauthentication no`, а Nginx — отдавать страницу по умолчанию. Поэтому в `ansible.cfg` включается `force_handlers = True`: уведомлённые handlers выполняются и при отказе последующих задач.

### 2.4 Идемпотентность

Идемпотентный плейбук приводит узел к описанному состоянию, но не выполняет повторно необратимые или ненужные операции. После первого успешного запуска второй должен завершиться с `changed=0`.

Это не означает «ничего не проверять»: Ansible заново собирает факты и сравнивает фактическое состояние с желаемым. Если вручную удалить контейнер или изменить конфигурацию Nginx, следующий запуск обнаружит различие и устранит его.

Команды `docker run`, `sed`, `systemctl restart`, безусловно вызываемые в каждой задаче, идемпотентности не дают. Поэтому в работе применяются специализированные модули, а не сценарий из последовательных shell-команд.

### 2.5 Деплой по SHA и поведение при ошибке

Переменная `app_tag` содержит полный SHA коммита, для которого CI опубликовал образ. Это связывает конфигурацию сервера с проверенным исходником.

Задача загрузки образа предшествует изменению контейнера. Если задан несуществующий тег, `docker_image` завершится ошибкой до задачи `docker_container`. Уже работающий контейнер прежней версии при этом не удаляется. Плейбук красный, но сервис остаётся доступным.

Это не является универсальной гарантией zero-downtime для любой ошибки: сбой после пересоздания контейнера потребовал бы более сложной стратегии. В выбранном инциденте отказ намеренно происходит на ранней стадии загрузки.

### 2.6 Проверка результата

Проверки расположены на нескольких уровнях:

1. модули подтверждают состояние пакетов, файлов, служб и контейнера;
2. `uri` на VM проверяет непосредственный HTTP-ответ приложения;
3. `curl` с управляющего узла проверяет цепочку «клиент → Nginx → контейнер»;
4. повторный запуск подтверждает идемпотентность;
5. drift-тест доказывает способность восстановления, а не только первичной установки.

---

## 3 Подготовка к занятию

### 3.1 Подготовка управляющего узла до занятия

Установка выполняется заранее и не входит в 90 минут аудиторной работы.

**Ubuntu / WSL:**

```bash
sudo apt update
sudo apt install -y ansible
ansible --version
```

Ожидается Ansible с `ansible-core` версии 2.16 или новее. В Windows используется ранее настроенная WSL, а не Git Bash или PowerShell.

Установите `sshpass`, необходимый для первичного запуска по паролю:

```bash
sudo apt install -y sshpass
sshpass -V
```

**WSL.** Репозиторий должен находиться в файловой системе WSL (например, `~/devops-course-2026`), а не на диске Windows (`/mnt/c/...`). Каталоги на `/mnt/c` видны как доступные для записи всем, и Ansible в таком каталоге игнорирует `ansible.cfg` с предупреждением `Ansible is being run in a world writable directory`; inventory `prod.ini` при этом не подключается. Ключ `~/.ssh/devops_vm` также должен лежать в домашнем каталоге WSL с правами `0600`.

**macOS:**

```bash
brew install ansible
brew install hudochenkov/sshpass/sshpass
ansible --version
sshpass -V
```

В основном репозитории Homebrew формулы `sshpass` нет, поэтому используется сторонний tap. Если установить `sshpass` невозможно, используйте вариант bootstrap по ключу из шага 1.3.

Создайте проект в репозитории `devops-course-2026` и установите коллекции после появления `requirements.yml` из задания 1. Если преподаватель раздаёт готовый шаблон проекта, установку коллекций также выполните до занятия:

```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

Проверьте наличие ключа из практической работы № 5:

```bash
ls -l ~/.ssh/devops_vm ~/.ssh/devops_vm.pub
ssh-keygen -y -P "" -f ~/.ssh/devops_vm >/dev/null && echo "no passphrase" || echo "passphrase set"
```

Если на ключе установлена парольная фраза, неинтерактивный запуск будет её запрашивать. Для занятия загрузите ключ в агент (`eval "$(ssh-agent -s)"`, затем `ssh-add ~/.ssh/devops_vm`). Для контрольной работы № 3 потребуется отдельный ключ деплоя без парольной фразы, который хранится только в GitHub Secrets.

Закрытый ключ не копируется в репозиторий и не передаётся другим студентам.

### 3.2 Возврат VM к чистому состоянию

1. Сохраните необходимые данные предыдущих работ в репозитории. Состояние VM будет потеряно.
2. Выключите VM и восстановите снимок `01-clean-install`.
3. Запустите VM, войдите в консоль как `student` и определите Host-only адрес:

```bash
ip -brief address
```

4. С управляющего узла проверьте подключение по паролю и подтвердите ключ хоста по известной процедуре:

```bash
ssh student@192.168.56.101
```

Замените адрес на фактический. Порт 22, NAT-проброс и прежний псевдоним `devops` не используются: после отката VM прежней конфигурации SSH нет.

### 3.3 Проверка готовности

Таблица 1. Условия готовности

| Номер | Условие | Подтверждение |
|---|---|---|
| 1 | VM восстановлена к чистому снимку | Менеджер снимков VirtualBox |
| 2 | Host-only адрес известен, SSH на порту 22 доступен | `ssh student@<IP>` |
| 3 | Ansible и `sshpass` установлены на управляющем узле | `ansible --version`, `sshpass -V` |
| 4 | Открытый и закрытый ключи `devops_vm` сохранены; известно, есть ли парольная фраза | `ls -l ~/.ssh/devops_vm*`, `ssh-keygen -y -P ""` |
| 5 | В WSL репозиторий находится вне `/mnt/c` | `pwd` |
| 6 | GHCR-пакет из ПР № 10 доступен для чтения | Страница пакета и успешный pull из самостоятельной работы № 10 |
| 7 | Выбран полный SHA успешно опубликованного образа | Packages → теги |

---

## 4 Порядок выполнения аудиторной части

Таблица 2. Регламент занятия

| Этап | Содержание | Время, мин |
|---|---|---|
| 1 | Проверка готовности | 5 |
| 2 | Задание 1. Проект, inventory и переменные | 10 |
| 3 | Задание 2. Роли `base` и `ssh` | 20 |
| 4 | Задание 3. Роли `nginx` и `app` | 20 |
| 5 | Задание 4. Bootstrap, деплой и идемпотентность | 15 |
| 6 | Задание 5. Drift и неудачная смена версии | 10 |
| 7 | Итоговый контроль, резерв | 10 |
| | Итого | 90 |

Команды, помеченные `[Control]`, выполняются на управляющем узле; `[VM]` — в SSH-сессии или консоли VM.

### 4.1 Задание 1. Проект, inventory и переменные

**Шаг 1.1.** `[Control]` Перейдите в репозиторий и создайте ветку:

```bash
cd devops-course-2026
git switch main
git pull
git switch -c feature/ansible
mkdir -p ansible/{inventory,group_vars}
mkdir -p ansible/roles/{base,ssh,nginx,app}/tasks
mkdir -p ansible/roles/{ssh,nginx}/handlers
mkdir -p ansible/roles/nginx/templates
```

Создайте `ansible/requirements.yml`:

```yaml
---
collections:
  - name: ansible.posix
    version: "1.6.2"
  - name: community.docker
    version: "4.5.0"
  - name: community.general
    version: "9.5.0"
```

Версии совместимы с ansible-core 2.16. При установке `community.docker` зависимость `community.library_inventory_filtering_v1` может быть установлена автоматически; отдельно описывать её не требуется.

Если коллекции ещё не установлены, выполните:

```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

**Шаг 1.2.** Создайте `ansible/ansible.cfg`:

```ini
[defaults]
inventory = inventory/prod.ini
retry_files_enabled = False
host_key_checking = True
timeout = 15
force_handlers = True

[ssh_connection]
pipelining = True
```

Файл рассчитан на запуск из каталога `ansible/`. Не переносите `ansible.cfg` в домашний каталог. Параметр `force_handlers = True` гарантирует, что уведомлённые handlers SSH и Nginx выполнятся даже при отказе более поздней задачи (см. подраздел 2.3).

**Шаг 1.3.** Создайте `ansible/inventory/bootstrap.ini`, подставив фактический IP:

```ini
[vm]
devops-vm ansible_host=192.168.56.101 ansible_port=22 ansible_user=student
```

Создайте `ansible/inventory/prod.ini` с тем же IP:

```ini
[vm]
devops-vm ansible_host=192.168.56.101 ansible_port=22 ansible_user=devops ansible_private_key_file=~/.ssh/devops_vm
```

**Вариант bootstrap без `sshpass`.** Если `sshpass` установить невозможно, заранее скопируйте открытый ключ пользователю `student` и подключайтесь при первичном запуске по ключу:

```bash
ssh-copy-id -i ~/.ssh/devops_vm.pub student@192.168.56.101
```

В `bootstrap.ini` добавьте к строке узла `ansible_private_key_file=~/.ssh/devops_vm`, а в шаге 4.3 запускайте плейбук без `--ask-pass`, только с `--ask-become-pass`. Остальной ход работы не меняется.

**Шаг 1.4.** Создайте `ansible/group_vars/all.yml`:

```yaml
---
app_image: "ghcr.io/<login>/devops-ci-app"
app_tag: "<полный-SHA-зелёного-коммита-из-ПР-10>"
app_container_name: "devops-ci-app"
app_host_port: 5000
app_internal_port: 5000
```

Имя владельца GHCR указывается строчными буквами. Тег `latest` не используется. Проверьте, что выбранный SHA действительно присутствует на странице пакета.

**Шаг 1.5.** Создайте `ansible/site.yml`:

```yaml
---
- name: Configure and deploy devops VM
  hosts: vm
  become: true

  roles:
    - base
    - ssh
    - nginx
    - app
```

Порядок важен: Docker и базовые зависимости появляются до контейнера, пользователь и SSH-ключ — до отключения парольной аутентификации, reverse proxy — до финальной внешней проверки.

**В отчёт:** дерево проекта, два inventory без паролей, переменная `app_tag` и объяснение перехода bootstrap → prod.

### 4.2 Задание 2. Роли `base` и `ssh`

#### 4.2.1 Роль `base`

Создайте `ansible/roles/base/tasks/main.yml`:

```yaml
---
- name: Assert supported VM platform
  ansible.builtin.assert:
    that:
      - ansible_distribution == "Ubuntu"
      - ansible_distribution_version is version("24.04", "==")
      - ansible_architecture == "x86_64"
    fail_msg: "Требуется Ubuntu Server 24.04 amd64"

- name: Install base packages and remote module dependencies
  ansible.builtin.apt:
    name:
      - ca-certificates
      - curl
      - gnupg
      - openssh-server
      - ufw
      - python3-debian
      - python3-requests
    state: present
    update_cache: true
    cache_valid_time: 3600

- name: Add Docker official repository
  ansible.builtin.deb822_repository:
    name: docker
    types: [deb]
    uris: https://download.docker.com/linux/ubuntu
    suites: "{{ ansible_distribution_release }}"
    components: [stable]
    architectures: [amd64]
    signed_by: https://download.docker.com/linux/ubuntu/gpg
    state: present

- name: Install Docker Engine
  ansible.builtin.apt:
    name:
      - docker-ce
      - docker-ce-cli
      - containerd.io
      - docker-buildx-plugin
      - docker-compose-plugin
    state: present
    update_cache: true

- name: Enable Docker service
  ansible.builtin.service:
    name: docker
    state: started
    enabled: true
```

`python3-debian` необходим модулю `deb822_repository`, `python3-requests` — модулям `community.docker` на VM для обращения к Docker API. Docker SDK for Python (`python3-docker`) этим модулям не нужен. Пакет `docker.io` не используется.

#### 4.2.2 Роль `ssh`

Создайте `ansible/roles/ssh/tasks/main.yml`:

```yaml
---
- name: Create automation user
  ansible.builtin.user:
    name: devops
    shell: /bin/bash
    groups: sudo
    append: true
    create_home: true

- name: Create SSH directory
  ansible.builtin.file:
    path: /home/devops/.ssh
    state: directory
    owner: devops
    group: devops
    mode: "0700"

- name: Install automation public key
  ansible.posix.authorized_key:
    user: devops
    state: present
    key: "{{ lookup('file', lookup('env', 'HOME') + '/.ssh/devops_vm.pub') }}"
    manage_dir: false

- name: Allow non-interactive automation sudo
  ansible.builtin.copy:
    content: "devops ALL=(ALL) NOPASSWD:ALL\n"
    dest: /etc/sudoers.d/devops
    owner: root
    group: root
    mode: "0440"
    validate: "visudo -cf %s"

- name: Harden SSH only after key installation
  ansible.builtin.copy:
    content: |
      PermitRootLogin no
      PasswordAuthentication no
      PubkeyAuthentication yes
      PermitEmptyPasswords no
      AllowUsers student devops
      X11Forwarding no
    dest: /etc/ssh/sshd_config.d/00-ansible-hardening.conf
    owner: root
    group: root
    mode: "0644"
    validate: "sshd -t -f %s"
  notify: Restart SSH

- name: Allow management and web ports
  community.general.ufw:
    rule: allow
    port: "{{ item }}"
    proto: tcp
  loop:
    - "22"
    - "80"

- name: Set incoming firewall policy
  community.general.ufw:
    default: deny
    direction: incoming

- name: Set outgoing firewall policy
  community.general.ufw:
    default: allow
    direction: outgoing

- name: Enable firewall
  community.general.ufw:
    state: enabled
    logging: low
```

Lookup `file` читает открытый ключ на управляющем узле. Файл `00-ansible-hardening.conf` обрабатывается раньше возможного `50-cloud-init.conf`, поэтому ранее встреченное `PasswordAuthentication yes` не победит.

Создайте `ansible/roles/ssh/handlers/main.yml`:

```yaml
---
- name: Restart SSH
  ansible.builtin.service:
    name: ssh
    state: restarted
```

**Контроль безопасности.** Не меняйте порядок задач: сначала пользователь, каталог и ключ, затем sudo и отключение паролей. Не добавляйте в эту работу `AllowUsers devops` без `student`: при ошибке до завершения плейбука консоль VM останется резервным доступом, а первичная SSH-сессия `student` не должна искусственно усложнять восстановление.

**В отчёт:** объяснение назначения `python3-requests`, `validate` для sudo/sshd и причина выбора префикса `00-`.

### 4.3 Задание 3. Роли `nginx` и `app`

#### 4.3.1 Роль `nginx`

Создайте `ansible/roles/nginx/templates/devops-ci-app.conf.j2`:

```nginx
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:{{ app_host_port }};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Создайте `ansible/roles/nginx/tasks/main.yml`:

```yaml
---
- name: Install Nginx
  ansible.builtin.apt:
    name: nginx
    state: present
    update_cache: true
    cache_valid_time: 3600

- name: Configure application reverse proxy
  ansible.builtin.template:
    src: devops-ci-app.conf.j2
    dest: /etc/nginx/sites-available/devops-ci-app
    owner: root
    group: root
    mode: "0644"
  notify: Reload Nginx

- name: Disable default site
  ansible.builtin.file:
    path: /etc/nginx/sites-enabled/default
    state: absent
  notify: Reload Nginx

- name: Enable application site
  ansible.builtin.file:
    src: /etc/nginx/sites-available/devops-ci-app
    dest: /etc/nginx/sites-enabled/devops-ci-app
    state: link
  notify: Reload Nginx

- name: Enable Nginx service
  ansible.builtin.service:
    name: nginx
    state: started
    enabled: true
```

Создайте `ansible/roles/nginx/handlers/main.yml` с двумя handlers под общим событием:

```yaml
---
- name: Validate Nginx before reload
  ansible.builtin.command: nginx -t
  changed_when: false
  listen: Reload Nginx

- name: Reload Nginx
  ansible.builtin.service:
    name: nginx
    state: reloaded
  listen: Reload Nginx
```

При изменении шаблона сначала выполняется `nginx -t`; reload запускается только после успешной проверки. В применённом handler `changed_when: false` нужен, потому что сама проверка конфигурации не меняет систему. Оба handlers выполняются в конце play, после роли `app`; это не мешает health-check, поскольку он обращается к контейнеру напрямую, минуя Nginx.

#### 4.3.2 Роль `app`

Создайте `ansible/roles/app/tasks/main.yml`:

```yaml
---
- name: Allow devops to inspect Docker
  ansible.builtin.user:
    name: devops
    groups: docker
    append: true

- name: Pull reviewed application image
  community.docker.docker_image:
    name: "{{ app_image }}"
    tag: "{{ app_tag }}"
    source: pull
    state: present

- name: Run application container
  community.docker.docker_container:
    name: "{{ app_container_name }}"
    image: "{{ app_image }}:{{ app_tag }}"
    state: started
    restart_policy: unless-stopped
    published_ports:
      - "127.0.0.1:{{ app_host_port }}:{{ app_internal_port }}"

- name: Wait for application health
  ansible.builtin.uri:
    url: "http://127.0.0.1:{{ app_host_port }}/health"
    return_content: true
  register: app_health
  retries: 15
  delay: 2
  until: >
    (app_health.status | default(-1)) == 200 and
    (app_health.json | default({})).get("status") == "ok"
```

`docker_image` не использует `force_source`: при неизменном SHA повторный запуск не загружает образ заново. `docker_container` сравнивает существующий контейнер с желаемой конфигурацией и пересоздаёт его только при расхождении.

Публикация на `127.0.0.1` исключает прямой обход Nginx. Порт 80 разрешён UFW, порт 5000 наружу не опубликован.

**Docker и UFW.** Опубликованные порты Docker открывает собственными правилами `iptables`, которые обрабатываются раньше правил UFW. Если опубликовать порт как `5000:5000` (на всех интерфейсах), он будет доступен извне, несмотря на политику `deny incoming` в UFW. Поэтому защита от обхода Nginx обеспечивается именно привязкой к `127.0.0.1`, а не межсетевым экраном.

**В отчёт:** шаблон reverse proxy, назначение двух Nginx handlers, объяснение `published_ports` и `until` health-проверки.

### 4.4 Задание 4. Bootstrap, деплой и идемпотентность

**Шаг 4.1.** `[Control]` Перед первым запуском проверьте синтаксис и inventory:

```bash
cd ansible
ansible-inventory -i inventory/bootstrap.ini --graph
ansible-inventory --graph
ansible-playbook -i inventory/bootstrap.ini site.yml --syntax-check
ansible-playbook site.yml --syntax-check
```

Имя плейбука обязательно: команда `ansible-playbook --syntax-check` без него завершается ошибкой `the following arguments are required: playbook`. Вторая пара команд не указывает `-i` и поэтому проверяет, что `ansible.cfg` действительно подключился и выбрал `prod.ini`.

Ошибки пути, YAML и неизвестные модули устраняются до обращения к VM.

**Шаг 4.2.** Зафиксируйте проект до запуска:

```bash
cd ..
git add ansible
git commit -m "feat: automate vm configuration with ansible roles"
git push -u origin feature/ansible
cd ansible
```

**Шаг 4.3.** Выполните первичный запуск:

```bash
ansible-playbook -i inventory/bootstrap.ini site.yml --ask-pass --ask-become-pass
```

Введите пароль `student` на оба запроса. Первый запуск устанавливает пакеты и может занять несколько минут. Не прерывайте его после начала изменения SSH.

Ожидаемый результат: `failed=0`, приложение прошло health-check, handlers SSH/Nginx выполнились в конце play и только после соответствующих изменений.

**Если первичный запуск завершился ошибкой.** Найдите и исправьте причину (частые — опечатка в SHA, заглавные буквы в имени владельца образа, приватный GHCR-пакет). Затем определите, каким inventory повторять запуск:

```bash
ssh -i ~/.ssh/devops_vm -o BatchMode=yes devops@192.168.56.101 "sudo -n true" && echo "use prod" || echo "use bootstrap"
```

Если роль `ssh` успела выполниться, благодаря `force_handlers` SSH уже перезапущен и парольный вход отключён: повторяйте через `ansible-playbook site.yml` (prod). Если отказ произошёл раньше, например в роли `base`, повторите команду bootstrap.

**Шаг 4.4.** Проверьте переход на ключ и неинтерактивный доступ:

```bash
ssh -i ~/.ssh/devops_vm devops@192.168.56.101 "whoami && sudo -n true && echo sudo-ok"
ansible all -m ping
```

Ожидаются `devops`, `sudo-ok` и `pong`. Пароль не запрашивается. Отдельно проверьте, что прежний парольный вход больше не предлагается:

```bash
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no student@192.168.56.101
```

Ожидается `Permission denied (publickey)`. Не восстанавливайте парольную аутентификацию.

**Шаг 4.5.** `[Control]` Проверьте внешнюю цепочку:

```bash
curl --fail http://192.168.56.101/health
curl --fail http://192.168.56.101/
```

Ожидаются `status=ok` и сведения о службе. На VM дополнительно проверьте:

```bash
ssh -i ~/.ssh/devops_vm devops@192.168.56.101
sudo ss -tlnp | grep -E ':(22|80|5000)\b'
docker ps
sudo ufw status verbose
```

Порт 5000 должен быть привязан к `127.0.0.1`, порты 22 и 80 доступны по правилам UFW.

**Шаг 4.6.** Немедленно выполните повторный запуск через prod inventory:

```bash
# выйдите из SSH-сессии VM, если ещё находитесь в ней
ansible-playbook site.yml
```

Зафиксируйте итоговую строку. Ожидается `changed=0`, `failed=0`; restart SSH и reload Nginx не вызываются. Если `changed` больше нуля, по журналу определите задачу и объясните, почему она считает состояние изменённым; не игнорируйте это отклонение.

**В отчёт:** итоги первого и второго запусков, переход на ключ, HTTP-ответы, порты/UFW и доказательство `changed=0`.

### 4.5 Задание 5. Drift и неудачная смена версии

#### 4.5.1 Инцидент 1: ручной drift вывел сайт из строя

**Шаг 5.1.** `[VM]` Имитируйте ручное вмешательство администратора:

```bash
docker rm -f devops-ci-app
sudo sed -i 's/127.0.0.1:5000/127.0.0.1:5001/' /etc/nginx/sites-available/devops-ci-app
sudo nginx -t && sudo systemctl reload nginx
```

`[Control]` Проверьте:

```bash
curl -i http://192.168.56.101/health
```

Ожидается `502 Bad Gateway`: контейнер удалён, а Nginx дополнительно указывает на неверный порт.

**Шаг 5.2.** Не исправляйте VM вручную. Запустите:

```bash
ansible-playbook site.yml
curl --fail http://192.168.56.101/health
```

Плейбук должен восстановить шаблон Nginx и пересоздать контейнер. В журнале найдите, какие задачи получили `changed`, какой handler перезагрузил Nginx и почему health-check выполнился только после запуска контейнера.

#### 4.5.2 Инцидент 2: новая версия недоступна

**Шаг 5.3.** `[Control]` В `group_vars/all.yml` временно замените `app_tag` на заведомо несуществующее значение:

```yaml
app_tag: "0000000000000000000000000000000000000000"
```

Запустите `ansible-playbook site.yml`. Ожидается отказ задачи **Pull reviewed application image** с ошибкой загрузки манифеста/тега. Задача **Run application container** не выполняется.

Сразу проверьте текущий сервис:

```bash
curl --fail http://192.168.56.101/health
ssh -i ~/.ssh/devops_vm devops@192.168.56.101 "docker ps --filter name=devops-ci-app"
```

Ожидается работающий прежний контейнер. Красный плейбук не означает автоматическое падение сервиса: отказ произошёл до изменения контейнера.

**Шаг 5.4.** Восстановите файл из Git и повторите запуск:

```bash
git restore group_vars/all.yml
ansible-playbook site.yml
curl --fail http://192.168.56.101/health
```

Ожидается возврат к зафиксированному SHA и `changed=0`. В журнале первого отказа найдите точное имя образа и тег, чтобы в разборе не ограничиваться общей фразой «образ не скачался».

**В отчёт:** симптом 502, задачи восстановления drift, ошибка несуществующего тега, доказательство сохранения прежнего контейнера и итоговый зелёный запуск.

---

## 5 Задание для самостоятельной работы

### 5.1 Автоматический аудит результата

Создайте `ansible/verify.yml`, который использует тот же `prod.ini` и не меняет конфигурацию:

```yaml
---
- name: Verify deployed configuration
  hosts: vm
  become: true
  gather_facts: true

  tasks:
    - name: Check SSH effective configuration
      ansible.builtin.command: sshd -T
      register: sshd_effective
      changed_when: false

    - name: Assert password authentication is disabled
      ansible.builtin.assert:
        that:
          - "'passwordauthentication no' in sshd_effective.stdout"
          - "'permitrootlogin no' in sshd_effective.stdout"

    - name: Read container facts
      community.docker.docker_container_info:
        name: "{{ app_container_name }}"
      register: container_info

    - name: Assert container is running
      ansible.builtin.assert:
        that:
          - container_info.container.State.Running

    - name: Check direct application health
      ansible.builtin.uri:
        url: "http://127.0.0.1:{{ app_host_port }}/health"
      register: direct_health

    - name: Assert health payload
      ansible.builtin.assert:
        that:
          - direct_health.status == 200
          - direct_health.json.status == "ok"
```

Запустите `ansible-playbook verify.yml` дважды. В обоих запусках ожидается `changed=0`. Затем временно остановите контейнер вручную, убедитесь, что аудит падает, и восстановите состояние основным `site.yml`.

Объясните, почему отдельный read-only плейбук удобен для проверки из CI и почему `command: sshd -T` снабжён `changed_when: false`.

### 5.2 Обновление документации сервера

Дополните `docs/server-setup.md` разделом:

```markdown
## 10. Ansible

(расположение проекта; управляющий и управляемый узлы; inventory;
учётные записи bootstrap и prod; роли и их ответственность;
адрес образа GHCR; полный SHA; порт контейнера; health endpoint;
команды первичного и повторного запусков; команда read-only аудита)
```

Пароли и закрытый ключ в документ не включаются. После обновления оформите PR из `feature/ansible` в `main`, приложите ссылку и выполните merge после проверки.

---

## 6 Факультативное задание. Параллельный деплой двух версий

Задание выполняется при наличии времени и на оценку не влияет.

Разверните второй контейнер из другого зелёного SHA на `127.0.0.1:5001`, не изменяя основной. Проверьте оба `/health`, сравните `docker inspect` и образы. Затем удалите только дополнительный контейнер.

Ответьте:

1. какую роль играет имя контейнера при идемпотентном управлении;
2. почему два контейнера не могут публиковать один и тот же `host_ip:host_port`;
3. как blue-green deployment использует два параллельных окружения и переключение reverse proxy;
4. какие дополнительные проверки нужны перед переключением Nginx на новый порт.

Не превращайте основной плейбук в безусловный запуск двух контейнеров: это отдельный эксперимент.

---

## 7 Быстрая диагностика типовых затруднений

Таблица 3. Диагностический минимум

| Симптом | Вероятная причина | Первичная проверка |
|---|---|---|
| Bootstrap не подключается | Неверный IP, VM не чистая, SSH не на 22 | `ip -brief address`, `ssh student@<IP>` |
| `you must install the sshpass program` | На управляющем узле нет `sshpass` | `sshpass -V`; установка или вариант bootstrap по ключу |
| `ansible all -m ping` не находит узлы, предупреждение `world writable directory` | Проект на `/mnt/c`, `ansible.cfg` проигнорирован | `pwd`; перенос репозитория в домашний каталог WSL |
| Запуск по ключу запрашивает парольную фразу | Ключ `devops_vm` защищён фразой | `ssh-add ~/.ssh/devops_vm` |
| Конфигурация изменена, но служба работает по-старому, повторный запуск даёт `ok` | Handler не выполнился из-за отказа поздней задачи | `force_handlers = True` в `ansible.cfg`; разовое `systemctl restart`/`reload` и повторный запуск |
| После bootstrap нет доступа `devops` | Неверный путь к public key или права | `/home/devops/.ssh/authorized_keys`, `~/.ssh/devops_vm` |
| `sudo` запрашивает пароль в prod | Не применён sudoers | `/etc/sudoers.d/devops`, `sudo -n true` |
| Модуль Docker не найден | Коллекция не установлена на control | `ansible-galaxy collection list` |
| Docker-модуль сообщает об отсутствии `requests` | На VM нет `python3-requests` | Роль base и `python3 -c 'import requests'` на VM |
| `deb822_repository` падает | Нет `python3-debian` или старый ansible-core | Пакет на VM, `ansible --version` |
| Повторный запуск меняет SSH/Nginx | Нестабильный шаблон или ручной drift | `diff`, журнал changed tasks |
| `docker_container` создаёт новый контейнер каждый раз | Изменяется image/ports или имя | `docker inspect`, переменные |
| Health-check не проходит | Контейнер упал или неверный порт | `docker ps`, `docker logs`, `ss -tlnp` |
| Наружу доступен порт 5000 | Публикация не на loopback | Значение `published_ports` |
| Несуществующий SHA дал 404 | Тег не опубликован в GHCR | Packages, полный SHA, нижний регистр owner |
| После failed pull прежний сайт работает | Отказ был до container task | Порядок задач и `docker ps` |

---

## 8 Подготовка к контрольной работе № 3

а) убедиться, что `ansible-playbook site.yml` работает неинтерактивно и даёт `changed=0` при отсутствии drift;

б) определить, откуда workflow будет подключаться к VM. Адрес Host-only (`192.168.56.x`) доступен только с хостовой системы студента; GitHub-hosted runner работает в облаке и до него не дойдёт. Варианты: GitHub-hosted runner с сетевым туннелем к VM (например, Tailscale), VM в облаке или self-hosted runner на хостовой системе. GitHub рекомендует использовать self-hosted runner только с **приватными** репозиториями: в Pull Request из форка можно изменить сам workflow и выполнить произвольный код на компьютере студента, поэтому ограничения триггеров в собственном `ci.yml` недостаточно. При выборе self-hosted runner репозиторий для КР № 3 делается приватным (тогда GHCR-пакет требует аутентификации чтения) либо в **Settings → Actions → General** включается обязательное одобрение запусков для всех внешних участников;

в) подготовить GitHub Secrets для SSH: отдельный ключ деплоя без парольной фразы, известный ключ хоста, адрес VM; понимать, что Secrets не следует выводить в журнал;

г) изучить `workflow_dispatch` и условие запуска деплоя только из `main`;

д) определить, как SHA из CI будет передаваться в `app_tag` без ручного редактирования `group_vars/all.yml`;

е) повторить различие CI-артефакта, Docker-образа и результата развёртывания на VM;

ж) подготовить ответ, как безопасно проверить новый SSH-ключ хоста и почему безусловное `StrictHostKeyChecking=no` нежелательно.

---

## 9 Контрольные вопросы

1. Почему для Ansible на VM не нужен постоянный агент? Где выполняются модули?
2. Чем различаются `bootstrap.ini` и `prod.ini`? Почему первый запуск интерактивный, а последующие нет?
3. Почему установка открытого ключа предшествует отключению парольной аутентификации?
4. Какие риски даёт `NOPASSWD:ALL` и почему в учебной работе он используется осознанно?
5. Чем handler отличается от обычной задачи? Почему Nginx проверяется перед reload?
6. Что означает `changed=0` и почему это не то же самое, что «плейбук не выполнялся»?
7. Почему специализированные модули предпочтительнее безусловных `command: docker run` и `command: systemctl restart`?
8. Почему `python3-requests` устанавливается на VM, а коллекции — на управляющем узле? Почему Docker SDK for Python модулям `community.docker` не нужен?
9. Почему приложение разворачивается по SHA, а не по `latest`?
10. Почему отсутствие нового тега не удалило работающий контейнер? При каком другом порядке задач результат мог бы быть хуже?
11. Какие изменения были обнаружены при drift и какие задачи их устранили?
12. Почему порт 5000 публикуется на `127.0.0.1`, а в UFW открыт только 80 в дополнение к SSH?
13. Что проверяет `uri` на VM и что дополнительно доказывает `curl` с управляющего узла?
14. Почему read-only аудит должен сам давать `changed=0`?
15. Какие элементы текущего плейбука потребуют секретов или дополнительной защиты при запуске из GitHub Actions?
16. Когда выполняются handlers и что произойдёт с изменённым `sshd`-конфигом, если после его записи упадёт задача роли `app`? Как это предотвращает `force_handlers = True`?
17. Почему GitHub-hosted runner не может подключиться к VM по адресу Host-only и какие варианты решения существуют для контрольной работы № 3?
18. Почему Docker-порт, опубликованный на всех интерфейсах, доступен извне даже при политике UFW `deny incoming`?

---

## 10 Требования к содержанию и оформлению отчёта

Отчёт оформляется в формате Microsoft Word (.docx) и содержит титульный лист, цель и задачи работы, схему управляющего и управляемого узлов, структуру проекта Ansible, материалы из блоков «В отчёт», ссылку на репозиторий и PR, разборы двух инцидентов, результаты самостоятельного аудита и выводы.

Скриншоты первого и повторного запусков должны включать итоговые строки `ok/changed/failed`. Пароли, закрытые ключи и содержимое секретных файлов в отчёт не включаются.

Таблица 4. Условия, проверяемые перед сдачей

| Номер | Условие | Подтверждение |
|---|---|---|
| 1 | Существуют роли `base`, `ssh`, `nginx`, `app` | Дерево `ansible/roles` |
| 2 | Bootstrap выполнен от `student`, prod работает по ключу | Два запуска, `whoami`, `sudo -n true` |
| 3 | Парольная аутентификация отключена после установки ключа | `sshd -T`, отказ password-only SSH |
| 4 | Docker установлен из официального репозитория | `deb822_repository`, `docker --version` |
| 5 | Nginx настроен reverse proxy, default site отключён | Шаблон, symlink, внешний curl |
| 6 | Приложение развёрнуто по полному SHA из GHCR | `group_vars`, `docker inspect` |
| 7 | Порт 5000 доступен только на loopback | `ss -tlnp`, `published_ports` |
| 8 | Повторный `site.yml` даёт `changed=0`, `failed=0` | Итоговая строка запуска |
| 9 | Drift воспроизведён и устранён только плейбуком | 502 → зелёный запуск → 200 |
| 10 | Несуществующий тег дал failed pull без остановки прежнего сервиса | Журнал pull и одновременный health 200 |
| 11 | `verify.yml` не меняет состояние и обнаруживает остановленный контейнер | Два запуска и negative test |
| 12 | В репозитории нет закрытого ключа и паролей | `git status`, проверка файлов |
| 13 | `ansible.cfg` содержит `force_handlers = True`, на VM установлен `python3-requests` | `ansible.cfg`, роль `base` |

Итоговая защита: студент должен без новых ручных исправлений на VM восстановить заранее внесённый drift одним плейбуком и объяснить, почему второй запуск идемпотентен.

---

## Список использованных источников

1. Ansible. Getting Started [Электронный ресурс]. URL: https://docs.ansible.com/projects/ansible/latest/getting_started/ (дата обращения: 04.11.2026).
2. Ansible. Using inventory [Электронный ресурс]. URL: https://docs.ansible.com/projects/ansible/latest/inventory_guide/intro_inventory.html (дата обращения: 04.11.2026).
3. Ansible. Playbook keywords: roles и handlers [Электронный ресурс]. URL: https://docs.ansible.com/projects/ansible/latest/playbook_guide/ (дата обращения: 04.11.2026).
4. ansible.builtin.deb822_repository module [Электронный ресурс]. URL: https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/deb822_repository_module.html (дата обращения: 04.11.2026).
5. ansible.posix.authorized_key module [Электронный ресурс]. URL: https://docs.ansible.com/projects/ansible/latest/collections/ansible/posix/authorized_key_module.html (дата обращения: 04.11.2026).
6. community.general.ufw module [Электронный ресурс]. URL: https://docs.ansible.com/projects/ansible/latest/collections/community/general/ufw_module.html (дата обращения: 04.11.2026).
7. community.docker.docker_image module [Электронный ресурс]. URL: https://docs.ansible.com/projects/ansible/latest/collections/community/docker/docker_image_module.html (дата обращения: 04.11.2026).
8. community.docker.docker_container module [Электронный ресурс]. URL: https://docs.ansible.com/projects/ansible/latest/collections/community/docker/docker_container_module.html (дата обращения: 04.11.2026).
9. Install Docker Engine on Ubuntu [Электронный ресурс] // Docker Docs. URL: https://docs.docker.com/engine/install/ubuntu/ (дата обращения: 04.11.2026).
10. Nginx. Module ngx_http_proxy_module [Электронный ресурс]. URL: https://nginx.org/ru/docs/http/ngx_http_proxy_module.html (дата обращения: 04.11.2026).
11. Ansible. Error handling in playbooks: handlers and failure [Электронный ресурс]. URL: https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_error_handling.html (дата обращения: 04.11.2026).
12. Connection methods and details: passwords and sshpass [Электронный ресурс] // Ansible Docs. URL: https://docs.ansible.com/projects/ansible/latest/inventory_guide/connection_details.html (дата обращения: 04.11.2026).
13. Docker. Packet filtering and firewalls [Электронный ресурс] // Docker Docs. URL: https://docs.docker.com/engine/network/packet-filtering-firewalls/ (дата обращения: 04.11.2026).
14. Secure use reference: hardening for self-hosted runners [Электронный ресурс] // GitHub Docs. URL: https://docs.github.com/en/actions/reference/security/secure-use (дата обращения: 04.11.2026).
