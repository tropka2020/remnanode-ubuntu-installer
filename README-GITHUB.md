sudo --preserve-env=SSH_CONNECTION bash -c '
set -Eeuo pipefail
umask 077

HELPER_URL="https://raw.githubusercontent.com/tropka2020/remnanode-ubuntu-installer/main/download-install.sh"
HELPER_SHA="11f8b8badafc0a0722fda7c54f6bd93514d297381e8b057fa3729e3aa464fc3d"

ZIP_URL="https://raw.githubusercontent.com/tropka2020/remnanode-ubuntu-installer/main/remnanode-ubuntu24-eight-sites-torrent-final.zip"
ZIP_SHA="fd7f9a4c6bcaa6b6f44bf18d74ba485b4d4c43dcf952c175ddefddbcdc3f9504"

command -v curl >/dev/null || {
    printf "Требуется curl: apt-get update && apt-get install -y curl\n" >&2
    exit 1
}

command -v python3 >/dev/null || {
    printf "Требуется python3.\n" >&2
    exit 1
}

WORK="$(mktemp -d /opt/.remnanode-helper.XXXXXX)"
trap '\''rm -rf -- "$WORK"'\'' EXIT

printf "\n[1/3] Скачивание загрузчика\n"
curl --disable --fail --show-error --location \
    --proto "=https" --proto-redir "=https" \
    --connect-timeout 30 --max-time 120 \
    --output "$WORK/download-install.sh" \
    -- "$HELPER_URL"

printf "\n[2/3] Проверка загрузчика\n"
printf "%s  %s\n" "$HELPER_SHA" "$WORK/download-install.sh" |
    sha256sum -c -

printf "\n[3/3] Скачивание архива и запуск установки\n"
bash "$WORK/download-install.sh" "$ZIP_URL" "$ZIP_SHA"
'
