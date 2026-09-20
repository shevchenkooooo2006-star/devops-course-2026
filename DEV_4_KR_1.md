|||
|---|---|
|ДИСЦИПЛИНА|Инструменты девопс|
|ИНСТИТУТ|ИПТИП|
|КАФЕДРА|Индустриального программирования|
|ВИД УЧЕБНОГО МАТЕРИАЛА|Методические указания к контрольной работе|
|ПРЕПОДАВАТЕЛЬ|Гиматдинов Дамир Маратович|
|СЕМЕСТР|5 семестр, 2026/2027 уч. год|

Ссылка на материал: <br>
https://gitverse.ru/dgimatdinov/DevOps_2026/content/master/DEV_4_KR_1.md

# ПРАКТИЧЕСКАЯ РАБОТА №4
## Тема: Контрольная работа №1. Комплексное применение Git и Gitverse

**Дисциплина:** Инструменты DevOps  
**Курс:** 3  
**Занятие:** 4 из 16  
**Блок:** Git и Github (занятие 4 из 4)  
**Форма работы:** Индивидуальная, аудиторная  
**Продолжительность:** 90 минут  

---

## 🎯 Цель работы

Проверить и закрепить навыки работы с Git и Github (Gitverse), полученные в ходе трёх предыдущих занятий:
1. Работа с удалёнными репозиториями (fork, clone, multi-remote).
2. Ветвление и Pull Request'ы.
3. Продвинутые техники: interactive rebase, squash, разрешение конфликтов.
4. Использование `reflog`, `cherry-pick`, `revert` в критических ситуациях.

---

## 📋 Сценарий контрольной работы

Преподаватель заранее подготовил **репозиторий-шаблон** `devops-kr-template`, содержащий:
- Простой Python-проект (валидатор email-адресов).
- Ветку `main` с базовой функциональностью.
- Ветку `feature/instructor-change`, в которой преподаватель намеренно изменил те же строки, что и вы будете менять — это гарантирует **merge-конфликт** при создании PR.

Ваша задача — пройти полный цикл разработки: от форка до финального merge, продемонстрировав владение всеми изученными техниками Git.

---

## 💻 Практическая часть

### Задание 1. Форк и настройка окружения ( ~10 минут)

**Шаг 1.1.** Откройте репозиторий преподавателя: `https://gitverse.ru/dgimatdinov/devops-kr-template`. Нажмите кнопку **Fork** в правом верхнем углу (или можете импортировать репозиторий на другую платформу, например Github).

**Шаг 1.2.** Клонируйте **свой** форк на локальную машину по SSH:

```bash
git clone git@gitverse.ru:ваш_username/devops-kr-template.git
cd devops-kr-template
```

**Шаг 1.3.** Добавьте upstream (оригинальный репозиторий преподавателя):

```bash
git remote add upstream git@https://gitverse.ru/dgimatdinov/devops-kr-template
git remote -v
```

Ожидаемый вывод:
```
origin    git@gitverse.ru:ваш_username/devops-kr-template.git (fetch)
origin    git@gitverse.ru:ваш_username/devops-kr-template.git (push)
upstream  git@https://gitverse.ru/dgimatdinov/devops-kr-template (fetch)
upstream  git@https://gitverse.ru/dgimatdinov/devops-kr-template (push)
```

**Шаг 1.4.** Настройте **второй remote** (mirror). Выберите один из вариантов:
- **Вариант А:** Создайте пустой репозиторий на `gitlab.com` с именем `devops-kr-mirror`.
- **Вариант Б:** Создайте пустой репозиторий на Gitverse с именем `devops-kr-mirror`.

```bash
# Для GitLab:
git remote add mirror git@gitlab.com:ваш_username/devops-kr-mirror.git

# Для Gitverse:
# git remote add mirror git@gitverse.ru:ваш_username/devops-kr-mirror.git
```

**Шаг 1.5.** Настройте автоматический push в оба remote:

```bash
git remote set-url --add --push origin git@gitlab.com:ваш_username/devops-kr-mirror.git
# или для Gitverse-mirror:
# git remote set-url --add --push origin git@gitverse.ru:ваш_username/devops-kr-mirror.git
```

**Шаг 1.6.** Проверьте, что всё настроено корректно:

```bash
git remote -v
git fetch --all
```

✅ **Отчёт:** Скриншот вывода `git remote -v` с тремя remote (`origin`, `upstream`, `mirror`).

---

### Задание 2. Создание feature-ветки и внесение изменений ( ~15 минут)

**Шаг 2.1.** Обновите локальную `main` из upstream и создайте feature-ветку:

```bash
git checkout main
git pull upstream main
git checkout -b feature/add-phone-validation
```

**Шаг 2.2.** Откройте файл `validator.py` и изучите его структуру. Это простой валидатор email-адресов.

