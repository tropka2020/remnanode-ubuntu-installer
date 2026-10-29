# Remnawave Node — Ubuntu 24.04

Установщик Node, Caddy и восьми самостоятельных сайтов: NORTH, STILL, RITUAL, INDEX, FORM, AFTERLIGHT, COMMON и ORBIT. В каждом из восьми шаблонов — пять полных статей. Короткий мастер, автономное оформление, logrotate, UFW с проверкой SSH, новый Fail2ban jail и штатный BBR при поддержке ядра.

> Сначала испытайте сборку на одноразовой Ubuntu24.04 со snapshot и консолью провайдера. Автотесты не заменяют реальную проверку Docker/ACME/Fail2ban/nftables и изменения разделов.

## Первая установка на новом сервере из GitHub

В репозиторий нужно загрузить с точными именами `download-install.sh`, ZIP релиза и `prepare_fresh_install.py`. После загрузки ZIP вычислите его SHA256 и замените **оба заполнителя архива** (`ZIP_URL` и `ZIP_SHA`) ниже. Не подставляйте выдуманные URL или хеши: этот пример намеренно не запускается до публикации вашего ZIP. `HELPER_URL` и `HELPER_SHA` также замените на фактические URL/SHA опубликованного helper-файла.

**Весь блок ниже — одна команда.** Он скачивает helper отдельно, проверяет его SHA256, а затем запускает его с двумя аргументами — URL архива и SHA256 архива. Ответ helper не передаётся в shell через pipe.

```bash
sudo --preserve-env=SSH_CONNECTION bash -c '
set -Eeuo pipefail
umask 077
HELPER_URL="https://raw.githubusercontent.com/REPLACE_OWNER/REPLACE_REPOSITORY/REPLACE_REF/download-install.sh"
HELPER_SHA="REPLACE_AFTER_UPLOADING_DOWNLOAD_INSTALL_SH"
ZIP_URL="https://raw.githubusercontent.com/REPLACE_OWNER/REPLACE_REPOSITORY/REPLACE_REF/REPLACE_RELEASE_ZIP_NAME.zip"
ZIP_SHA="REPLACE_AFTER_UPLOADING_ZIP"
WORK="$(mktemp -d /opt/.remnanode-helper.XXXXXX)"
trap '\''rm -rf -- "$WORK"'\'' EXIT
command -v curl >/dev/null || { printf "Требуется curl.\n" >&2; exit 1; }
printf "Скачивание проверяемого helper\n"
curl --disable --fail --show-error --silent --location --proto "=https" --proto-redir "=https" \
  --connect-timeout 30 --max-time 60 --output "$WORK/download-install.sh" -- "$HELPER_URL"
printf "%s  %s\n" "$HELPER_SHA" "$WORK/download-install.sh" | sha256sum -c -
printf "Запуск helper с URL архива и SHA256 архива\n"
bash "$WORK/download-install.sh" "$ZIP_URL" "$ZIP_SHA"
'
```

Замените все `REPLACE_*` до вставки блока. `ZIP_SHA` — SHA256 именно загруженного ZIP, `HELPER_SHA` — SHA256 именно загруженного `download-install.sh`; это не SHA256 из внутреннего `SHA256SUMS`. Helper сам проверяет внешний SHA архива, безопасное содержимое ZIP и все внутренние контрольные суммы, после чего запускает wizard из `/opt/remnanode-local`.

Если вошли под root, а sudo отсутствует, замените только начало `sudo --preserve-env=SSH_CONNECTION bash -c` на `bash -c`.

## Повторная установка после ошибки

**Не предназначено для работающей ноды.** Сделайте snapshot, оставьте открытой SSH-сессию и консоль провайдера. Это не удаление Ubuntu/Docker и не форматирование диска.

Следующая команда скачивает маленький проверяемый скрипт. Он:

- отказывается при любых существующих Docker-контейнерах, включая остановленные;
- отказывается при активном UFW-rollback, активном/неизвестном Fail2ban, policy-rc.d или незавершённом dpkg;
- показывает точные пути и требует подтверждение `ПЕРЕНАЧАТЬ`;
- перемещает остатки `/opt/remnanode`, `/opt/caddy`, старый комплект `/opt/remnanode-local`, design state и распознанный selfsteal runtime в закрытую папку `/var/backups/remnanode-local/fresh-start-*`;
- **не удаляет** тома сертификатов, Docker, образы, пакеты, логи, старые backups и правила UFW.

