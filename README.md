sudo bash -c '
set -Eeuo pipefail
umask 077

TARGET="/opt/remnanode-local"
URL="https://raw.githubusercontent.com/tropka2020/remnanode-ubuntu-installer/main/remnanode-ubuntu24-official-compose.zip"
SHA256="172d0057293be6b6d009e04d9e0ead41b4382be3688b14481670a8283057f8cd"

command -v curl >/dev/null || {
    printf "Сначала установите curl: apt-get update && apt-get install -y curl\n" >&2
    exit 1
}

command -v python3 >/dev/null || {
    printf "Требуется Python 3.\n" >&2
    exit 1
}

if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
    printf "Каталог %s уже существует. Автоматическая перезапись запрещена.\n" "$TARGET" >&2
    exit 1
fi

TMP="$(mktemp -d /opt/.remnanode-install.XXXXXX)"
trap '\''rm -rf -- "$TMP"'\'' EXIT

printf "\n[1/4] Скачивание установщика\n"
curl -fSL --proto "=https" --proto-redir "=https" \
    --connect-timeout 15 --max-time 300 --retry 3 \
    "$URL" -o "$TMP/installer.zip"

printf "\n[2/4] Проверка SHA-256 архива\n"
printf "%s  %s\n" "$SHA256" "$TMP/installer.zip" | sha256sum -c -

printf "\n[3/4] Распаковка и проверка файлов\n"
python3 -m zipfile -e "$TMP/installer.zip" "$TMP"
(
    cd "$TMP/remnanode-local"
    sha256sum -c SHA256SUMS
)

mv -T -- "$TMP/remnanode-local" "$TARGET"

printf "\n[4/4] Запуск мастера\n"
cd "$TARGET"
bash install-remnanode.sh
'
