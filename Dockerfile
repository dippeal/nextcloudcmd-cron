FROM debian:latest

LABEL maintainer="deinname@example.com"
LABEL description="nextcloudcmd-cron: NextcloudCMD Cron Sync Container (Logs to STDOUT, Boolean Flags, NC_* Variables)"

# Environment Variables
ENV NC_USER=""
ENV NC_PASS=""
ENV NC_URL=""
ENV NC_NTRC="false"
ENV NC_SILENT="false"
ENV NC_SSL_TRUST="false"
ENV NC_HTTP_PROXY=""
ENV NC_SYNC_RETRIES="3"
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
RUN echo '#!/bin/bash\n' \
    'set -e\n' \
    '\n' \
    '# Check required values\n' \
    'if [ -z "$NC_USER" ] || [ -z "$NC_PASS" ] || [ -z "$NC_URL" ]; then\n' \
    '  echo "ERROR: NC_USER, NC_PASS and NC_URL must be set!" >&2\n' \
    '  exit 1\n' \
    'fi\n' \
    '\n' \
    '# URL encode credentials\n' \
    'ENC_USER=$(python3 -c "import urllib.parse, os; print(urllib.parse.quote(os.environ[\'NC_USER\']))")\n' \
    'ENC_PASS=$(python3 -c "import urllib.parse, os; print(urllib.parse.quote(os.environ[\'NC_PASS\']))")\n' \
    '\n' \
    '# Build full URL\n' \
    'FULL_URL=$(echo "$NC_URL" | sed "s#://#://$ENC_USER:$ENC_PASS@#")\n' \
    '\n' \
    '# Build argument list\n' \
    'ARGS=""\n' \
    'if [ "$NC_NTRC" = "true" ]; then ARGS="$ARGS -n"; fi\n' \
    'if [ "$NC_SILENT" = "true" ]; then ARGS="$ARGS -s"; fi\n' \
    'if [ "$NC_SSL_TRUST" = "true" ]; then ARGS="$ARGS --trust"; fi\n' \
    'if [ -n "$NC_SYNC_RETRIES" ]; then ARGS="$ARGS --max-sync-retries $NC_SYNC_RETRIES"; fi\n' \
    'if [ "$NC_SYNC_HIDDEN" = "true" ]; then ARGS="$ARGS -h"; fi\n' \
    'if [ -n "$NC_HTTP_PROXY" ]; then ARGS="$ARGS --httpproxy $NC_HTTP_PROXY"; fi\n' \
    '\n' \
    '# Check if exclude file exists\n' \
    'EXCLUDE_FILE="/nextcloud/sync-exclude.lst"\n' \
    'if [ -f "$EXCLUDE_FILE" ]; then\n' \
    '  ARGS="$ARGS --exclude $EXCLUDE_FILE"\n' \
    'fi\n' \
    '\n' \
    '# Check if unsyncedfolders file exists\n' \
    'UNSYNC_FILE="/nextcloud/unsyncedfolders.lst"\n' \
    'if [ -f "$UNSYNC_FILE" ]; then\n' \
    '  ARGS="$ARGS --unsyncedfolders $UNSYNC_FILE"\n' \
    'fi\n' \
    '\n' \
    'echo "[$(date)] Starting Nextcloud sync..." >&1\n' \
    'nextcloudcmd $ARGS /nextcloud/data "$FULL_URL"\n' \
    'echo "[$(date)] Sync complete." >&1\n' \
    > /usr/local/bin/run_sync.sh && chmod +x /usr/local/bin/run_sync.sh

# Cronjob
RUN echo '$NC_CRONTIME root /usr/local/bin/run_sync.sh >> /proc/1/fd/1 2>&1' \
    > /etc/cron.d/nextcloud-cron && \
    chmod 0644 /etc/cron.d/nextcloud-cron && \
    crontab /etc/cron.d/nextcloud-cron

# Mountpoint
VOLUME ["/nextcloud"]

# Run cron in foreground
CMD ["bash", "-c", "cron -f"]
