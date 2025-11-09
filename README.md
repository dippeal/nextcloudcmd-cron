# nextcloudcmd-cron
nextcloudcmd that repeats synchronizations with cronjob. See https://docs.nextcloud.com/server/stable/admin_manual/desktop/commandline.html

## Start container
    docker run -d \
    -v /my/data/path:/nextcloud/data \
    -e NC_USER="username" \
    -e NC_PASS="P@ss/w:rd!" \
    -e NC_URL="https://cloud.example.com" \
    --name nextcloud_sync \
    nextcloudcmd-cron

### Optional file mounts
| Parameter                | Default       |
|--------------------------|---------------|
| /xyz/sync-exclude.lst    |               |
| /xyz/unsyncedfolders.lst |               |

### Optional parameters
| Parameter          | Default       |
|--------------------|---------------|
| NC_CRONTIME        | */5 * * * *   |
| NC_EXCLUDE         |               |
| NC_SILENT          | false         |
| NC_NTRC            | false         |
| NC_SSL_TRUST       | false         |
| NC_HTTP_PROXY      |               |
| NC_UNSYNCEDFOLDERS |               |
| NC_SYNC_RETRIES    | 3             |
| NC_SYNC_HIDDEN     | false         |


## Automatic build docker image

See .github/workflows/build-docker.yml

## Manually build docker image
    git clone https://github.com/dippeal/nextcloudcmd-cron.git
    cd nextcloudcmd-cron/
    docker build -t nextcloudcmd-cron .
