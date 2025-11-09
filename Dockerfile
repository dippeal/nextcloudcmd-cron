FROM debian:latest

# Environment Variables
ENV NC_USER=""
ENV NC_PASS=""
ENV NC_URL=""
ENV NC_NTRC="false"
ENV NC_SILENT="false"
ENV NC_SSL_TRUST="false"
ENV NC_HTTP_PROXY=""
ENV NC_SYNC_RETRIES=""
ENV NC_SYNC_HIDDEN="false"
ENV NC_CRONTIME="*/5 * * * *"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nextcloud-desktop-cmd \
        cron \
        ca-certificates \
        curl \
        python3 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /nextcloud

# Sync script
RUN cat <<'EOF' > /usr/local/bin/run_sync.sh
#!/bin/bash
set -e

# Prüfen, ob Pflichtvariablen gesetzt sind
if [ -z "$NC_USER" ] || [ -z "$NC_PASS" ] || [ -z "$NC_URL" ]; then
  echo "ERROR: NC_USER, NC_PASS and NC_URL must be set!" >&2
  exit 1
fi

# URL encode credentials
ENC_USER=$(python3 -c "import urllib.parse, os; print(urllib.parse.quote(os.environ['NC_USER']))")
ENC_PASS=$(python3 -c "import urllib.parse, os; print(urllib.parse.quote(os.environ['NC_PASS']))")

# Full URL mit Benutzer und Passwort
FULL_URL=$(echo "$NC_URL" | sed "s#://#://$ENC_USER:$ENC_PASS@#")

# Argumente bauen
ARGS=""
if [ "$NC_NTRC" = "true" ]; then ARGS="$ARGS -n"; fi
if [ "$NC_SILENT" = "true" ]; then ARGS="$ARGS -s"; fi
if [ "$NC_SSL_TRUST" = "true" ]; then ARGS="$ARGS --trust"; fi
if [ -n "$NC_SYNC_RETRIES" ]; then ARGS="$ARGS --max-sync-retries $NC_SYNC_RETRIES"; fi
if [ "$NC_SYNC_HIDDEN" = "true" ]; then ARGS="$ARGS -h"; fi
if [ -n "$NC_HTTP_PROXY" ]; then ARGS="$ARGS --httpproxy $NC_HTTP_PROXY"; fi

# Prüfen auf exclude-Datei
EXCLUDE_FILE="/nextcloud/sync-exclude.lst"
if [ -f "$EXCLUDE_FILE" ]; then
  ARGS="$ARGS --exclude $EXCLUDE_FILE"
fi

# Prüfen auf unsyncedfolders-Datei
UNSYNC_FILE="/nextcloud/unsyncedfolders.lst"
if [ -f "$UNSYNC_FILE" ]; then
  ARGS="$ARGS --unsyncedfolders $UNSYNC_FILE"
fi

echo "[$(date)] Starting Nextcloud sync..." >&1
nextcloudcmd $ARGS /nextcloud/data "$FULL_URL"
echo "[$(date)] Sync complete." >&1
EOF

RUN chmod +x /usr/local/bin/run_sync.sh

# Startscript für dynamische Crontab
RUN cat <<'EOF' > /usr/local/bin/start.sh
#!/bin/bash
set -e

# Crontab zur Laufzeit erstellen
echo "$NC_CRONTIME root /usr/local/bin/run_sync.sh >> /proc/1/fd/1 2>&1" > /etc/cron.d/nextcloud-cron
chmod 0644 /etc/cron.d/nextcloud-cron
crontab /etc/cron.d/nextcloud-cron

# Cron im Vordergrund starten
exec cron -f
EOF

RUN chmod +x /usr/local/bin/start.sh

# Mountpoint für Daten
VOLUME ["/nextcloud"]

# Container startet mit dynamischer Crontab
CMD ["/usr/local/bin/start.sh"]