**Шаг 2.3.** Внесите **три отдельных изменения**, каждое — отдельным коммитом:

**Коммит 1:** Добавьте функцию валидации телефона в начало файла:

```python
def validate_phone(phone: str) -> bool:
    """Валидация российского номера телефона."""
    import re
    pattern = r'^\+?7\d{10}$'
    return bool(re.match(pattern, phone.replace('-', '').replace(' ', '')))
```

```bash
git add validator.py
git commit -m "feat: add phone validation function"
```

**Коммит 2:** Добавьте тестовые данные в `tests/test_validator.py`:

```python
def test_validate_phone():
    assert validate_phone("+79991234567") == True
    assert validate_phone("89991234567") == False
    assert validate_phone("+7999123") == False
```

```bash
git add tests/test_validator.py
git commit -m "test: add phone validation tests"
```

**Коммит 3:** Добавьте заготовку для будущей функции (WIP):

```python
def validate_inn(inn: str) -> bool:
    """TODO: валидация ИНН."""
    pass
```

```bash
git add validator.py
git commit -m "wip: start INN validation"
```

**Коммит 4:** Исправьте опечатку в комментарии:

```python
# Было: "Валидация расийского номера"
# Стало: "Валидация российского номера"
```

```bash
git add validator.py
git commit -m "fix: typo in phone validation docstring"
```

**Шаг 2.4.** Проверьте «грязную» историю:

```bash
git log --oneline -4
```

Вы должны увидеть 4 коммита, включая `wip` и `fix: typo`.

✅ **Отчёт:** Скриншот вывода `git log --oneline -4` с «грязной» историей.

---

### Задание 3. Interactive rebase и squash ( ~15 минут)

**Шаг 3.1.** Выполните interactive rebase для последних 4 коммитов:

```bash
git rebase -i HEAD~4
```

**Шаг 3.2.** В открывшемся редакторе отредактируйте список так:

```
pick   xxxxxxx feat: add phone validation function
fixup  xxxxxxx test: add phone validation tests
fixup  xxxxxxx fix: typo in phone validation docstring
drop   xxxxxxx wip: start INN validation
```

> 💡 **Подсказка:** `fixup` приклеивает коммит к предыдущему, отбрасывая его сообщение. `drop` удаляет коммит полностью.

**Шаг 3.3.** Сохраните и закройте редактор. Проверьте результат:

```bash
git log --oneline -3
```

Ожидаемый результат — **один чистый коммит**:
```
xxxxxxx feat: add phone validation function
```

**Шаг 3.4.** Убедитесь, что код сохранился корректно:

```bash
cat validator.py
cat tests/test_validator.py
```

В `validator.py` должна быть функция `validate_phone` с правильным комментарием, но **не должно** быть функции `validate_inn` (она была в drop-нутом коммите).

✅ **Отчёт:** Скриншот чистой истории (`git log --oneline -3`) и скриншот содержимого `validator.py`.

---

### Задание 4. Разрешение merge-конфликта ( ~20 минут)

**Шаг 4.1.** Получите последние изменения из upstream (включая ветку преподавателя с конфликтом):

```bash
git fetch upstream
```

**Шаг 4.2.** Попробуйте смержить ветку преподавателя в свою feature-ветку:

```bash
git merge upstream/feature/instructor-change
```

**Ожидаемый результат:** Git сообщит о конфликте:
```
CONFLICT (content): Merge conflict in validator.py
Automatic merge failed; fix conflicts and then commit the result.
```

**Шаг 4.3.** Откройте `validator.py` в редакторе. Вы увидите маркеры конфликта:

```
<<<<<<< HEAD
...ваш код (validate_phone)...
=======
...код преподавателя (например, validate_snils)...
>>>>>>> upstream/feature/instructor-change
```

**Шаг 4.4.** **Ваша задача:**
1. Вручную объединить оба варианта в **один осмысленный файл** — должны остаться **обе** функции (и ваша `validate_phone`, и преподавателя `validate_snils`).
2. Удалить все маркеры (`<<<<<<<`, `=======`, `>>>>>>>`).
3. Сохранить файл.
4. Убедитесь, что Python-синтаксис корректен (нет лишних отступов, все скобки закрыты).

**Шаг 4.5.** Завершите merge:

```bash
git add validator.py
git commit -m "merge: resolve conflict with instructor branch"
```

**Шаг 4.6.** Проверьте, что обе функции присутствуют:

```bash
grep -E "def validate_" validator.py
```

Ожидаемый вывод:
```
def validate_email(email: str) -> bool:
def validate_phone(phone: str) -> bool:
def validate_snils(snils: str) -> bool:
```

✅ **Отчёт:** Скриншот файла `validator.py` с маркерами конфликта (до разрешения) и финальный вид файла.

---

### Задание 5. Pull Request и финальный push ( ~15 минут)

