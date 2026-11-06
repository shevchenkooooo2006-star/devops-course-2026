| | |
|---|---|
| **ДИСЦИПЛИНА** | Инструменты девопс |
| **ИНСТИТУТ** | ИРИП |
| **КАФЕДРА** | Индустриального программирования |
| **ВИД УЧЕБНОГО МАТЕРИАЛА** | Методические указания к практическим занятиям |
| **ПРЕПОДАВАТЕЛЬ** | Гиматдинов Дамир Маратович |
| **СЕМЕСТР** | 5 семестр, 2026/2027 учебный год |

Ссылка на материал:
https://gitverse.ru/dgimatdinov/DevOps_2026/content/master/DEV_10.md

---

# ПРАКТИЧЕСКАЯ РАБОТА № 10

**Тема: Непрерывная интеграция и публикация образа. GitHub Actions, pytest, Docker, GHCR**

| | |
|---|---|
| **Дисциплина** | DevOps-практикум |
| **Курс** | 3 |
| **Занятие** | 10 из 16 |
| **Блок** | Автоматизация конфигураций и CI/CD (занятие 2 из 4) |
| **Форма работы** | Индивидуальная |
| **Продолжительность аудиторной части** | До 90 минут |

Работа выполняется в новом публичном репозитории GitHub. Виртуальная машина и локальные Python/Docker для аудиторной части не требуются: проверки, сборка и запуск контейнера выполняются на GitHub-hosted runner. Образ публикуется в GitHub Container Registry (GHCR) с использованием автоматического `GITHUB_TOKEN`, поэтому учётная запись Docker Hub и персональные токены не нужны.

---

## 1 Цель и задачи работы

Цель работы — сформировать практические навыки построения последовательного CI-конвейера, который останавливается при дефекте и публикует Docker-образ только после успешных проверок.

Задачи:

а) реализовать последовательность «статический анализ → модульные тесты → сборка образа → smoke-test → публикация»;

б) настроить зависимости заданий через `needs` и исключить выполнение последующих этапов после отказа;

в) проверять Pull Request без публикации образа и публиковать только событие `push` в `main`;

г) использовать полный SHA коммита как неизменяемый идентификатор версии образа и `latest` как изменяемый указатель;

д) настроить доступ к GHCR через `GITHUB_TOKEN` и право `packages: write`;

е) исследовать три класса отказов: нарушение функционального требования, ошибка запуска контейнера и отказ авторизации в реестре.

**Связь с предыдущими работами.** Используются знания GitHub Actions из практической работы № 9 и модель Docker-образа из работы № 7. В отличие от работы № 9, проверяется не документация, а приложение и его исполняемый артефакт.

**Связь с последующими работами.** Опубликованный образ будет загружаться на целевую VM при автоматизации развёртывания средствами Ansible в практической работе № 11 и контрольной работе № 3. Полный SHA в теге позволит развернуть именно проверенную версию, а не неопределённое текущее содержимое `latest`.

---

## 2 Теоретическая часть

### 2.1 Конвейер как цепочка доказательств

Каждый этап CI отвечает на отдельный вопрос:

| Этап | Проверяемое свойство | Что этап не доказывает |
|---|---|---|
| Pylint | Код соответствует включённым правилам статического анализа | Корректность поведения приложения |
| pytest | Выбранные сценарии возвращают ожидаемые результаты | Работоспособность собранного образа |
| `docker build` | Инструкции Dockerfile выполнились, образ создан | Успешный запуск процесса в контейнере |
| Smoke-test | Контейнер запускается и отвечает на `/health` | Полное отсутствие прикладных дефектов |
| `docker push` | Образ передан в реестр | Работоспособность будущего развёртывания на VM |

Вывод «тесты прошли, значит образ работает» некорректен. Например, тесты вызывают фабрику приложения напрямую, а Gunicorn в контейнере использует отдельно заданную точку входа. Ошибка в ней проявится только при запуске образа.

### 2.2 Зависимости заданий и коды возврата

Ключ `needs` задаёт зависимость. В работе применяется цепочка:

```text
lint → test → image
```

Если `lint` завершился ошибкой, `test` не запускается; если упал `test`, сборка образа не выполняется. Это экономит время и не позволяет опубликовать результат, который не прошёл предыдущие этапы.

При этом задание, пропущенное из-за отказа в `needs`, получает статус `skipped`, а GitHub считает статусы `success`, `skipped` и `neutral` успешными для обязательных проверок. Поэтому одна обязательная проверка `image` не защищает ветку: если упал `test`, то `image` будет пропущен, засчитан как успешный, и PR можно будет слить. В работе обязательными назначаются все три задания: `lint`, `test` и `image`. В промышленных репозиториях вместо этого часто добавляют итоговое задание с `if: ${{ !cancelled() }}`, которое явно проверяет `needs.<job>.result` всех предыдущих заданий, и делают обязательным только его.