```bash
sudo bash -c '
set -Eeuo pipefail
umask 077
URL="https://raw.githubusercontent.com/tropka2020/remnanode-ubuntu-installer/main/prepare_fresh_install.py"
SHA="873177f2c2777da93929e69ba59d7617237cc871924e087e93c6e6efde69a1a5"
WORK="$(mktemp -d /root/remnanode-reset.XXXXXX)"
printf "Скачивание проверяемой подготовки повторной установки…\n"
curl -fSL --proto "=https" --proto-redir "=https" --connect-timeout 15 --max-time 60 "$URL" -o "$WORK/prepare_fresh_install.py"
printf "%s  %s\n" "$SHA" "$WORK/prepare_fresh_install.py" | sha256sum -c -
python3 "$WORK/prepare_fresh_install.py" --apply
'
```

После сообщения **«Рабочие пути освобождены»** выполните команду из раздела **«Первая установка»**. Если скрипт отказал, остановитесь и изучите причину — не обходите проверки, не запускайте prune/reset.

Если хотите действительно полностью чистую ОС, это отдельное действие: переустановка Ubuntu в панели провайдера с потерей данных. Этот скрипт её не выполняет.

## Требования и диск

- Ubuntu24.04 amd64/arm64, systemd, Python3, root, рабочий SSH и консоль провайдера.
- Snapshot до изменения разделов/firewall.
- Домен с A-записью прямо на VPS, без CDN/proxy; в текущем IPv4-мастере AAAA не допускается.
- IPv4 панели и SECRET_KEY из формы добавления ноды.
- Firewall провайдера разрешает SSH, TCP80/443; API2222 только панели.
- Xray Torrent Blocker использует последний upstream installer `kutovoys/xray-torrent-blocker`, `/var/log/remnanode/access.log` и выбор `iptables`; его `/opt/tblocker/config.yaml` и systemd unit создаёт штатный upstream installer, а не наш код.

До вопросов мастер проверяет полный размер `/`. При >=6GiB раздел не меняется. При меньшем размере допускается авторасширение только подтверждённого прямого последнего ext4-раздела: уже выделенный диск должен предоставлять место для раздела >=15GiB, утилиты growpart/resize2fs должны быть установлены. План показывается до `УСТАНОВИТЬ`, изменение выполняется после подтверждения и lock до APT/Docker. Рост — до доступного конца, не ровно15GiB; на диске30GiB результат будет около30GiB. Создаётся приватный журнал и table dump. Автоматического сжатия, форматирования или дискового rollback нет.

LVM/RAID/шифрование/неизвестная схема и staleGPT не изменяются автоматически. Виртуальный диск у провайдера скрипт не увеличивает. Проверка свободного места остаётся предупреждением: запас2GiB рекомендуется, но нехватка не блокируется отдельным free-space порогом. Заполнение диска всё равно может вызвать ошибку APT/Docker.

## Вопросы и процесс

Мастер спрашивает четыре значения: домен, IPv4 панели, скрытый SECRET_KEY и тему 1–8 (1 NORTH, 2 STILL, 3 RITUAL, 4 INDEX, 5 FORM, 6 AFTERLIGHT, 7 COMMON, 8 ORBIT), затем просит одно подтверждение общей сводки. В каждом из восьми шаблонов ровно пять полных статей, а также главная, список материалов и страница о журнале. АВТОНОМНО выбирается автоматически, название и оформление — из выбранной темы. Отсутствие повторов между независимыми серверами не гарантируется.

Ручной запрос `SSH РАБОТАЕТ` убран. После применения UFW мастер автоматически повторно проверяет SSH-listeners, текущий SSH_CONNECTION и ожидаемые правила до отмены watchdog. Это локальная проверка, не замер внешней доступности; сохраняйте рабочее SSH-окно и консоль провайдера. Галочки показывают законченные этапы, стрелка — текущий; каждые10с есть heartbeat ожидания. Это не точный процент Docker-слоёв. Секретные argv/stdout/stderr не печатаются.

## Профиль создаётся в панели

Установщик сохраняет пример `/opt/remnanode/config-profile.json` с приватным ключом, `host-settings.json` и `PANEL-SETUP.txt`. Вы создаёте/назначаете профиль в панели Remnawave и связываете inbound с Host/Internal Squad. Панель управляет пользователями, `clients: []` в примере намерен.

Публичный443 работает только после применения профиля. Caddy backend — `127.0.0.1:9443`, target тот же, xver0. TCP80 нужен для ACME. API2222 только панели. Private keys/SECRET_KEY не публикуйте.

Логи Xray на сервере и внутри контейнера `/var/log/remnanode/access.log` и `error.log`; их нужно включить в секции log профиля в панели. Logrotate50M/5archives/compress/copytruncate установлен отдельно. Права системного `/var/log` не меняются.

## Управление сайтом