**Шаг 5.1.** Отправьте свою ветку в origin:

```bash
git push origin feature/add-phone-validation
```

**Шаг 5.2.** Откройте Gitverse. Создайте Pull Request из вашей ветки `feature/add-phone-validation` в `main` вашего форка.

**Шаг 5.3.** Заполните PR:
- **Title:** `feat: add phone validation`
- **Description:**
  ```markdown
  ## Что сделано
  - Добавлена функция `validate_phone` для валидации российских номеров
  - Добавлены тесты для новой функции
  - Разрешён merge-конфликт с веткой `feature/instructor-change`
  
  ## Чек-лист
  - [x] История коммитов очищена через interactive rebase
  - [x] Все тесты проходят локально
  - [x] Конфликт разрешён осмысленно (обе функции сохранены)
  ```
- Нажмите **Create pull request**.

**Шаг 5.4.** Смерджите PR через **Squash and merge** (чтобы в `main` попал один чистый коммит).

**Шаг 5.5.** Удалите feature-ветку через Gitverse.

**Шаг 5.6.** Обновите локальную `main` и запушьте в **оба remote** одной командой:

```bash
git checkout main
git pull origin main
git push origin main
```

**Шаг 5.7.** Откройте **оба** репозитория (основной и mirror) в браузере и убедитесь, что коммит merge появился в обоих.

✅ **Отчёт:**
1. Ссылка на смерженный PR.
2. Скриншоты обоих репозиториев (основной и mirror), подтверждающие наличие коммита.
3. Скриншот финальной истории `git log --oneline --graph -5`.

---

## 🏁 Защита контрольной работы 

**Структура защиты:**

1. **Демонстрация результата:**
   - Открыть репозиторий на Gitverse.
   - Показать чистую историю коммитов (`git log --oneline --graph`).
   - Показать смерженный PR.
   - Открыть оба remote (основной и mirror) и показать, что коммиты синхронизированы.

2. **Ответы на вопросы преподавателя (3–5 вопросов из списка ниже).**

### 📝 Контрольные вопросы для устной защиты

1. В чём разница между `git merge` и `git rebase`? Когда что использовать?
2. Почему нельзя делать `rebase` публичных веток?
3. Что делает команда `git rebase -i HEAD~5`? Перечислите действия: `pick`, `reword`, `squash`, `fixup`, `drop`.
4. Чем `squash` отличается от `fixup`?
5. Что такое `cherry-pick` и в каком сценарии он полезен?
6. Как восстановить коммит, который был «потерян» после `git reset --hard`?
7. Чем `git revert` отличается от `git reset --hard`?
8. Как добавить второй remote и настроить push в оба репозитория одной командой?
9. Что такое upstream и зачем он нужен при работе с форками?
10. Опишите Gitverse Flow своими словами.

---

## 🏠 Домашнее задание (подготовка к Блоку 2)


1. **Установить VirtualBox** (если ещё не установлен):
   - Скачать с [virtualbox.org](https://www.virtualbox.org/).
   - Убедиться, что в BIOS включена виртуализация (VT-x / AMD-V).

2. **Скачать образ Ubuntu Server 22.04**:
   - [Официальная ссылка](https://ubuntu.com/download/server).
   - Размер: ~1.5 GB.

3. **Повторить основы Linux** (будет нужно на занятии 5):
   - Прочитать: [Основы командной строки Linux](https://git-scm.com/book/ru/v2).
   - Повторить команды: `ls`, `cd`, `pwd`, `mkdir`, `rm`, `cp`, `mv`, `cat`, `nano`, `sudo`.

4. **Подготовиться к лекции по SSH и DNS:**
   - Прочитать: [Протокол SSH — Википедия](https://ru.wikipedia.org/wiki/SSH).
   - Понять разницу между симметричным и асимметричным шифрованием.

---

## 📖 Сводка полезных ссылок

| Тема | Ссылка |
|---|---|
| Pro Git Book (рус.) | [git-scm.com/book/ru/v2](https://git-scm.com/book/ru/v2) |
| Gitverse Docs — Fork a Repo | [docs.gitverse.ru/ru/pull-requests/collaborating-with-pull-requests/working-with-forks/fork-a-repo](https://docs.gitverse.ru/ru/pull-requests/collaborating-with-pull-requests/working-with-forks/fork-a-repo) |
| Gitverse Docs — About Pull Requests | [docs.gitverse.ru/ru/pull-requests](https://docs.gitverse.ru/ru/pull-requests) |
| Git Docs — git-rebase | [git-scm.com/docs/git-rebase](https://git-scm.com/docs/git-rebase) |
| Conventional Commits | [conventionalcommits.org/ru](https://www.conventionalcommits.org/ru/) |
| GitLab Docs — SSH keys | [docs.gitlab.com/ee/user/ssh.html](https://docs.gitlab.com/ee/user/ssh.html) |