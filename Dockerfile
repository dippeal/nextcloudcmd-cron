FROM debian:latest

# === Environment Variables ===
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
ENV PUID="1000"
ENV PGID="1000"

# === Install dependencies ===
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nextcloud-desktop-cmd \
        cron \
        ca-certificates \
        curl \
        python3 \
        gosu && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /nextcloud

# === Main sync script ===
RUN cat <<'EOF' > /usr/local/bin/run_sync.sh
#!/bin/bash
set -e

# Validate required values
if [ -z "$NC_USER" ] || [ -z "$NC_PASS" ] || [ -z "$NC_URL" ]; then
  echo "ERROR: NC_USER, NC_PASS and NC_URL must be set!" >&2
  exit 1
fi

# URL-encode credentials
ENC_USER=$(python3 -c "import urllib.parse, os; print(urllib.parse.quote(os.environ['NC_USER']))")
ENC_PASS=$(python3 -c "import urllib.parse, os; print(urllib.parse.quote(os.environ['NC_PASS']))")

# Build full URL
FULL_URL=$(echo "$NC_URL" | sed "s#://#://$ENC_USER:$ENC_PASS@#")

# Build argument list
ARGS=""
if [ "$NC_NTRC" = "true" ]; then ARGS="$ARGS -n"; fi
if [ "$NC_SILENT" = "true" ]; then ARGS="$ARGS -s"; fi
if [ "$NC_SSL_TRUST" = "true" ]; then ARGS="$ARGS --trust"; fi
if [ -n "$NC_SYNC_RETRIES" ]; then ARGS="$ARGS --max-sync-retries $NC_SYNC_RETRIES"; fi
if [ "$NC_SYNC_HIDDEN" = "true" ]; then ARGS="$ARGS -h"; fi
if [ -n "$NC_HTTP_PROXY" ]; then ARGS="$ARGS --httpproxy $NC_HTTP_PROXY"; fi

# Optional exclude and unsynced folder files
EXCLUDE_FILE="/nextcloud/sync-exclude.lst"
if [ -f "$EXCLUDE_FILE" ]; then
  ARGS="$ARGS --exclude $EXCLUDE_FILE"
fi

UNSYNC_FILE="/nextcloud/unsyncedfolders.lst"
if [ -f "$UNSYNC_FILE" ]; then
  ARGS="$ARGS --unsyncedfolders $UNSYNC_FILE"
fi

# Start sync
echo "[$(date)] Starting Nextcloud sync as user $(id -u):$(id -g) ..." >&1
nextcloudcmd $ARGS /nextcloud/data "$FULL_URL"
echo "[$(date)] Sync complete." >&1
EOF

RUN chmod +x /usr/local/bin/run_sync.sh

# === Startup script ===
RUN cat <<'EOF' > /usr/local/bin/start.sh
#!/bin/bash
set -e

# Create group if not existing
if ! getent group "$PGID" >/dev/null 2>&1; then
  groupadd -g "$PGID" nextcloudgroup
else
  groupmod -n nextcloudgroup "$(getent group "$PGID" | cut -d: -f1)"
fi

# Create user if not existing
if ! id -u "$PUID" >/dev/null 2>&1; then
  useradd -u "$PUID" -g "$PGID" -M -s /bin/bash nextcloud
else
  usermod -l nextcloud "$(getent passwd "$PUID" | cut -d: -f1)"
fi

# Fix ownership for mounted data
chown -R "$PUID:$PGID" /nextcloud

# Export environment variables for cron jobs
printenv | grep '^NC_' > /etc/environment
echo "PUID=$PUID" >> /etc/environment
echo "PGID=$PGID" >> /etc/environment

# Create cron schedule dynamically
echo "$NC_CRONTIME root gosu nextcloud /usr/local/bin/run_sync.sh >> /proc/1/fd/1 2>&1" > /etc/cron.d/nextcloud-cron
chmod 0644 /etc/cron.d/nextcloud-cron
crontab /etc/cron.d/nextcloud-cron

# Perform initial sync
echo "[$(date)] Performing initial sync..." >&1
gosu nextcloud /usr/local/bin/run_sync.sh

# Start cron in foreground
echo "[$(date)] Starting cron with schedule: $NC_CRONTIME" >&1
exec cron -f
EOF

RUN chmod +x /usr/local/bin/start.sh

VOLUME ["/nextcloud"]

CMD ["/usr/local/bin/start.sh"]