Любая команда `run` должна возвращать нулевой код только при действительном успехе. В многострочном smoke-test используется `set -euo pipefail`: ошибка команды, обращение к неустановленной переменной или отказ элемента конвейера приводят к ненулевому завершению шага.

### 2.3 Модульные тесты Flask

Flask предоставляет тестовый клиент, который вызывает приложение без запуска сетевого сервера. Он подходит для быстрой проверки кода ответа и JSON-тела. Фикстура pytest создаёт тестовый клиент и автоматически подставляет его в тестовые функции.

В работе два теста:

1. `/health` возвращает `200` и `{"status": "ok"}`;
2. `/` возвращает `200`, имя службы и версию.

Тесты не требуют PostgreSQL и внешних сервисов. Это намеренное упрощение: на занятии исследуется конвейер, а не написание приложения. Запуск выполняется командой `python -m pytest` из корня репозитория: форма `python -m` включает текущий каталог в путь импорта, поэтому пакет `app` находится без дополнительной настройки `PYTHONPATH`.

### 2.4 Сборка и smoke-test

На `ubuntu-latest` доступен Docker. Workflow собирает локальный образ `devops-ci-app:<SHA>`, запускает его с публикацией порта только на `127.0.0.1` runner и выполняет HTTP-запрос к `/health`.

Smoke-test — короткая проверка жизнеспособности, а не полный набор интеграционных тестов. Если процесс завершился из-за неверной точки входа Gunicorn, повторные HTTP-запросы не помогут. Диагностическое значение имеют `docker logs` и код отказа шага.

Контейнер запускается от имени непривилегированного пользователя `app`. Команда `docker exec smoke id` подтверждает это. Успешная сборка от имени `root` на этапе `RUN` не означает, что приложение должно работать от `root` после запуска.

### 2.5 GHCR и теги образа

GHCR использует имена вида:

```text
ghcr.io/<owner>/<repository>:<tag>
```

Реестр требует строчных букв в имени образа. Workflow приводит значение `github.repository` к нижнему регистру перед тегированием.

Публикуются два тега одного образа:

- `ghcr.io/<owner>/devops-ci-app:<полный-SHA>` — неизменяемая привязка к исходному коммиту;
- `ghcr.io/<owner>/devops-ci-app:latest` — изменяемый указатель на последнюю успешно опубликованную версию из `main`.

Полный SHA предпочтителен для воспроизводимого деплоя. Тег `latest` удобен для ручной проверки, но сам по себе не сообщает, какая версия была развёрнута ранее. Для промышленного деплоя ещё точнее использовать digest вида `sha256:...`, поскольку даже тег теоретически может быть перезаписан.

Для публикации job получает:

```yaml
permissions:
  contents: read
  packages: write
```

Аутентификация выполняется командой `docker login ghcr.io` с `GITHUB_TOKEN`. Токен передаётся в шаг через переменную окружения `env`, а не подставляется выражением `${{ ... }}` прямо в текст команды: так значение не становится частью сгенерированного скрипта, и это та же привычка, которая защищает от инъекций при работе с недоверенными данными события. Персональный токен не требуется. Первый созданный пакет GHCR по умолчанию может быть приватным; для последующей загрузки на учебную VM его видимость изменяют на public либо настраивают отдельную аутентификацию чтения.

### 2.6 Почему PR не должен публиковать образ

На событии `pull_request` выполняются линтинг, тесты, сборка и smoke-test. Шаги login, tag для реестра и push пропускаются условием:

```yaml
if: github.event_name == 'push' && github.ref == 'refs/heads/main'
```

Таким образом, каждый PR доказывает собираемость, но не изменяет публикуемые теги. Событие `pull_request_target` не используется: сочетание повышенных прав и выполнения непроверенного кода из fork создаёт дополнительный риск.

---

## 3 Подготовка к занятию

### 3.1 Создание репозитория

1. Создайте новый **публичный** репозиторий GitHub `devops-ci-app` с `README.md`.
2. Склонируйте его по SSH:

```bash
git clone git@github.com:<login>/devops-ci-app.git
cd devops-ci-app
git switch main
git status
```

`<login>` заменяется именем учётной записи без угловых скобок. Команды выполняются на хостовой системе, а запуски конвейера — на GitHub.

### 3.2 Проверка готовности

Таблица 1. Условия готовности

| Номер | Условие | Подтверждение |
|---|---|---|
| 1 | Репозиторий публичный и склонирован | URL репозитория, `git status` |
| 2 | Push по SSH работает | `git push` после первого коммита |
| 3 | Вкладка Actions доступна | Визуальная проверка |
| 4 | GitHub Packages не заблокирован настройками учётной записи | Наличие раздела Packages после первой публикации |
| 5 | Локальные Python и Docker не устанавливаются перед занятием | Все команды выполняет runner |