```bash
selfsteal
selfsteal status
selfsteal start
selfsteal stop --confirm
selfsteal restart --confirm
selfsteal renew-check
selfsteal logs --kind visits --lines 100
selfsteal logs --kind errors --lines 100
selfsteal template --template 1 --confirm  # NORTH
selfsteal template --template 2 --confirm  # STILL
selfsteal template --template 3 --confirm  # RITUAL
selfsteal template --template 4 --confirm  # INDEX
selfsteal template --template 5 --confirm  # FORM
selfsteal template --template 6 --confirm  # AFTERLIGHT
selfsteal template --template 7 --confirm  # COMMON
selfsteal template --template 8 --confirm  # ORBIT
```

В меню пункт 8 меняет шаблон с private backup/откатом и кратким перерывом Caddy; допустимы темы 1–8. Нода, профиль, ключи и certificate volumes не заменяются. Caddy продлевает сертификаты автоматически; renew-check не удаляет их ради принудительного перевыпуска. Manager живёт в `/usr/local/lib/remnanode-manager`, wrapper в `/usr/local/bin/selfsteal`. Чужая команда не перезаписывается.

## Защита и скорость

Новая установка Fail2ban SSH выполняется после автоматических локальных проверок UFW/SSH, с systemd backend, фактическими портами и точным исключением текущего клиента. После запуска ожидаются `ping` и `status sshd` до30с, а не один немедленный запрос к ещё не готовому сокету. Внешняя конфигурация/активная чужая служба не перезаписывается. Автоматический повтор требует связанного с пакетом receipt и завершённого нашего rollback; для старого отката без receipt нужен явный флаг восстановления.

### Восстановление Fail2ban после старого отката

Если после неудачной попытки пакет установлен, служба выключена и наш jail удалён, не считайте skip защитой SSH. Сначала обновите полный комплект новой сборкой. Если используете блок скачивания из начала этого README для такого восстановления, замените его последнюю строку `bash install-remnanode.sh` на `bash install-remnanode.sh wizard --recover-fail2ban` **до выполнения блока**. Не делайте сначала обычную установку, а затем повторную поверх неё.

Если новый комплект уже распакован, нода ещё не установлена и каталоги прошлой неудачной попытки архивированы, команда:

```bash
bash /opt/remnanode-local/install-remnanode.sh wizard --recover-fail2ban
```

Это разрешение только для распознанного старого завершённого rollback: known private journal/code, inactive/disabled служба, штатные неизменённые packageconfigs, зависимости и отсутствие systemd overrides. Флаг не обходит несовпавший новый receipt или внешнюю конфигурацию. Активная чужая служба не меняется. При неподтверждённом состоянии будет skip с причиной, а не ложный успех. **Флаг не обновляет старые файлы:** сначала нужно заменить полный скачанный комплект новой сборкой; на работающей ноде мастер не запускать.

BBR проверяется и включается штатным модулем при поддержке/отсутствии конфликтов, с точечным откатом. Существующие fq/fq_codel сохраняются. MTU/offload/buffers/backlog/conntrack/ядро не меняются вслепую, firewall не отключается. BBR не снимает лимит тарифа/CPU/маршрута и не ускоряет UDP напрямую. Максимальная скорость не гарантируется, автоматического speedtest нет.

## Ограничения проверки

Полный локальный набор:509тестов,505успешны,4пропущены (Windows POSIX/symlink ограничения). Реальные growpart/resize2fs, apt install Fail2ban, nftables, UFW и ACME этой сборкой на одноразовом Ubuntu-стенде не выполнялись. Исправлена гонка готовности Fail2ban, согласующаяся с пользовательскими журналами; точный прежний stderr не сохранён, поэтому реальная причина не выдаётся за окончательно доказанную. Добавлены bounded readiness/recovery-тесты и автоматические локальные UFW/SSH-проверки вместо ручного ввода.

Смотрите QUICKSTART-V2.md и TEST-REPORT.md внутри архива. При ошибке сохраняйте backup и текст ошибки. Не используйте docker system/volume prune, ufw reset, удаление /usr или массовое удаление /var/lib/docker.

## Файлы в корне GitHub

Загрузите с точными именами:

```text
README.md
README-GITHUB.md
download-install.sh
<имя-релизного-ZIP>.zip
prepare_fresh_install.py
```

После загрузки ZIP и helper обновите в блоке первой установки заполнители `HELPER_URL`, `HELPER_SHA`, `ZIP_URL` и `ZIP_SHA` фактическими URL/SHA. Не отключайте проверку и не публикуйте выдуманный финальный URL/SHA. `ZIP_SHA` — внешний SHA256 архива; внутренний `SHA256SUMS` находится в архиве и helper проверяет его сам. `prepare_fresh_install.py` скачивается отдельной проверяемой командой ниже.
