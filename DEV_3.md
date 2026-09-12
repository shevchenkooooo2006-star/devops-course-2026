|||
|---|---|
|ДИСЦИПЛИНА|Инструменты девопс|
|ИНСТИТУТ|ИПТИП|
|КАФЕДРА|Индустриального программирования|
|ВИД УЧЕБНОГО МАТЕРИАЛА|Методические указания к практическим занятиям|
|ПРЕПОДАВАТЕЛЬ|Гиматдинов Дамир Маратович|
|СЕМЕСТР|5 семестр, 2026/2027 уч. год|

Ссылка на материал: <br>
https://gitverse.ru/dgimatdinov/DevOps_2026/content/master/DEV_3.md

# ПРАКТИЧЕСКАЯ РАБОТА №3
## Тема: Продвинутые техники Git. Rebase, Squash, конфликты и Multi-Remote

**Дисциплина:** DevOps-практикум  
**Курс:** 3  
**Занятие:** 3 из 16  
**Блок:** Git и GitHub (занятие 3 из 4)  
**Форма работы:** Индивидуальная  

---

## 🎯 Цель работы

1. Освоить разрешение merge-конфликтов в реальных сценариях.
2. Понять принципиальную разницу между `merge` и `rebase`, научиться осознанно выбирать стратегию.
3. Освоить `interactive rebase` для "причёсывания" истории коммитов.
4. Научиться работать с несколькими удалёнными репозиториями (multi-remote) — синхронизация между GitHub и GitLab.
5. Освоить продвинутые техники: `cherry-pick`, `reflog`, `revert`.

> ⚠️ **Важно:** Это занятие сложнее предыдущих. Здесь вы столкнётесь с ситуациями, которые в реальной работе случаются ежедневно. Внимательно читайте условия заданий и **не бойтесь ошибаться** — Git позволяет откатить почти любое действие.

---

## 📚 Теоретическая справка

### 1. Merge vs Rebase: вечный спор

Обе команды решают одну задачу — **интегрировать изменения из одной ветки в другую**, но делают это принципиально по-разному.

#### Merge (слияние)
Создаёт новый "merge-коммит", который объединяет две истории. История остаётся **нелинейной** — видно, что разработка шла параллельно.

```
main:    A───B───C───M (merge commit)
              ╲     ╱
feature:       D───E
```

**Плюсы:**
- Сохраняется полная история, ничего не теряется.
- Безопасно — не переписывает существующие коммиты.

**Минусы:**
- История становится "загаженной" merge-коммитами.
- При частых слияниях история превращается в "железную дорогу".

#### Rebase (перемещение)
"Пересаживает" ваши коммиты на верхушку другой ветки. История становится **линейной**, как будто вы работали последовательно.

```
До rebase:
main:    A───B───C
              ╲
feature:       D───E

После rebase feature на main:
main:    A───B───C
                      ╲
feature:               D'──E' (новые коммиты)
```

**Плюсы:**
- Чистая, линейная история.
- Легко читать `git log`.

**Минусы:**
- **Переписывает историю** — нельзя делать с коммитами, которые уже запушены и с которыми работают другие.
- Золотое правило: **`never rebase public branches`** (никогда не делайте rebase публичных веток).