**Резерв при недоступности GHCR.** Если настройки учётной записи запрещают публикацию пакетов, основную часть всё равно можно выполнить до smoke-test включительно. Отказ публикации документируется, а преподаватель предоставляет готовый публичный образ для самостоятельной проверки. Не подменяйте GHCR случайным публичным Docker Hub-аккаунтом с общим паролем.

---

## 4 Порядок выполнения аудиторной части

Таблица 2. Регламент занятия

| Этап | Содержание | Время, мин |
|---|---|---|
| 1 | Проверка готовности | 5 |
| 2 | Задание 1. Шаблон приложения и тесты | 15 |
| 3 | Задание 2. Конвейер и инцидент с GHCR | 25 |
| 4 | Задание 3. Инцидент с модульным тестом | 15 |
| 5 | Задание 4. Инцидент запуска контейнера | 20 |
| 6 | Итоговый контроль, резерв, вопросы | 10 |
| | Итого | 90 |

Итоговый workflow должен проходить все этапы на `main` и публиковать два тега. В PR должны выполняться только проверки, без login и push. Все намеренные дефекты к концу работы исправлены.

### 4.1 Задание 1. Шаблон приложения и тесты

**Шаг 1.1.** Создайте структуру:

```bash
mkdir -p app tests .github/workflows
```

Создайте `.gitignore`:

```gitignore
__pycache__/
*.pyc
.pytest_cache/
.coverage
```

Создайте `.dockerignore`:

```text
.git
.github
.pytest_cache
__pycache__
*.pyc
tests
requirements-dev.txt
```

**Шаг 1.2.** Создайте `app/requirements.txt`:

```text
flask==3.1.3
gunicorn==26.2.0
```

Создайте `requirements-dev.txt`:

```text
pylint==4.1.3
pytest==9.2.0
```

Разделение файлов не даёт включить pytest и Pylint в производственный образ. В CI устанавливаются оба набора.

**Шаг 1.3.** Создайте `app/__init__.py`:

```python
"""Пакет учебного Flask-приложения."""

from .app import create_app

__all__ = ["create_app"]
```

Создайте `app/app.py`:

```python
"""HTTP-приложение для проверки CI-конвейера."""

from flask import Flask, jsonify


def create_app():
    """Создаёт и настраивает экземпляр приложения."""
    application = Flask(__name__)

    @application.get("/health")
    def health():
        """Возвращает результат простой проверки жизнеспособности."""
        return jsonify(status="ok")

    @application.get("/")
    def index():
        """Возвращает сведения о службе."""
        return jsonify(
            service="devops-ci-app",
            version="1.0.0",
            status="running",
        )

    return application


app = create_app()
```

**Шаг 1.4.** Создайте `tests/test_app.py`:

```python
"""Модульные тесты HTTP-интерфейса."""

import pytest

from app import create_app


@pytest.fixture()
def client():
    """Создаёт изолированный тестовый клиент Flask."""
    app = create_app()
    app.config.update(TESTING=True)
    with app.test_client() as test_client:
        yield test_client


def test_health(client):
    """Проверяет код и тело ответа health endpoint."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_index(client):
    """Проверяет основные сведения о службе."""
    response = client.get("/")
    assert response.status_code == 200
    assert response.get_json() == {
        "service": "devops-ci-app",
        "version": "1.0.0",
        "status": "running",
    }
```

**Шаг 1.5.** Создайте `Dockerfile`, заменив `<login>`:

```dockerfile
FROM python:3.12-slim

LABEL org.opencontainers.image.source="https://github.com/<login>/devops-ci-app"
LABEL org.opencontainers.image.description="DevOps CI sample application"

RUN useradd --system --no-create-home app

WORKDIR /app

COPY app/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/

USER app

EXPOSE 5000
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--access-logfile", "-", "app.app:app"]
```

Точка входа `app.app:app` означает: пакет `app`, модуль `app.py`, переменная `app`. Сокращение до `app:app` в задании 4 намеренно создаст ошибку, которую модульные тесты не обнаружат.

**Внимание.** В OCI label `org.opencontainers.image.source` нужно обязательно заменить `<login>`. Этот label связывает GHCR-пакет с репозиторием; оставленная заглушка даст неверную ссылку и затруднит проверку связи в шаге 2.5.

**Шаг 1.6.** Обновите `README.md`:

```markdown
# devops-ci-app

Учебное Flask-приложение для практической работы № 10.

CI: Pylint → pytest → Docker build → smoke-test → GHCR.

Публикация образа выполняется только из `main`. В Pull Request выполняются проверки без push.

- health endpoint: `/health`;
- образ: `ghcr.io/<login>/devops-ci-app`;
- основной workflow: `.github/workflows/ci.yml`.
```

