#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    printf 'Run with sudo: sudo bash %s\n' "$0" >&2
    exit 2
fi

VM_USER="${SUDO_USER:-devops}"
VM_HOME="$(getent passwd "$VM_USER" | cut -d: -f6)"
PROJECT_DIR="$VM_HOME/kr2"
HOSTS_FILE=/etc/hosts
HOSTS_BACKUP=/etc/hosts.kr2.before

if [ ! -d "$PROJECT_DIR" ]; then
    printf 'Project directory not found: %s\n' "$PROJECT_DIR" >&2
    exit 2
fi

# Capture the firewall state before installing the KR2 reverse proxy. The
# script never changes UFW rules.
ufw status numbered > "$VM_HOME/ufw-before-kr2.txt"
chown "$VM_USER:$VM_USER" "$VM_HOME/ufw-before-kr2.txt"

# Docker Hub currently resolves to IPv6 first on this VM even though the VM
# has no IPv6 default route. Keep the PR7 CDN entries and add only the two
# missing Docker Hub names, using addresses resolved over IPv4 at run time.
if ! grep -q '^# BEGIN KR2 DOCKER HUB IPV4$' "$HOSTS_FILE"; then
    registry_ip="$(getent ahostsv4 registry-1.docker.io | awk 'NR==1 {print $1}')"
    auth_ip="$(getent ahostsv4 auth.docker.io | awk 'NR==1 {print $1}')"
    if [[ ! "$registry_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] \
        || [[ ! "$auth_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        printf 'Could not resolve Docker Hub IPv4 addresses safely\n' >&2
        exit 2
    fi
    cp -a "$HOSTS_FILE" "$HOSTS_BACKUP"
    {
        printf '\n# BEGIN KR2 DOCKER HUB IPV4\n'
        printf '%s registry-1.docker.io\n' "$registry_ip"
        printf '%s auth.docker.io\n' "$auth_ip"
        printf '# END KR2 DOCKER HUB IPV4\n'
    } >> "$HOSTS_FILE"
fi

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
