#!/usr/bin/env bash
set -u

failures=0

check() {
    local description="$1"
    shift
    if "$@"; then
        printf 'PASS: %s\n' "$description"
    else
        printf 'FAIL: %s\n' "$description"
        failures=$((failures + 1))
    fi
}

redis_healthy() {
    [ "$(docker inspect -f '{{.State.Health.Status}}' kr2-redis-1 2>/dev/null)" = healthy ]
}

app_loopback_port() {
    [ "$(docker port kr2-app-1 8002/tcp 2>/dev/null)" = '127.0.0.1:8002' ]
}

env_mode_600() {
    [ "$(stat -c '%a' "$HOME/kr2/.env" 2>/dev/null)" = 600 ]
}

certificate_valid_30_days() {
    openssl x509 -checkend 2592000 -noout -in /etc/ssl/certs/kr2.crt >/dev/null 2>&1
}

nginx_site_enabled() {
    [ "$(readlink -f /etc/nginx/sites-enabled/kr2 2>/dev/null)" = /etc/nginx/sites-available/kr2 ]
}

printf '[KR2 variant 2]\n'
check 'Redis container is healthy' redis_healthy
check 'Application is published only on 127.0.0.1:8002' app_loopback_port
check 'Redis environment file mode is 600' env_mode_600
check 'TLS certificate is valid for at least 30 days' certificate_valid_30_days
check 'Nginx KR2 site symlink is active' nginx_site_enabled

exit "$failures"