📖 **Для изучения:**
- [Пожалуйста, перестаньте рекомендовать Git Flow (Хабр)](https://habr.com/ru/companies/flant/articles/491320/)
- [Pro Git Book — Переписывание истории](https://git-scm.com/book/ru/v2/Инструменты-Git-Переписывание-истории)

### 2. Squash — объединение коммитов

Squash — это операция, которая **объединяет несколько коммитов в один**. Используется, когда вы сделали много "рабочих" коммитов (WIP, fix, oops), но в `main` хотите видеть один чистый коммит.

**Пример:**
```
До squash:
1. feat: start working on auth
2. fix: typo
3. wip: almost done
4. fix: forgot to save
5. feat: finish auth

После squash:
1. feat: implement authentication module
```

### 3. Interactive Rebase (`git rebase -i`)

Мощнейший инструмент для переписывания истории. Позволяет:
- Объединять коммиты (squash, fixup).
- Переупорядочивать коммиты.
- Редактировать сообщения коммитов (reword).
- Разделять коммиты (split).
- Удалять коммиты (drop).

### 4. Multi-Remote — работа с несколькими удалёнными репозиториями

В реальной работе один и тот же код часто должен жить в нескольких местах:
- **Основной репозиторий** (например, на GitHub) — для команды.
- **Зеркало (mirror)** (например, на GitLab) — для бэкапа или для другой команды.
- **Fork** — для участия в OpenSource.

Git позволяет добавить **несколько remote** и пушить в них по отдельности или одновременно.

### 5. Разрешение конфликтов

Конфликт возникает, когда **две стороны изменили одну и ту же строку** в файле, и Git не может понять, чьи изменения принять.

**Маркеры конфликта в файле:**
```
<<<<<<< HEAD
Это изменения из текущей ветки
=======
Это изменения из ветки, которую мы вливаем
>>>>>>> feature-branch
```

Вам нужно **вручную** выбрать, что оставить, и удалить маркеры.

---

## 💻 Практическая часть

### 📁 Структура сквозного проекта

К этому моменту у вас должен быть репозиторий `devops-course-2026` с файлами:
- `about_me.md`
- `hobby.md`
- `ide_notes.md`
- `svn_comparison.md`
- `goals.md`
- `README.md`

Сегодня мы добавим в него **Python-скрипт**, который станет основой для следующих блоков (Docker, CI/CD, деплой).

---

### Задание 1. Разрешение merge-конфликтов

**Цель:** Научиться разрешать конфликты осознанно, а не паниковать.

**Шаг 1.1.** Убедитесь, что вы в ветке `main` и она актуальна:

```bash
git checkout main
git pull origin main
```

**Шаг 1.2.** Создайте **две параллельные ветки**, которые будут конфликтовать:

```bash
# Ветка 1: изменяем README.md
git checkout -b conflict/readme-update-1
```

Откройте `README.md` и замените его содержимое на:

```markdown
# DevOps Course 2026

Репозиторий для практических работ по курсу DevOps.

## Студент
ФИО: [ваше ФИО]
Группа: [ваша группа]

## Описание
Учебный проект для освоения инструментов DevOps.
```

Закоммитьте:

```bash
git add README.md
git commit -m "docs: update README with student info (variant 1)"
```

**Шаг 1.3.** Вернитесь в `main` и создайте **вторую ветку**:

```bash
git checkout main
git checkout -b conflict/readme-update-2
```

Откройте `README.md` и замените его содержимое на **другой вариант**:

```markdown
# DevOps Course 2026

Учебный репозиторий курса "Инструменты DevOps".

## Автор
[ваше ФИО], группа [ваша группа]

## Стек
- Git / GitHub
- Python
- Docker (скоро)
```

Закоммитьте:

```bash
git add README.md
git commit -m "docs: update README with student info (variant 2)"
```

**Шаг 1.4.** Попробуйте смержить вторую ветку в первую:

```bash
git checkout conflict/readme-update-1
git merge conflict/readme-update-2
```

**Ожидаемый результат:** Git сообщит о конфликте:
```
CONFLICT (content): Merge conflict in README.md
Automatic merge failed; fix conflicts and then commit the result.
```

**Шаг 1.5.** Откройте `README.md` в любом редакторе. Вы увидите маркеры конфликта:

```
<<<<<<< HEAD
...ваш первый вариант...
=======
...ваш второй вариант...
>>>>>>> conflict/readme-update-2
```

**Ваша задача:**
1. Вручную объединить оба варианта в **один осмысленный документ** (не просто удалить один из вариантов, а взять лучшее из обоих).
2. Удалить все маркеры (`<<<<<<<`, `=======`, `>>>>>>>`).
3. Сохранить файл.

**Шаг 1.6.** Завершите merge:

```bash
git add README.md
git commit -m "merge: resolve conflict in README.md"
```

**Шаг 1.7.** Удалите временные ветки:

```bash
git checkout main
git branch -D conflict/readme-update-1
git branch -D conflict/readme-update-2
```

✅ **Отчёт по заданию 1:** Скриншот файла `README.md` с маркерами конфликта (до разрешения) и финальный вид файла.

---

### Задание 2. Rebase vs Merge — сравнение на практике 

**Цель:** Увидеть разницу в истории после `merge` и после `rebase`.

#### Часть А: Merge

**Шаг 2А.1.** Создайте feature-ветку от `main`:

```bash
git checkout -b demo/merge-example
```

**Шаг 2А.2.** Сделайте 2 коммита в этой ветке:

```bash
# Коммит 1
echo "# Feature A" > feature_a.md
git add feature_a.md
git commit -m "feat: add feature A description"

# Коммит 2
echo "## Details" >> feature_a.md
echo "- Point 1" >> feature_a.md
git add feature_a.md
git commit -m "docs: add details for feature A"
```

**Шаг 2А.3.** Вернитесь в `main` и смержите через **merge**:

```bash
git checkout main
git merge demo/merge-example -m "merge: integrate feature A"
```

**Шаг 2А.4.** Посмотрите историю:

```bash
git log --oneline --graph --all -10
```

Обратите внимание на **"галочку"** merge-коммита — это слияние двух линий истории.

#### Часть Б: Rebase

**Шаг 2Б.1.** Откатите `main` на один коммит назад (до merge):

```bash
git reset --hard HEAD~1
```

> ⚠️ **Внимание:** `--hard` удаляет изменения безвозвратно! Но у нас есть ветка `demo/merge-example`, так что мы ничего не теряем. Это демонстрация силы `reflog` — если бы мы потеряли что-то важное, можно было бы восстановить через `git reflog`.

**Шаг 2Б.2.** Теперь сделаем то же самое, но через **rebase**:

```bash
git checkout demo/merge-example
git rebase main
```

**Шаг 2Б.3.** Вернитесь в `main` и смержите (теперь это будет fast-forward):

```bash
git checkout main
git merge demo/merge-example
```

**Шаг 2Б.4.** Посмотрите историю:

```bash
git log --oneline --graph --all -10
```

**Обратите внимание:** история стала **линейной**, без merge-коммита.

**Шаг 2Б.5.** Удалите временную ветку:

```bash
git branch -D demo/merge-example
```

✅ **Отчёт по заданию 2:** Два скриншота вывода `git log --graph` — после merge и после rebase. Под каждым скриншотом напишите 1-2 предложения, в чём разница.

---

### Задание 3. Interactive Rebase — «причёсывание» истории 

**Цель:** Научиться превращать хаотичную историю коммитов в чистую и осмысленную.

**Сценарий:** Вы разрабатывали Python-скрипт для сквозного проекта и делали коммиты «как попало» — с опечатками, WIP-коммитами и фиксами. Теперь перед merge в `main` нужно привести историю в порядок.

**Шаг 3.1.** Создайте ветку и симулируйте «грязную» историю разработки:

```bash
git checkout -b feature/calculator
```

Последовательно выполните следующие команды, создавая файлы и коммиты **именно в таком порядке** (задание выполняем в терминале, например, Git Bash):

```bash
# Коммит 1: начало работы
cat > calculator.py << 'EOF'
# Calculator app
def add(a, b):
    return a + b
EOF
git add calculator.py
git commit -m "start calculator"

# Коммит 2: опечатка в сообщении + мелкое изменение
echo "# TODO: add more functions" >> calculator.py
git add calculator.py
git commit -m "wip"

# Коммит 3: добавление функции
cat >> calculator.py << 'EOF'

def subtract(a, b):
    return a - b
EOF
git add calculator.py
git commit -m "add subtract"

# Коммит 4: фикс опечатки в предыдущем коммите
sed -i 's/return a - b/return a - b  # fixed/' calculator.py
git add calculator.py
git commit -m "fix typo in subtract"

# Коммит 5: документация
cat > README_CALC.md << 'EOF'
# Calculator
Простой калькулятор на Python.
EOF
git add README_CALC.md
git commit -m "add docs"

# Коммит 6: ещё один WIP
echo "" >> calculator.py
git add calculator.py
git commit -m "oops"
```

**Шаг 3.2.** Посмотрите на «грязную» историю:

```bash
git log --oneline -6
```

Вы увидите что-то вроде:
```
a1b2c3d oops
e4f5g6h add docs
i7j8k9l fix typo in subtract
m0n1o2p add subtract
q3r4s5t wip
u6v7w8x start calculator
```

**Шаг 3.3.** Запустите interactive rebase для последних 6 коммитов:

```bash
git rebase -i HEAD~6
```

Откроется текстовый редактор (VS Code или nano/vim) со списком коммитов:

```
pick u6v7w8x start calculator
pick q3r4s5t wip
pick m0n1o2p add subtract
pick i7j8k9l fix typo in subtract
pick e4f5g6h add docs
pick a1b2c3d oops
```

**Шаг 3.4.** Ваша задача — отредактировать этот список так:

| Исходный коммит | Действие | Почему |
|---|---|---|
| `start calculator` | `reword` → изменить сообщение на `feat: implement add function` | Нормальное сообщение, но нужно точнее |
| `wip` | `fixup` (приклеить к предыдущему) | Бессмысленный коммит, его содержимое полезно, но сообщение — нет |
| `add subtract` | `pick` (оставить как есть, но reword → `feat: implement subtract function`) | Полезный коммит |
| `fix typo in subtract` | `fixup` (приклеить к `add subtract`) | Это исправление ошибки в предыдущем коммите, должно быть частью него |
| `add docs` | `pick` (оставить, reword → `docs: add calculator README`) | Полезный коммит |
| `oops` | `drop` (удалить) | Пустой/бессмысленный коммит |

Итоговый план в редакторе должен выглядеть примерно так:

```
reword u6v7w8x start calculator
fixup  q3r4s5t wip
reword m0n1o2p add subtract
fixup  i7j8k9l fix typo in subtract
reword e4f5g6h add docs
drop   a1b2c3d oops
```

> 💡 **Подсказка для nano:** навигация стрелками, редактирование как в обычном тексте. Сохранить: `Ctrl+O`, `Enter`, выйти: `Ctrl+X`.
> 💡 **Подсказка для VS Code:** просто отредактируйте текст и закройте вкладку (`Ctrl+S`, `Ctrl+W`).

**Шаг 3.5.** После сохранения Git попросит вас ввести новые сообщения для `reword`-коммитов. Введите:
1. `feat: implement add function`
2. `feat: implement subtract function`
3. `docs: add calculator README`

**Шаг 3.6.** Проверьте результат:

```bash
git log --oneline -5
```

Ожидаемый результат — **3 чистых коммита**:
```
xxx docs: add calculator README
xxx feat: implement subtract function
xxx feat: implement add function
```

**Шаг 3.7.** Проверьте, что файл `calculator.py` содержит обе функции (add и subtract с комментарием `# fixed`):

```bash
cat calculator.py
```

✅ **Отчёт по заданию 3:**
1. Скриншот «грязной» истории (`git log --oneline -6`) **до** rebase.
2. Скриншот чистой истории (`git log --oneline -3`) **после** rebase.
3. Скриншот содержимого `calculator.py`.

---

### Задание 4. Multi-Remote — синхронизация между GitHub и GitLab

**Цель:** Научиться работать с несколькими удалёнными репозиториями. Это реальный сценарий: основной репозиторий на GitHub, зеркало (backup/mirror) на GitLab.

**Шаг 4.1.** Создайте второй репозиторий (mirror):
- На **gitlab.com** (или на GitHub): создайте новый **пустой** репозиторий `devops-course-2026-mirror`.
- **Не** добавляйте README, .gitignore, license — он должен быть абсолютно пустым.

**Шаг 4.2.** Настройте SSH-ключ для GitLab (если используете gitlab.com):

```bash
# Проверьте, есть ли уже ключ
ls ~/.ssh/id_ed25519.pub

# Если используете тот же ключ, просто добавьте его в GitLab:
# Settings → SSH Keys → Add new key → Вставьте содержимое ~/.ssh/id_ed25519.pub

# Проверьте подключение
ssh -T git@gitlab.com
# Ожидаемый ответ: Welcome to GitLab, @username!
```

📖 **Документация:** [GitLab Docs — SSH keys](https://docs.gitlab.com/ee/user/ssh.html)

**Шаг 4.3.** Посмотрите текущие remote в вашем репозитории:

```bash
git remote -v
```

Вы увидите что-то вроде:
```
origin  git@github.com:ваш_username/devops-course-2026.git (fetch)
origin  git@github.com:ваш_username/devops-course-2026.git (push)
```

**Шаг 4.4.** Добавьте второй remote:

```bash
# Для GitLab:
git remote add gitlab git@gitlab.com:ваш_username/devops-course-2026-mirror.git

# Для GitHub-mirror:
# git remote add mirror git@github.com:ваш_username/devops-course-2026-mirror.git
```

**Шаг 4.5.** Проверьте:

```bash
git remote -v
```

Теперь должно быть **два remote**:
```
gitlab  git@gitlab.com:ваш_username/devops-course-2026-mirror.git (fetch)
gitlab  git@gitlab.com:ваш_username/devops-course-2026-mirror.git (push)
origin  git@github.com:ваш_username/devops-course-2026.git (fetch)
origin  git@github.com:ваш_username/devops-course-2026.git (push)
```

**Шаг 4.6.** Отправьте все ветки и теги в зеркало:

```bash
git push gitlab --all
git push gitlab --tags
```

**Шаг 4.7.** Настройте **автоматический push в оба remote** одной командой. Для этого добавьте дополнительный push-URL к `origin`:

```bash
git remote set-url --add --push origin git@gitlab.com:ваш_username/devops-course-2026-mirror.git
```

Проверьте:

```bash
git remote -v
```

Теперь `origin` при `push` будет отправлять в **оба** репозитория:
```
origin  git@github.com:ваш_username/devops-course-2026.git (fetch)
origin  git@github.com:ваш_username/devops-course-2026.git (push)
origin  git@gitlab.com:ваш_username/devops-course-2026-mirror.git (push)
```

**Шаг 4.8.** Проверьте, что это работает. Сделайте тестовый коммит:

```bash
echo "# Multi-remote test" >> README.md
git add README.md
git commit -m "chore: test multi-remote push"
git push origin main
```

Откройте **оба** репозитория в браузере и убедитесь, что коммит появился в обоих.

**Шаг 4.9.** (Продвинутый уровень) Настройте **fetch из обоих remote** и сравните истории:

```bash
git fetch --all
git log --oneline --graph --all --remotes -10
```

✅ **Отчёт по заданию 4:**
1. Скриншот вывода `git remote -v` с двумя remote.
2. Скриншоты обоих репозиториев в браузере, подтверждающие, что коммит `chore: test multi-remote push` есть в обоих.

---

### Задание 5. Cherry-pick, Reflog и Revert — «машина времени» Git

**Цель:** Освоить инструменты для работы с историей, которые спасают в критических ситуациях.

#### Часть А: Cherry-pick (выборочное применение коммита)

**Сценарий:** Вы сделали полезное исправление в одной ветке, но оно срочно нужно в `main`, а всю ветку мерджить пока рано.

**Шаг 5А.1.** Создайте ветку с несколькими коммитами:

```bash
git checkout -b hotfix/urgent-fix
```

```bash
# Коммит 1: полезный фикс
echo "IMPORTANT_FIX = True" >> calculator.py
git add calculator.py
git commit -m "fix: critical bug in calculator"

# Коммит 2: экспериментальная фича (не готова для main)
cat >> calculator.py << 'EOF'

def multiply(a, b):
    return a * b

def divide(a, b):
    if b == 0:
        raise ValueError("Cannot divide by zero")
    return a / b
EOF
git add calculator.py
git commit -m "feat: add multiply and divide (experimental)"
```

**Шаг 5А.2.** Запомните хеш первого коммита (фикса):

```bash
git log --oneline -2
```

Скопируйте хеш коммита `fix: critical bug in calculator` (например, `abc1234`).

**Шаг 5А.3.** Переключитесь в `main` и примените **только** этот коммит:

```bash
git checkout main
git cherry-pick abc1234
```

**Шаг 5А.4.** Проверьте, что в `main` появилась строка `IMPORTANT_FIX = True`, но **нет** функций `multiply` и `divide`:

```bash
cat calculator.py
git log --oneline -3
```

#### Часть Б: Reflog (восстановление «потерянного»)

**Сценарий:** Вы случайно удалили ветку или сделали `reset --hard` и потеряли коммиты. `reflog` — это «чёрный ящик» Git, который помнит всё.

**Шаг 5Б.1.** Сделайте коммит, который вы «случайно потеряете»:

```bash
git checkout -b temp/lost-branch
echo "# This is important data" > important_data.md
git add important_data.md
git commit -m "feat: add very important data"
```

Запомните хеш этого коммита.

**Шаг 5Б.2.** «Случайно» удалите ветку:

```bash
git checkout main
git branch -D temp/lost-branch
```

Файл `important_data.md` исчез. Ветка удалена. Кажется, что данные потеряны.

**Шаг 5Б.3.** Используйте `reflog`, чтобы найти потерянный коммит:

```bash
git reflog
```

Найдите в списке строку с `feat: add very important data` и скопируйте её хеш.

**Шаг 5Б.4.** Восстановите коммит:

```bash
git checkout -b temp/recovered-branch <хеш_из_reflog>
cat important_data.md
```

Файл на месте! Данные восстановлены.

**Шаг 5Б.5.** Удалите восстановленную ветку (она больше не нужна для демонстрации):

```bash
git checkout main
git branch -D temp/recovered-branch
```

#### Часть В: Revert (безопасный откат)

**Сценарий:** В `main` попал коммит, который сломал функциональность. Нужно откатить его, но **без переписывания истории** (потому что `main` — публичная ветка).

**Шаг 5В.1.** Сделайте «вредный» коммит в `main`:

```bash
echo "BROKEN_CODE = True  # this breaks everything" >> calculator.py
git add calculator.py
git commit -m "feat: add new feature (accidentally broken)"
```

**Шаг 5В.2.** «Осознайте» ошибку и откатите коммит через `revert`:

```bash
git revert HEAD
```

Git откроет редактор с предзаполненным сообщением `Revert "feat: add new feature (accidentally broken)"`. Сохраните и закройте.

**Шаг 5В.3.** Проверьте:

```bash
git log --oneline -3
cat calculator.py
```

Вы увидите:
- Строка `BROKEN_CODE` **исчезла** из файла.
- В истории появился **новый коммит** `Revert "..."` — история не переписана, а дополнена.

> 💡 **Ключевое отличие:** `git reset --hard HEAD~1` удалил бы коммит из истории (опасно для публичных веток), а `git revert` создаёт новый коммит, который отменяет изменения (безопасно).

✅ **Отчёт по заданию 5:**
1. **Cherry-pick:** скриншот `git log --oneline -3` в `main`, показывающий, что cherry-pick коммит появился, и скриншот `cat calculator.py`, подтверждающий, что экспериментальных функций нет.
2. **Reflog:** скриншот вывода `git reflog` с выделенным потерянным коммитом и скриншот восстановленного файла `important_data.md`.
3. **Revert:** скриншот `git log --oneline -3` с revert-коммитом и скриншот `cat calculator.py` без `BROKEN_CODE`.

---

### 🏆 Бонусное задание

**Git Hooks: pre-commit проверка**

Настройте Git hook, который **не даст сделать коммит**, если в сообщении нет префикса по Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `merge:`).

```bash
# Создайте файл .git/hooks/commit-msg
cat > .git/hooks/commit-msg << 'HOOK'
#!/bin/bash
commit_msg=$(cat "$1")
pattern="^(feat|fix|docs|chore|refactor|merge|test|ci|build|perf|style)(\(.+\))?: .+"

if ! echo "$commit_msg" | grep -qE "$pattern"; then
    echo "❌ ОШИБКА: Сообщение коммита не соответствует Conventional Commits."
    echo "   Ожидаемый формат: <type>: <description>"
    echo "   Примеры: feat: add login, fix: typo in header, docs: update README"
    echo "   Ваше сообщение: $commit_msg"
    exit 1
fi
HOOK

chmod +x .git/hooks/commit-msg
```

Проверьте:

```bash
# Это должно ЗАБЛОКИРОВАТЬСЯ:
echo "test" >> test_hook.txt
git add test_hook.txt
git commit -m "bad message"
# Ожидается ошибка от hook

# Это должно ПРОЙТИ:
git commit -m "chore: test git hook"
# Ожидается успешный коммит
```

✅ **Отчёт по бонусу:** Скриншот заблокированного коммита с ошибкой от hook и скриншот успешного коммита.

---

## 🏠 Домашнее задание (подготовка к контрольной работе №4)

### Теория
1. Прочитайте: [Forking Workflow — как у Linux (Хабр)](https://habr.com/ru/companies/jugru/articles/421757/)
2. Повторите все команды, изученные на занятиях 1–3.

### Практика
1. **Подготовка к КР:** Создайте ветку `prep/kr-practice` и выполните в ней полный цикл:
   - Создайте файл `kr_prep.md` и напишите в нём ответы на 3 вопроса:
     - *«Когда я выберу rebase, а когда merge? Почему?»*
     - *«Что произойдёт, если я сделаю rebase публичной ветки, с которой работают коллеги?»*
     - *«Зачем нужен multi-remote и в каких реальных сценариях он применяется?»*
   - Сделайте 3 коммита (намеренно «грязных»).
   - Сделайте interactive rebase и объедините их в один чистый коммит.
   - Запушьте результат.
2. **Повторите** разрешение конфликтов: создайте две ветки, измените один и тот же файл, попробуйте смержить и разрешите конфликт.

### Подготовка к КР (Занятие 4)
Контрольная работа будет **практической** и **индивидуальной**. Вам нужно будет:
- Форкнуть репозиторий преподавателя.
- Создать feature-ветку.
- Сделать несколько коммитов.
- Выполнить rebase на обновлённый `main`.
- Squash коммитов.
- Создать Pull Request.
- Разрешить merge-конфликт (преподаватель намеренно его создаст).
- Сделать revert коммита.
- Запушить в два remote.

---

## ❓ Контрольные вопросы (для самопроверки)

1. В чём принципиальная разница между `merge` и `rebase`? Когда что использовать?
2. Почему нельзя делать `rebase` публичных веток? Что произойдёт, если нарушить это правило?
3. Что делает команда `git rebase -i HEAD~5`? Перечислите все доступные действия (pick, reword, edit, squash, fixup, drop).
4. Чем `squash` отличается от `fixup` при interactive rebase?
5. Что такое `cherry-pick` и в каком сценарии он полезен?
6. Как восстановить коммит, который был «потерян» после `git reset --hard` или удаления ветки?
7. Чем `git revert` отличается от `git reset --hard`? Почему для публичных веток нужно использовать именно `revert`?
8. Как добавить второй remote и настроить push в оба репозитория одной командой?
9. Что такое Git hooks? Приведите пример полезного pre-commit hook.
10. Опишите Forking Workflow. Чем он отличается от GitHub Flow?

---

## 📖 Сводка полезных ссылок

| Тема | Ссылка |
|---|---|
| Pro Git Book (рус.) — Переписывание истории | [git-scm.com/book/ru/v2](https://git-scm.com/book/ru/v2/Инструменты-Git-Переписывание-истории) |
| Merge vs Rebase (Хабр) | [habr.com/ru/companies/flant/articles/491320](https://habr.com/ru/companies/flant/articles/491320/) |
| Conventional Commits | [conventionalcommits.org/ru](https://www.conventionalcommits.org/ru/) |
| GitLab Docs — SSH keys | [docs.gitlab.com/ee/user/ssh](https://docs.gitlab.com/ee/user/ssh.html) |
| GitHub Docs — Managing remotes | [docs.github.com/ru/get-started/getting-started-with-git/managing-remote-repositories](https://docs.github.com/ru/get-started/getting-started-with-git/managing-remote-repositories) |
| Git Hooks (Pro Git) | [git-scm.com/book/ru/v2/Настройка-Git-Хуки-в-Git](https://git-scm.com/book/ru/v2/Настройка-Git-Хуки-в-Git) |
| Forking Workflow (Хабр) | [habr.com/ru/companies/jugru/articles/421757](https://habr.com/ru/companies/jugru/articles/421757/) |

---