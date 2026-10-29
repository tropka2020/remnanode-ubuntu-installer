#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# All modules must be copied together; never execute a remote response as shell code.
if [[ $# -eq 0 || "${1:-}" == "wizard" ]]; then
    if ! command -v python3 >/dev/null 2>&1; then
        printf '%s\n' 'Требуется Python 3 (штатно установлен в Ubuntu 24.04).' >&2
        exit 1
    fi
    if [[ "${1:-}" == "wizard" ]]; then shift; fi
    exec python3 "${ROOT}/installer.py" "$@"
fi
exec python3 "${ROOT}/manage.py" "$@"