**Шаг 1.7.** Зафиксируйте начальное состояние:

```bash
git add .
git commit -m "feat: add flask app tests and dockerfile"
git push -u origin main
```

Workflow ещё не существует, поэтому отсутствие запуска Actions ожидаемо. Не пытайтесь установить зависимости локально: первый реальный запуск тестов будет выполнен runner.

**В отчёт:** структура репозитория, Dockerfile, объяснение точки входа `app.app:app` и причина разделения двух файлов зависимостей.

### 4.2 Задание 2. Конвейер и инцидент с GHCR

#### 4.2.1 Создание конвейера

**Шаг 2.1.** Создайте `.github/workflows/ci.yml` в `main`. В первой версии намеренно отсутствует `packages: write`; не добавляйте его до воспроизведения инцидента.

```yaml
name: CI — verify and publish image

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

env:
  IMAGE_NAME: ghcr.io/${{ github.repository }}

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v7

      - name: Setup Python
        uses: actions/setup-python@v7
        with:
          python-version: "3.12"
          cache: pip
          cache-dependency-path: |
            app/requirements.txt
            requirements-dev.txt

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          python -m pip install -r app/requirements.txt -r requirements-dev.txt

      - name: Pylint
        run: python -m pylint app --score=no

  test:
    needs: lint
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v7

      - name: Setup Python
        uses: actions/setup-python@v7
        with:
          python-version: "3.12"
          cache: pip
          cache-dependency-path: |
            app/requirements.txt
            requirements-dev.txt

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          python -m pip install -r app/requirements.txt -r requirements-dev.txt

      - name: Unit tests
        run: python -m pytest -q

  image:
    needs: test
    runs-on: ubuntu-latest

    # ИНЦИДЕНТ 1: для push в GHCR права пока недостаточно.
    permissions:
      contents: read

    steps:
      - name: Checkout
        uses: actions/checkout@v7

      - name: Normalize image name
        run: echo "IMAGE_NAME=${IMAGE_NAME,,}" >> "$GITHUB_ENV"

      - name: Build image
        run: docker build --tag "devops-ci-app:${GITHUB_SHA}" .

      - name: Smoke-test container
        run: |
          set -euo pipefail
          cleanup() {
            docker logs smoke || true
            docker rm -f smoke >/dev/null 2>&1 || true
          }
          trap cleanup EXIT
          docker run -d --name smoke -p 127.0.0.1:5000:5000 "devops-ci-app:${GITHUB_SHA}"
          ready=0
          for attempt in {1..15}; do
            if curl --fail --silent --show-error --max-time 2 \
              http://127.0.0.1:5000/health --output health.json; then
              ready=1
              break
            fi
            sleep 1
          done
          if [ "$ready" -ne 1 ]; then
            echo "::error::/health did not respond after 15 attempts"
            exit 1
          fi
          python3 -m json.tool health.json
          python3 - <<'PY'
          import json
          from pathlib import Path

          payload = json.loads(Path("health.json").read_text(encoding="utf-8"))
          assert payload == {"status": "ok"}, f"unexpected /health payload: {payload}"
          PY
          docker exec smoke id

      - name: Tag registry image
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        run: |
          docker tag "devops-ci-app:${GITHUB_SHA}" "${IMAGE_NAME}:${GITHUB_SHA}"
          docker tag "devops-ci-app:${GITHUB_SHA}" "${IMAGE_NAME}:latest"

      - name: Log in to GHCR
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        env:
          REGISTRY_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: printf '%s\n' "$REGISTRY_TOKEN" | docker login ghcr.io --username "$GITHUB_ACTOR" --password-stdin

      - name: Push image
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        run: |
          docker push "${IMAGE_NAME}:${GITHUB_SHA}"
          docker push "${IMAGE_NAME}:latest"
```

Обратите внимание, что `needs` связывает задания, а условия `if` относятся только к публикации. Сборка и smoke-test выполняются и для PR.

