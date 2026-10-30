#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf 'Run with sudo: sudo bash %s\n' "$0" >&2
    exit 2
fi

vm_user="${SUDO_USER:-devops}"
vm_home="$(getent passwd "$vm_user" | cut -d: -f6)"
project_dir="$vm_home/kr2"

printf 'NGINX_CONFIG\n'
nginx -t

printf 'UFW_RULES_DIFF\n'
if diff <(ufw status numbered) "$vm_home/ufw-before-kr2.txt"; then
    printf 'unchanged\n'
else
    printf 'UFW rules changed\n' >&2
    exit 1
fi

printf 'FILE_PERMISSIONS\n'
stat -c '%a %U:%G %n' "$project_dir/.env" /etc/ssl/private/kr2.key

printf 'ACTIVE_SECRET_SCAN\n'
redis_password="$(sed -n 's/^REDIS_PASSWORD=//p' "$project_dir/.env")"
if [ -z "$redis_password" ]; then
    printf 'REDIS_PASSWORD is missing\n' >&2
    exit 1
fi
mapfile -t leaked_files < <(
    grep -RIlF --exclude=.env -- "$redis_password" "$project_dir" 2>/dev/null || true
)
if [ "${#leaked_files[@]}" -ne 0 ]; then
    printf '%s\n' "${leaked_files[@]}"
    exit 1
fi
printf 'no copies outside .env\n'
unset redis_password

printf 'INTEGRATED_AUDIT\n'
bash "$vm_home/devops-pr5/scripts/audit.sh"
