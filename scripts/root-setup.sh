#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf 'Run with sudo: sudo bash %s\n' "$0" >&2
    exit 2
fi

VM_USER="${SUDO_USER:-devops}"
VM_HOME="$(getent passwd "$VM_USER" | cut -d: -f6)"
PROJECT_DIR="$VM_HOME/kr2"

if [ ! -d "$PROJECT_DIR" ]; then
    printf 'Project directory not found: %s\n' "$PROJECT_DIR" >&2
    exit 2
fi

# Capture the firewall state before installing the KR2 reverse proxy. The
# script never changes UFW rules.
ufw status numbered > "$VM_HOME/ufw-before-kr2.txt"
chown "$VM_USER:$VM_USER" "$VM_HOME/ufw-before-kr2.txt"

cert_ok=false
if [ -f /etc/ssl/certs/kr2.crt ] && [ -f /etc/ssl/private/kr2.key ]; then
    if openssl x509 -in /etc/ssl/certs/kr2.crt -noout -ext subjectAltName \
        | grep -q 'DNS:notes.devops.local'; then
        cert_ok=true
    else
        stamp="$(date +%Y%m%d%H%M%S)"
        cp -a /etc/ssl/certs/kr2.crt "/etc/ssl/certs/kr2.crt.$stamp.bak"
        cp -a /etc/ssl/private/kr2.key "/etc/ssl/private/kr2.key.$stamp.bak"
    fi
fi

if [ "$cert_ok" != true ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/kr2.key \
        -out /etc/ssl/certs/kr2.crt \
        -subj '/CN=notes.devops.local' \
        -addext 'subjectAltName=DNS:notes.devops.local'
fi

chown root:root /etc/ssl/private/kr2.key /etc/ssl/certs/kr2.crt
chmod 600 /etc/ssl/private/kr2.key
chmod 644 /etc/ssl/certs/kr2.crt

if [ -e /etc/nginx/sites-available/kr2 ] \
    && ! cmp -s "$PROJECT_DIR/nginx/kr2" /etc/nginx/sites-available/kr2; then
    cp -a /etc/nginx/sites-available/kr2 \
        "/etc/nginx/sites-available/kr2.$(date +%Y%m%d%H%M%S).bak"
fi
install -o root -g root -m 644 "$PROJECT_DIR/nginx/kr2" /etc/nginx/sites-available/kr2
ln -sfn /etc/nginx/sites-available/kr2 /etc/nginx/sites-enabled/kr2

nginx -t
systemctl reload nginx

printf 'Root setup complete. UFW rules were not changed.\n'
