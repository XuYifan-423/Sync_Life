#!/bin/bash
set -e

cd /opt/server/Sync

cat > config.py << EOF
POSTGRES_PASSWORD="$POSTGRES_PASSWORD"
POSTGRES_DB="$POSTGRES_DB"
POSTGRES_USER="$POSTGRES_USER"
POSTGRES_ADDR="$POSTGRES_ADDR"
EOF

#运行Django迁移
echo "运行Django迁移..."
../.venv/bin/python3 manage.py migrate --noinput

../.venv/bin/python3 manage.py runserver 0.0.0.0:8000