**Шаг 2.2.** Зафиксируйте workflow:

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add test build and registry publishing pipeline"
git push
```

Откройте **Actions → CI — verify and publish image**. Проследите порядок:

1. `lint` успешен;
2. `test` запускается после `lint`, два теста проходят;
3. `image` запускается после `test`, образ собирается;
4. smoke-test получает `status=ok`, выполняет разбор JSON без зависимости от его текстового форматирования, а `docker exec smoke id` показывает пользователя `app`;
5. login, как правило, завершается успешно, но **Push image** отклоняется реестром. Если отказ произошёл уже на шаге login, разбор аналогичен: это тот же отказ авторизации в реестре.

#### 4.2.2 Инцидент 1: отказ push в реестр

**Шаг 2.3.** Откройте журнал **Push image**. Найдите `denied`, `403` или сообщение о недостаточном праве записи пакета. Успешный login не доказывает наличие права push: аутентификация подтверждает личность токена, а авторизация определяет разрешённые операции.

Зафиксируйте разбор:

```text
Симптом: lint, test, build и smoke-test успешны; docker push отклонён.
Компонент: авторизация GHCR.
Причина: у GITHUB_TOKEN отсутствует packages: write.
Влияние: проверенный образ остался только на временном runner; пакет не опубликован.
```

**Шаг 2.4.** Исправьте только блок `permissions` задания `image`:

```yaml
    permissions:
      contents: read
      packages: write
