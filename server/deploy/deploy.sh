#!/usr/bin/env bash
# Розгортання навчального банку на VPS: ./server/deploy/deploy.sh user@host [ключ ssh]
# Ідемпотентний: повторний запуск оновлює код і перезапускає службу. База й .env на сервері не чіпаються.
# Потрібні права root (або sudo без пароля) на VPS, nginx і certbot.
set -euo pipefail

TARGET=${1:?користувач@хост}
KEY=${2:-}
DOMAIN=bank.munister.com.ua
HERE=$(cd "$(dirname "$0")/.." && pwd)
SSH=(ssh -o BatchMode=yes ${KEY:+-i "$KEY"})
SUDO=$([ "${TARGET%%@*}" = root ] && echo "" || echo "sudo")

# мобільний веб-застосунок: збираємо з web/ у server/frontend, сервер віддає його з кореня домену
if [ -f "$HERE/../web/package.json" ]; then
  (cd "$HERE/../web" && npm ci --no-audit --no-fund --silent && npm run build --silent)
fi

"${SSH[@]}" "$TARGET" "$SUDO id kopiyka >/dev/null 2>&1 || $SUDO useradd --system --home /opt/kopiyka --shell /usr/sbin/nologin kopiyka; $SUDO mkdir -p /opt/kopiyka/server && $SUDO chown -R \$(id -un) /opt/kopiyka"
rsync -az --no-owner --no-group --delete -e "ssh ${KEY:+-i $KEY}" \
  --exclude '.env' --exclude 'database/*.db' --exclude '__pycache__' --exclude '.pytest_cache' --exclude 'tests' \
  "$HERE/" "$TARGET:/opt/kopiyka/server/"

"${SSH[@]}" "$TARGET" bash -s <<REMOTE
set -euo pipefail
cd /opt/kopiyka
[ -d venv ] || python3 -m venv venv
venv/bin/pip install -q --upgrade pip
venv/bin/pip install -q -r server/requirements.txt
if [ ! -f server/.env ]; then
  printf 'SECRET_KEY=%s\nDEBUG=0\nHOST=127.0.0.1\nPORT=5050\nAPPLE_CLIENT_ID=com.eprisjournal.kopiyka\n' "\$(openssl rand -hex 32)" > server/.env
fi
mkdir -p server/database
$SUDO chown -R kopiyka:kopiyka /opt/kopiyka/server/database
$SUDO chown root:kopiyka server/.env && $SUDO chmod 640 server/.env
$SUDO chmod -R go+rX /opt/kopiyka/venv /opt/kopiyka/server
$SUDO install -m 644 server/deploy/kopiyka-bank.service /etc/systemd/system/kopiyka-bank.service
$SUDO systemctl daemon-reload
$SUDO systemctl enable --now kopiyka-bank
$SUDO systemctl restart kopiyka-bank
# nginx: свій конфіг ставимо лише коли на домен ще немає жодного. Якщо домен уже обслуговує інший сайт,
# його конфіг перемикають вручну (proxy_pass на 127.0.0.1:5050), цей скрипт його не чіпає.
if grep -rqE "server_name[^;]*$DOMAIN" /etc/nginx/conf.d /etc/nginx/sites-enabled 2>/dev/null; then
  echo "nginx: на $DOMAIN уже є конфіг, не чіпаю."
else
  $SUDO install -m 644 server/deploy/nginx-bank.conf /etc/nginx/conf.d/$DOMAIN.conf
  $SUDO nginx -t && $SUDO systemctl reload nginx
  $SUDO test -d /etc/letsencrypt/live/$DOMAIN || \\
    $SUDO certbot --nginx -d $DOMAIN --non-interactive --agree-tos --register-unsafely-without-email --redirect
fi
REMOTE
echo "Готово: код і служба оновлені (127.0.0.1:5050)."
