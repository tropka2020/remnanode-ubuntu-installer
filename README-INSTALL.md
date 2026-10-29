# Remnawave Node: чистая Ubuntu 24.04

Этот комплект ставит Node Remnawave, Caddy, один из восьми локальных сайтов и официальный **latest GitHub DEB** `xray-torrent-blocker`. Рекомендуется только новая Ubuntu 24.04 с доступной консолью провайдера и snapshot.

## Файлы релиза

В GitHub загружаются в корень репозитория:

```text
remnanode-ubuntu24-eight-sites-torrent-final2.zip
download-install.sh
README-INSTALL.md
```

До публикации замените в `README-GITHUB.md` заполнители фактическими raw URL и SHA. Не используйте старый архив или SHA от предыдущей сборки.

## Что спросит мастер

- домен, который указывает на IP **ноды**;
- IPv4 Remnawave Panel;
- `SECRET_KEY` из панели, ввод скрыт;
- тема 1–8;
- одно подтверждение общей сводки.

Тема 1–8: NORTH, STILL, RITUAL, INDEX, FORM, AFTERLIGHT, COMMON, ORBIT. Каждая тема содержит пять статей и восемь HTML-страниц.

## Официальные пути

```text
Node:        /opt/remnanode
Caddy:       /opt/caddy
Node env:    /opt/remnanode/remnanode.env (0600)
Xray logs:   /var/log/remnanode/access.log
             /var/log/remnanode/error.log
Node API:    TCP 2222, только IPv4 панели
Caddy TLS:   127.0.0.1:9443
Public:      80/443; публичный 443 только после профиля панели
```

## Torrent Blocker

Установщик динамически получает текущий стабильный GitHub release через `releases/latest`, выбирает официальный DEB для архитектуры и проверяет SHA-256 asset/digest и `checksums.txt`. Версия намеренно не закрепляется.

Официальный DEB сам создаёт:

```text
/opt/tblocker/config.yaml
/etc/systemd/system/tblocker.service
```

Наш код не генерирует YAML. До запуска службы проверяются:

```yaml
LogFile: "/var/log/remnanode/access.log"
BlockMode: "iptables"
TorrentTag: "TORRENT"
```

В профиль Xray добавлены access/error logs и правило:

```text
protocol bittorrent -> TORRENT -> blackhole
```

Upstream использует raw-цепочку `TBLOCKER_BLOCKED` и source-IP DROP. Такой блок может затронуть SSH и других пользователей за NAT. Остановка службы не гарантирует снятие уже созданных правил. Наш откат удаляет только проверенные неизменённые собственные правила; неизвестные правила сохраняются для ручной проверки. `ufw reset`, `iptables -F`, `nft flush ruleset` и удаление чужих цепочек не выполняются.

Пакетные файлы, APT-репозиторий, keyring, зависимости, `conntrack.conf` и неизвестные upstream-файлы не удаляются при откате автоматически. При ошибке сохраняются приватные stdout/stderr, фазы, URL, SHA, время и DEB-файл в `/var/backups/remnanode-local/tblocker-*`, права каталога 0700 и файлов 0600.

## Предварительные требования

- Ubuntu 24.04 amd64/arm64, root, systemd, SSH и консоль провайдера;
- DNS A домена напрямую на IP ноды, без CDN/proxy;
- firewall провайдера: SSH, TCP80/443, API2222 только панели;
- не запускайте поверх существующей ноды;
- не публикуйте `config-profile.json`, `remnanode.env`, YAML, диагностику и private key.

## После установки

1. Откройте `/opt/remnanode/PANEL-SETUP.txt`.
2. Добавьте ноду в панели на API `IP_НОДЫ:2222`.
3. Примените `/opt/remnanode/config-profile.json` как серверный Config Profile.
4. Проверьте, что панель сохранила `bittorrent -> TORRENT`, blackhole outbound и пути логов.
5. Проверьте внешний VPN-клиент отдельно.

`active` у tblocker или успешный Xray `-test` не доказывают реальное обнаружение торрента или внешнюю доступность 443.

## Если установка упала

Не повторяйте мастер вслепую. Сохраните этап и путь диагностики из ошибки:

```bash
find /var/backups/remnanode-local -maxdepth 3 -type f -name 'failure.json' -o -name '*.stderr'
```

Не публикуйте эти файлы целиком. Не выполняйте `docker system prune`, `docker volume prune`, `ufw reset`, `iptables -F` или ручное удаление `/opt/tblocker` до проверки состояния службы, пакета и firewall.

## Границы проверки

Локальные тесты используют mocks/temp и не являются интеграционной проверкой APT, DEB maintainer scripts, systemd, UFW/iptables, conntrack, ACME или панели. Перед production используйте отдельный snapshot-backed Ubuntu стенд.
