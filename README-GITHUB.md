# Remnawave Node — установка на Ubuntu 24.04

Интерактивная установка Remnawave Node, Caddy и сайта с выбором NORTH / STILL / RITUAL. В каждом шаблоне — пять статей. Автономное оформление, ротация логов, UFW с проверкой SSH, Fail2ban и штатный BBR при поддержке системы.

> Сначала проверьте комплект на одноразовой Ubuntu 24.04 со snapshot и доступом к консоли провайдера. Новая версия не прошла полноценную интеграционную установку Linux/Docker/ACME/Fail2ban. Автотесты не заменяют эту проверку.

## Быстрый запуск

**Вставьте весь блок целиком в терминал нового сервера Ubuntu 24.04.** Тег или Release не требуется: архив загружается из ветки `main`, проверяется по фиксированному SHA-256 и только затем распаковывается.

```bash
sudo bash -c '
set -Eeuo pipefail
umask 077

URL="https://raw.githubusercontent.com/tropka2020/remnanode-ubuntu-installer/main/remnanode-ubuntu24-premium-v2.zip"
SHA="5ec1700d48fb4f4cfe5fef5150e384614c1c2845bbec564b4b3cdb60f6a7c7a8"
TARGET="/opt/remnanode-local"

[ "$(id -u)" -eq 0 ] || { printf "Требуются права root.\n" >&2; exit 1; }
command -v curl >/dev/null || { printf "Сначала установите curl: apt-get update && apt-get install -y curl\n" >&2; exit 1; }
command -v python3 >/dev/null || { printf "Требуется Python 3.\n" >&2; exit 1; }

if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
    printf "Каталог %s уже существует. Ничего не перезаписано.\n" "$TARGET" >&2
    exit 1
fi

WORK="$(mktemp -d /opt/.remnanode-download.XXXXXX)"
trap '\''rm -rf -- "$WORK"'\'' EXIT

printf "\n[1/4] Скачивание архива\n"
curl -fSL --proto "=https" --proto-redir "=https" \
    --connect-timeout 15 --max-time 300 --retry 3 \
    "$URL" -o "$WORK/installer.zip"

printf "\n[2/4] Проверка SHA-256\n"
printf "%s  %s\n" "$SHA" "$WORK/installer.zip" | sha256sum -c -

printf "\n[3/4] Распаковка и проверка файлов\n"
python3 -m zipfile -e "$WORK/installer.zip" "$WORK"
(
    cd "$WORK/remnanode-local"
    sha256sum -c SHA256SUMS
)

if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
    printf "Каталог назначения появился во время загрузки. Ничего не заменено.\n" >&2
    exit 1
fi
mv -T -- "$WORK/remnanode-local" "$TARGET"

printf "\n[4/4] Запуск мастера\n"
cd "$TARGET"
bash install-remnanode.sh
'
```

Если сервер уже открыт под `root`, наличие `sudo` в этой команде допустимо. Если `sudo` отсутствует, замените только начало `sudo bash -c` на `bash -c`.

**Не запускайте мастер повторно поверх установленной ноды.** Если каталог уже существует, не удаляйте его вслепую. При ошибке SHA-256 остановитесь: архив не соответствует проверенной версии.

## Что подготовить

- Новый Ubuntu 24.04 amd64/arm64 с systemd и Python 3.
- Не менее 2 ГиБ свободного места и 10000 inode перед большими загрузками; рекомендуется диск с запасом под ОС, Docker и обновления.
- Домен с A-записью прямо на сервер, без CDN/proxy. Текущий IPv4-мастер не принимает AAAA этого домена.
- IPv4 панели Remnawave и SECRET_KEY из формы добавления ноды.
- Доступ к консоли провайдера и рабочий SSH.
- Разрешённые у провайдера TCP/80, TCP/443 и SSH; API/2222 доступен только панели.

## Какие вопросы задаёт мастер

1. Домен.
2. IPv4 панели.
3. SECRET_KEY — ввод скрыт.
4. Шаблон: 1 — NORTH, 2 — STILL, 3 — RITUAL.
5. Подтверждение сводки словом `УСТАНОВИТЬ`.
6. После настройки UFW — проверка нового SSH-подключения и подтверждение `SSH РАБОТАЕТ`.

Автономный режим и название сайта выбираются автоматически. При недоступном BBR либо существующей чужой настройке Fail2ban выводится причина пропуска. Случайное оформление не гарантирует отсутствие повторов между серверами, нераспознаваемость VPN или прохождение сканеров.

## После установки

Профиль создаётся и назначается **в панели Remnawave**. Установщик сохраняет пример и памятку; без API-доступа ничего в панели не применяет. Публичный inbound/443 начнёт работать после применения профиля. Мастер проверяет Caddy backend локально на 127.0.0.1:9443.

```bash
selfsteal
```

Меню: статус, срок сертификата, запуск/остановка Caddy, проверка ACME, логи и смена шаблона.

```bash
selfsteal status
selfsteal logs --kind visits --lines 100
selfsteal logs --kind errors --lines 100
selfsteal template --template 1 --confirm
selfsteal template --template 2 --confirm
selfsteal template --template 3 --confirm
```

Смена шаблона создаёт резервную копию и кратковременно перезапускает Caddy. Нода, профиль и тома сертификатов не заменяются. BBR не снимает ограничения тарифа, CPU и маршрута; измерения скорости автоматически не запускаются.

## Обновление файла в репозитории

Архив в корне ветки `main` должен называться точно:

```text
remnanode-ubuntu24-premium-v2.zip
```

Текущий ожидаемый SHA-256:

```text
5ec1700d48fb4f4cfe5fef5150e384614c1c2845bbec564b4b3cdb60f6a7c7a8
```

При замене архива на другую сборку обновите и `SHA` в команде. Не отключайте проверку. Внутри архива находится полный комплект и собственный `SHA256SUMS`; секреты, приватные ключи, токены и индивидуальные отчёты серверов публиковать нельзя.