```

Удалите комментарий об инциденте и отправьте исправление:

```bash
git add .github/workflows/ci.yml
git commit -m "fix: allow pipeline to publish container package"
git push
```

Не ограничивайтесь **Re-run failed jobs**: повторный запуск использует прежний workflow. Дождитесь нового зелёного запуска и убедитесь, что оба `docker push` успешны.

**Шаг 2.5.** Откройте пакет через раздел **Packages** на странице репозитория или профиля. Найдите:

- имя `devops-ci-app`;
- тег `latest`;
- тег, равный полному SHA последнего коммита;
- связь пакета с репозиторием.

Если пакет приватный, откройте **Package settings → Change visibility** и сделайте его публичным для последующих учебных работ. Если изменение видимости запрещено политикой организации, сохраните приватность и зафиксируйте необходимость аутентификации при будущем `docker pull`.

#### 4.2.3 Обязательный итоговый контроль

**Шаг 2.6.** После успешного запуска создайте **Settings → Rules → Rulesets → New branch ruleset** с именем `protect-main`:

1. target — default branch `main`;
2. включите **Require status checks to pass**;
3. добавьте три проверки: `lint`, `test` и `image`;
4. сохраните правило.

Одной итоговой проверки `image` недостаточно, хотя её `needs: test`, а у `test` — `needs: lint`. Если упадёт `lint` или `test`, задание `image` получит статус `skipped`, а пропущенная обязательная проверка засчитывается как успешная. Отказ блокирует merge только тогда, когда обязательной является сама упавшая проверка. При классической защите ветки используйте эквивалент **Require status checks to pass before merging** с теми же тремя проверками.

**Внимание.** После сохранения правила прямой `git push` в `main` отклоняется (`GH013: Repository rule violations found`): у нового коммита ещё нет успешных обязательных проверок. Все последующие изменения, включая изменения `ci.yml` в разделах 5 и 6, вносятся через ветку и Pull Request.

**В отчёт:** схема трёх jobs, успешный smoke-test, журнал отказа GHCR, исправление `packages: write`, страница пакета с двумя тегами и настройка required checks `lint`, `test`, `image`.

### 4.3 Задание 3. Инцидент с модульным тестом

**Шаг 3.1.** Создайте ветку:

```bash
git switch -c fix/health-response
```

В `app/app.py` замените:

```python
return jsonify(status="ok")
```

на намеренно ошибочное:

```python
return jsonify(status="unhealthy")
```

Отправьте изменение и создайте PR:

```bash
git add app/app.py
git commit -m "fix: report explicit health state"
git push -u origin fix/health-response
```

**Шаг 3.2.** Дождитесь результата. Ожидается:

- `lint` зелёный: синтаксис и стиль не нарушены;
- `test` красный: `test_health` показывает различие ожидаемого и фактического JSON;
- `image` отмечен как пропущенный (`skipped`) и не выполняет сборку из-за `needs: test`;
- обычный merge блокируется обязательной проверкой `test`.

В журнале pytest найдите `assert` и значения `ok`/`unhealthy`. Ответьте, почему Pylint не считает такую замену ошибкой и почему `docker build` не должен начинаться после этого отказа. Отдельно объясните по списку проверок PR, почему merge был бы разрешён, если бы обязательной оставалась только проверка `image`.

**Шаг 3.3.** Верните корректное значение:

```python
return jsonify(status="ok")
```

Отправьте исправление в ту же ветку:

```bash
git add app/app.py
git commit -m "fix: restore healthy status contract"
git push
```

Дождитесь зелёной цепочки. В job `image` раскройте шаги и убедитесь, что **Tag registry image**, **Log in to GHCR** и **Push image** пропущены, поскольку событие — `pull_request`. Сравните SHA пакета в GHCR: новый тег коммита PR появиться не должен.

После успешной проверки выполните merge. Теперь уже запуск по `push` в `main` опубликует новый SHA и обновит `latest`.

**В отчёт:** failed test с фактическим и ожидаемым значением, статус `skipped` у `image` и заблокированный merge, зелёный PR после исправления, пропущенные шаги публикации и объяснение различия событий PR и main.

### 4.4 Задание 4. Инцидент запуска контейнера

**Шаг 4.1.** Обновите локальную `main` и создайте ветку:

```bash
git switch main
git pull
git switch -c fix/gunicorn-entrypoint
```

В `Dockerfile` намеренно замените последнюю строку:

```dockerfile
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--access-logfile", "-", "app:app"]
```

Зафиксируйте изменение и создайте PR:

```bash
git add Dockerfile
git commit -m "fix: shorten gunicorn application path"
git push -u origin fix/gunicorn-entrypoint
```

**Шаг 4.2.** Дождитесь запуска. На этот раз:

- Pylint успешен;
- оба pytest-теста успешны;
- `docker build` успешен: инструкция `CMD` не запускает Gunicorn во время сборки;
- smoke-test завершается ошибкой, поскольку контейнер не отвечает на `/health`.

В журнале найдите сообщение Gunicorn о некорректном объекте приложения, например `Application object must be callable`; в других версиях формулировка может указывать на невозможность найти атрибут `app`. Вспомогательный код `cleanup` выводит `docker logs` даже при отказе, поэтому журнал доступен непосредственно в упавшем шаге.

**Требуемый разбор:** объясните, почему тесты импортируют `create_app` успешно, а сокращённая точка входа `app:app` даёт Gunicorn модуль `app` вместо вызываемого WSGI-приложения из `app/app.py`. Укажите, какой этап конвейера впервые обнаружил дефект и почему предыдущие этапы были обязаны остаться зелёными.

**Шаг 4.3.** Восстановите точку входа:

```dockerfile
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--access-logfile", "-", "app.app:app"]
```

Отправьте исправление:

```bash
git add Dockerfile
git commit -m "fix: use full gunicorn application entrypoint"
git push
```

Дождитесь зелёного smoke-test. Убедитесь, что `health.json` содержит `status: ok`, а `docker exec smoke id` подтверждает запуск не от `root`. Выполните merge и дождитесь публикации нового SHA в `main`.

**Шаг 4.4.** Сопоставьте результаты трёх инцидентов:

| Инцидент | Последний зелёный этап | Первый отказавший этап | Почему предыдущие проверки не помогли |
|---|---|---|---|
| Нет `packages: write` | Smoke-test | `docker push` | Проверки приложения не проверяют права реестра |
| `status=unhealthy` | Pylint | pytest | Статический анализ не знает прикладной контракт |
| Неверная точка входа | pytest и `docker build` | Smoke-test | Тесты не запускают команду контейнера |

**В отчёт:** журнал Gunicorn, объяснение различия `app:app` и `app.app:app`, успешный smoke-test после исправления и заполненная таблица трёх инцидентов.

---

## 5 Задание для самостоятельной работы

### 5.1 Проверка опубликованного образа вне CI

Выполняется на VM из практической работы № 7 либо на другом узле с Docker. Цель — доказать, что реестр содержит не только запись о пакете, но и загружаемый работоспособный образ.

Во всех адресах GHCR ниже `<login>` указывайте **строчными буквами**, как после шага Normalize image name в workflow. Это особенно важно, если в имени учётной записи GitHub есть заглавные буквы.

**Шаг 5.1.** На VM выполните:

```bash
docker pull ghcr.io/<login>/devops-ci-app:latest
docker run -d --name ci-app -p 127.0.0.1:5001:5000 ghcr.io/<login>/devops-ci-app:latest
curl --fail http://127.0.0.1:5001/health
docker exec ci-app id
docker logs ci-app
```

Ожидается `{"status":"ok"}` и пользователь `app`. После проверки удалите только контейнер:

```bash
docker rm -f ci-app
```

Образ и опубликованный пакет не удаляйте: они пригодятся в практической работе № 11.

**Шаг 5.2.** Повторите запуск по полному SHA последнего зелёного коммита:

```bash
docker pull ghcr.io/<login>/devops-ci-app:<полный-SHA>
docker run -d --name ci-app-sha -p 127.0.0.1:5002:5000 ghcr.io/<login>/devops-ci-app:<полный-SHA>
curl --fail http://127.0.0.1:5002/health
docker rm -f ci-app-sha
```

Объясните, почему запуск по SHA воспроизводимее запуска по `latest` и какую информацию следует записать в `docs/server-setup.md` при будущем Ansible-деплое.

Если пакет оставлен приватным, анонимный `docker pull` завершится отказом. Не размещайте персональный токен в отчёте или командах с сохранением в историю; для основного варианта рекомендуется заранее сделать учебный пакет публичным.

**В отчёт:** вывод pull по SHA, health-ответ, пользователь контейнера и сравнение SHA/latest.

### 5.2 Сохранение digest результата

Задание выполняется по желанию. В отдельной ветке измените шаг **Push image**, чтобы журнал явно фиксировал digest, и внесите изменение в `main` через PR (прямой push отклоняется правилом `protect-main`):

```yaml
      - name: Push image
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        run: |
          docker push "${IMAGE_NAME}:${GITHUB_SHA}" | tee push-sha.log
          docker push "${IMAGE_NAME}:latest" | tee push-latest.log
          grep -E 'digest: sha256:' push-sha.log push-latest.log
