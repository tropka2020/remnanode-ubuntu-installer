#!/usr/bin/env bash
# Download this helper first and verify its independently published SHA256.
# Run as a child, NEVER source it or pipe a remote response into a shell:
# sudo --preserve-env=SSH_CONNECTION bash ./download-install.sh HTTPS_ZIP_URL ZIP_SHA256
# URL and digest are public release data; domain, panel and secret belong in the wizard.
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    printf '%s\n' 'Запустите helper дочерним bash, не через source.' >&2
    return 1
fi
set -Eeuo pipefail
umask 077

fail() { printf '%s\n' "$*" >&2; exit 1; }
[[ $# -eq 2 ]] || fail 'Использование: bash download-install.sh HTTPS_ZIP_URL ZIP_SHA256'
[[ "$1" == https://* ]] || fail 'Требуется HTTPS URL архива.'
[[ "$2" =~ ^[[:xdigit:]]{64}$ ]] || fail 'Требуется фиксированный SHA256 архива (64 hex).'
[[ "$EUID" -eq 0 ]] || fail 'Запустите через sudo --preserve-env=SSH_CONNECTION bash.'
for tool in curl python3 mktemp mv; do
    command -v "$tool" >/dev/null 2>&1 || fail "Не найдена команда: $tool"
done

# A root-owned, non-writable parent prevents staging/target substitution by users.
python3 -I - <<'PY_OPT'
from pathlib import Path
import stat
p = Path('/opt')
s = p.lstat()
if not stat.S_ISDIR(s.st_mode) or s.st_uid != 0 or s.st_mode & 0o022:
    raise SystemExit('/opt must be a root-owned directory, not writable by group/others.')
PY_OPT
TARGET=/opt/remnanode-local
[[ ! -e "$TARGET" && ! -L "$TARGET" ]] || fail 'Каталог /opt/remnanode-local уже существует; ничего не изменено.'
WORK="$(mktemp -d /opt/.remnanode-download.XXXXXXXX)"
cleanup() { rm -rf -- "$WORK"; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
curl --disable --fail --show-error --silent --location --proto '=https' --proto-redir '=https' \
    --connect-timeout 30 --max-time 600 --max-filesize 134217728 \
    --output "$WORK/release.zip" -- "$1"

# Validate the fixed outer hash and ALL member metadata before creating any file.
python3 -I - "$WORK/release.zip" "$2" "$WORK/extracted" <<'PY_RELEASE'
import hashlib
from pathlib import Path
import re
import stat
import sys
import zipfile

archive_path, expected, destination = sys.argv[1:]
if hashlib.sha256(Path(archive_path).read_bytes()).hexdigest() != expected.lower():
    raise SystemExit('ZIP SHA256 mismatch; nothing installed.')
root = Path(destination)
with zipfile.ZipFile(archive_path) as archive:
    members = archive.infolist()
    if not members or len(members) > 10000 or sum(m.file_size for m in members) > 134217728:
        raise SystemExit('ZIP exceeds release limits.')
    seen, files = set(), set()
    for member in members:
        name = member.filename
        parts = name.rstrip('/').split('/')
        mode = member.external_attr >> 16
        kind = stat.S_IFMT(mode)
        if (name != member.orig_filename or name.endswith('//') or '\\' in name or ':' in name
                or any(ord(c) < 32 or ord(c) == 127 for c in name)
                or parts[0] != 'remnanode-local' or any(p in ('', '.', '..') for p in parts)
                or (len(parts) == 1 and not member.is_dir())
                or member.flag_bits & 1
                or kind not in (0, stat.S_IFREG, stat.S_IFDIR)
                or (kind == stat.S_IFDIR and not member.is_dir())
                or (kind == stat.S_IFREG and member.is_dir())
                or member.external_attr & 0x400):  # Windows reparse point
            raise SystemExit('Unsafe ZIP member: ' + repr(name))
        canonical = '/'.join(parts)
        if canonical in seen:
            raise SystemExit('Duplicate ZIP member: ' + repr(name))
        seen.add(canonical)
        if not member.is_dir():
            files.add(canonical)
    if any('/'.join(name.split('/')[:i]) in files
           for name in seen for i in range(1, len(name.split('/')))):
        raise SystemExit('ZIP file/directory collision.')
    if not {'remnanode-local/SHA256SUMS', 'remnanode-local/install-remnanode.sh'} <= files:
        raise SystemExit('Missing release entrypoint or checksums.')
    root.mkdir(mode=0o700)
    # Manual extraction: never restore archive permissions, links or special files.
    for member in members:
        target = root.joinpath(*member.filename.rstrip('/').split('/'))
        if member.is_dir():
            target.mkdir(mode=0o700, parents=True, exist_ok=True)
        else:
            target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            with archive.open(member) as source, target.open('xb') as output:
                while chunk := source.read(1024 * 1024):
                    output.write(chunk)

# Interpret the inner manifest relative to the EXTRACTED remnanode-local root.
release = root / 'remnanode-local'
checksums = {}
for line in (release / 'SHA256SUMS').read_text(encoding='utf-8').splitlines():
    match = re.fullmatch(r'([0-9a-f]{64})  (.+)', line)
    if not match:
        raise SystemExit('Malformed inner checksum manifest.')
    digest, name = match.groups()
    parts = name.split('/')
    if (name in checksums or '\\' in name or ':' in name
            or any(p in ('', '.', '..') for p in parts)
            or 'remnanode-local/' + name not in files or name == 'SHA256SUMS'):
        raise SystemExit('Unsafe or duplicate checksum path.')
    checksums[name] = digest
if {'remnanode-local/' + name for name in checksums} != files - {'remnanode-local/SHA256SUMS'}:
    raise SystemExit('Inner checksum inventory mismatch.')
for name, digest in checksums.items():
    if hashlib.sha256((release / name).read_bytes()).hexdigest() != digest:
        raise SystemExit('Inner SHA256 mismatch: ' + name)
print('ZIP metadata, exact inventory and inner checksums verified.')
PY_RELEASE

# GNU mv -n may succeed without moving: recheck the source before launching.
[[ ! -e "$TARGET" && ! -L "$TARGET" ]] || fail 'Каталог назначения появился; установка отменена.'
mv -T -n -- "$WORK/extracted/remnanode-local" "$TARGET"
[[ ! -e "$WORK/extracted/remnanode-local" && ! -L "$WORK/extracted/remnanode-local" ]] \
    || fail 'Каталог назначения занят; существующие файлы не изменены.'
[[ -d "$TARGET" && ! -L "$TARGET" ]] || fail 'Не удалось перенести проверенный релиз.'
# Keep this as a child bash: failures must not exit the calling SSH shell.
bash "$TARGET/install-remnanode.sh" wizard
