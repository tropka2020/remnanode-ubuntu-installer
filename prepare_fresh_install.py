#!/usr/bin/env python3
"""Archive known failed-installation paths; never purge Docker or reset firewall."""
import argparse
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile

PATHS = ('/opt/remnanode', '/opt/caddy', '/opt/remnanode-local', '/var/lib/remnanode-design')
BASE = Path('/var/backups/remnanode-local')


def safe(path, directory=None):
    path = Path(path)
    for item in [*reversed(path.parents), path]:
        if not os.path.lexists(item):
            continue
        info = item.lstat()
        if stat.S_ISLNK(info.st_mode) or info.st_uid != 0 or info.st_mode & 0o022:
            raise RuntimeError('Небезопасный путь; остановка: ' + str(item))
        if item == path and directory is True and not stat.S_ISDIR(info.st_mode):
            raise RuntimeError('Ожидается каталог: ' + str(item))
    return path


def command(args, allowed=(0,)):
    result = subprocess.run(args, capture_output=True, text=True, timeout=20)
    if result.returncode not in allowed:
        raise RuntimeError('Проверка не выполнена: ' + args[0] + '. Ничего не удаляйте вслепую.')
    return result


def checks():
    if shutil.which('docker'):
        if command(['docker', 'ps', '-aq']).stdout.strip():
            raise RuntimeError('Есть контейнеры Docker. Автоматическая очистка запрещена: сначала проверить их назначение.')
    timers = command(['systemctl', 'list-units', '--all', '--plain', '--no-legend',
                      '--state=active,activating,deactivating', 'remnanode-ufw-rollback-*']).stdout.strip()
    if timers:
        raise RuntimeError('Ещё активна служба/таймер восстановления UFW. Сначала проверить её состояние; очистка остановлена.')
    state = command(['systemctl', 'is-active', 'fail2ban'], allowed=(0, 3, 4))
    if state.stdout.strip() not in ('inactive', 'unknown'):
        raise RuntimeError('Fail2ban активен либо его состояние неизвестно. Защита SSH не меняется.')
    if os.path.lexists('/usr/sbin/policy-rc.d'):
        raise RuntimeError('Найден policy-rc.d. Сначала изучить его принадлежность, автоматически не удаляется.')
    if command(['dpkg', '--audit']).stdout.strip():
        raise RuntimeError('dpkg сообщает незавершённые операции. Сначала нужна диагностика пакетов.')
    targets = [safe(name, directory=True) for name in PATHS if os.path.lexists(name)]
    wrapper = Path('/usr/local/bin/selfsteal')
    runtime = Path('/usr/local/lib/remnanode-manager')
    if os.path.lexists(wrapper):
        safe(wrapper)
        if not wrapper.is_file() or wrapper.stat().st_size > 4096:
            raise RuntimeError('Неизвестный selfsteal; перезапись запрещена.')
        text = wrapper.read_text()
        old = '#!/bin/sh\nexec /usr/bin/python3 /opt/remnanode-local/selfsteal.py "$@"\n'
        new = '#!/bin/sh\n# remnanode-manager managed runtime v1\nexec /usr/bin/python3 /usr/local/lib/remnanode-manager/selfsteal.py "$@"\n'
        if text not in (old, new):
            raise RuntimeError('Найден чужой selfsteal; очистка остановлена.')
        targets.append(wrapper)
    if os.path.lexists(runtime):
        safe(runtime, directory=True)
        marker = safe(runtime / '.managed-runtime')
        if not marker.is_file() or marker.read_text() != '# remnanode-manager managed runtime v1\n':
            raise RuntimeError('Неизвестный runtime; очистка остановлена.')
        targets.append(runtime)
    return targets


def main():
    import fcntl
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='После проверок запросить подтверждение и архивировать')
    args = parser.parse_args()
    if os.geteuid() != 0:
        raise RuntimeError('Нужен root на Linux.')
    os.umask(0o077)
    lock = safe('/run/remnanode-local.lock')
    fd = os.open(lock, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        info = os.fstat(fd)
        if info.st_nlink != 1 or not stat.S_ISREG(info.st_mode):
            raise RuntimeError('Небезопасный lock.')
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        targets = checks()
        print('Будут ПЕРЕМЕЩЕНЫ в закрытую резервную копию:')
        for path in targets:
            print(' ', path)
        print('Docker/пакеты, тома сертификатов, логи, UFW, BBR и старые backup не удаляются.')
        if not args.apply:
            print('Только проверка. Для архивирования повторите с --apply.')
            return
        if input('Для нового начала введите ПЕРЕНАЧАТЬ: ').strip() != 'ПЕРЕНАЧАТЬ':
            print('Отменено.')
            return
        if checks() != targets:
            raise RuntimeError('Состояние изменилось; остановка без перемещения.')
        safe(BASE, directory=True).mkdir(mode=0o700, parents=True, exist_ok=True)
        backup = Path(tempfile.mkdtemp(prefix='fresh-start-', dir=BASE))
        moved = []
        try:
            for index, path in enumerate(targets):
                destination = backup / (str(index) + '-' + path.name)
                path.rename(destination)
                moved.append((path, destination))
        except BaseException:
            for original, saved in reversed(moved):
                if not os.path.lexists(original):
                    saved.rename(original)
            raise
        print('Сохранено в:', backup)
        print('Рабочие пути освобождены. Можно скачать новый комплект по команде README.')
    finally:
        os.close(fd)


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as exc:
        raise SystemExit(str(exc))