```

Объясните, почему одинаковый digest для двух тегов подтверждает идентичность содержимого образа и чем digest отличается от локального image ID.

---

## 6 Факультативное задание. Публикация по версионному тегу

Добавьте запуск workflow для Git-тегов `v*` и публикацию Docker-тега без префикса `v`: Git-тег `v1.1.0` должен создать образ `:1.1.0`.

Требования:

1. не нарушать публикацию SHA и `latest` для `main`;
2. для PR по-прежнему не выполнять push; изменение `ci.yml` вносить через PR;
3. не заменять версионный тег значением `latest` вручную;
4. в отчёте показать соответствие Git tag → Docker tag → коммит.

Ответьте, почему повторный push существующего версионного тега после изменения исходников нарушает воспроизводимость выпуска.

---

## 7 Быстрая диагностика типовых затруднений

Таблица 3. Диагностический минимум

| Симптом | Вероятная причина | Первичная проверка |
|---|---|---|
| `test` ожидает и не запускается | Упал `lint` | Журнал Pylint и `needs: lint` |
| `image` не запускается | Упал или пропущен `test` | Журнал pytest и цепочка `needs` |
| PR с упавшим `test` можно слить | Обязательной назначена только `image`, а пропущенная проверка считается успешной | Список required checks: `lint`, `test`, `image` |
| `git push` в `main` отклонён с `GH013` | Правило `protect-main` требует успешных проверок до обновления ветки | Ветка и PR вместо прямого push |
| Required check не находится | Job `lint`, `test` или `image` ещё ни разу не запускался | Первый запуск workflow до настройки правила |
| PR собрал образ, но в Packages нет версии | Условия публикации правильно пропустили push | Событие `pull_request`, статус шагов Tag/Login/Push |
| `docker push` возвращает denied | Нет права записи или пакет не связан с репозиторием | `packages: write`, владелец образа, OCI source label |
| Имя образа отклонено | В owner/repository есть заглавные буквы | Шаг Normalize image name |
| Контейнер не отвечает | Процесс завершился или порт не опубликован | `docker logs`, `docker ps`, `EXPOSE`/`-p` |
| Smoke-test падает без health.json | Все попытки curl завершились отказом | Журнал контейнера в cleanup |
| `latest` не изменился | Запуск был PR или push выполнен в другой репозиторий | Событие, ref и полное имя образа |
| VM не может загрузить образ | Пакет приватный | Видимость пакета или аутентификация чтения |
| Re-run повторяет ошибку конфигурации | Используется прежний коммит workflow | SHA запуска и новый push с исправлением |

---

## 8 Подготовка к практической работе № 11

а) повторить структуру VM, SSH и Docker из практических работ № 5–7;

б) изучить понятия inventory, playbook, task, handler, role и идемпотентность Ansible;

в) определить, какие сведения потребуются для автоматического развёртывания опубликованного образа: адрес VM, SSH-пользователь, имя образа, тег SHA, порт, health endpoint;

г) обновить `docs/server-setup.md`: добавить адрес GHCR-образа, выбранный SHA и требования к доступу на чтение пакета;

д) подготовить устный ответ, почему Ansible не должен заново собирать приложение на каждой VM, если проверенный образ уже опубликован CI.

---

## 9 Контрольные вопросы

1. Какую цепочку зависимостей образуют `needs` в настоящей работе и почему нельзя запускать все jobs параллельно?
2. Почему Pylint пропустил замену `ok` на `unhealthy`, а pytest её обнаружил?
3. Почему успешный `docker build` не гарантирует успешный запуск контейнера?
4. Что означает точка входа `app.app:app`? Почему `app:app` не работает в данном проекте?
5. Какую дополнительную информацию даёт smoke-test по сравнению с модульными тестами Flask test client?
6. Почему login в GHCR может быть успешным при отсутствии права push? Чем аутентификация отличается от авторизации?
7. Какие права необходимы job `image` и почему lint/test их не получают?
8. Почему шаги публикации пропускаются для PR? Что при этом всё равно проверяется?
9. Почему полный SHA коммита предпочтительнее `latest` для воспроизводимого деплоя? Какое преимущество у digest?
10. Почему два тега могут ссылаться на один и тот же образ без повторной сборки?
11. Для чего имя `github.repository` приводится к нижнему регистру?
12. Почему Re-run failed jobs не применяет исправленный `permissions` из нового коммита?
13. Почему недостаточно назначить обязательной только итоговую проверку `image`, хотя она связана с предыдущими через `needs`? Какие два способа решения применяются на практике?
14. Почему `requirements-dev.txt` не копируется в образ?
15. Какие риски возникли бы при использовании `pull_request_target` и выполнении непроверенного Dockerfile из fork с правом `packages: write`?
16. Почему в контрольной работе № 3 целесообразно развёртывать образ по SHA, а не повторно собирать его на VM?

---

## 10 Требования к содержанию и оформлению отчёта

Отчёт оформляется в формате Microsoft Word (.docx) и содержит титульный лист, цель и задачи работы, схему конвейера, материалы из блоков «В отчёт», ссылки на репозиторий и GHCR-пакет, разборы трёх инцидентов, результаты самостоятельной проверки образа и выводы.

Для каждого инцидента приводятся симптом, последний успешный этап, доказательство из журнала, причина, исправление и подтверждение восстановления. Скриншот зелёного workflow без журнала исходного отказа не заменяет разбор.

Таблица 4. Условия, проверяемые перед сдачей

| Номер | Условие | Подтверждение |
|---|---|---|
| 1 | Workflow содержит последовательность `lint → test → image` | `ci.yml`, граф запуска |
| 2 | Pylint и два pytest-теста успешны | Журналы jobs |
| 3 | Образ собран, smoke-test возвращает `status=ok` | Build image, Smoke-test container |
| 4 | Контейнер работает не от `root` | `docker exec smoke id` |
| 5 | Воспроизведён отказ GHCR и добавлено только необходимое право | Журнал denied/403, `packages: write` |
| 6 | GHCR содержит теги полного SHA и `latest` | Страница пакета |
| 7 | Проверки `lint`, `test`, `image` обязательны для `main` | Ruleset `protect-main` |
| 8 | Failed test останавливает сборку и блокирует PR | Журнал pytest, `image` в состоянии `skipped`, заблокированный merge |
| 9 | PR выполняет build и smoke-test, но не публикует | Пропущенные Tag/Login/Push |
| 10 | Неверная точка входа обнаружена smoke-test и исправлена | Журнал Gunicorn, зелёный повторный запуск |
| 11 | Образ загружен по SHA и проверен вне CI | Команды VM и health-ответ |
| 12 | В репозитории и журналах отчёта нет токенов и паролей | Проверка файлов и скриншотов |

Итоговая защита: студент по выбранному преподавателю отказу должен показать место в цепочке, объяснить, почему предыдущие проверки его не выявили, и назвать изменение, восстановившее конвейер.

---

## Список использованных источников

1. Publishing Docker images [Электронный ресурс] // GitHub Docs. URL: https://docs.github.com/en/actions/use-cases-and-examples/publishing-packages/publishing-docker-images (дата обращения: 04.11.2026).
2. Publishing and installing a package with GitHub Actions [Электронный ресурс] // GitHub Docs. URL: https://docs.github.com/en/packages/managing-github-packages-using-github-actions-workflows/publishing-and-installing-a-package-with-github-actions (дата обращения: 04.11.2026).
3. Working with the Container registry [Электронный ресурс] // GitHub Docs. URL: https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry (дата обращения: 04.11.2026).
4. About permissions for GitHub Packages [Электронный ресурс] // GitHub Docs. URL: https://docs.github.com/en/packages/learn-github-packages/about-permissions-for-github-packages (дата обращения: 04.11.2026).
5. Workflow syntax for GitHub Actions [Электронный ресурс] // GitHub Docs. URL: https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions (дата обращения: 04.11.2026).
6. pytest: how to write and report assertions [Электронный ресурс]. URL: https://docs.pytest.org/en/stable/how-to/assert.html (дата обращения: 04.11.2026).
7. Flask. Testing Flask Applications [Электронный ресурс]. URL: https://flask.palletsprojects.com/en/stable/testing/ (дата обращения: 04.11.2026).
8. Dockerfile reference [Электронный ресурс] // Docker Docs. URL: https://docs.docker.com/reference/dockerfile/ (дата обращения: 04.11.2026).
9. Gunicorn. Running Gunicorn [Электронный ресурс]. URL: https://docs.gunicorn.org/en/stable/run.html (дата обращения: 04.11.2026).
10. Pylint. User Guide [Электронный ресурс]. URL: https://pylint.readthedocs.io/en/latest/user_guide/index.html (дата обращения: 04.11.2026).
11. Troubleshooting required status checks [Электронный ресурс] // GitHub Docs. URL: https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks (дата обращения: 04.11.2026).
