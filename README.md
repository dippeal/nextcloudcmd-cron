# nextcloudcmd-cron
nextcloudcmd that repeats synchronizations with cronjob. See https://docs.nextcloud.com/server/stable/admin_manual/desktop/commandline.html

## Start container
```bash
docker run -d \
-v /my/data/path:/nextcloud/data \
-e NC_USER="username" \
-e NC_PASS="MY-CLIENT-APP-PASSWORD" \
-e NC_URL="https://cloud.example.com" \
--name nextcloud_sync \
nextcloudcmd-cron
```

### Optional file mounts
| Local path               | Container path                 |
|--------------------------|--------------------------------|
| /xyz/sync-exclude.lst    | /nextcloud/sync-exclude.lst    |
| /xyz/unsyncedfolders.lst | /nextcloud/unsyncedfolders.lst |

See https://docs.nextcloud.com/server/stable/admin_manual/desktop/commandline.html#exclude-list

### Optional parameters
| Parameter          | Default       |
|--------------------|---------------|
| NC_CRONTIME        | */5 * * * *   |
| NC_SILENT          | false         |
| NC_NTRC            | false         |
| NC_SSL_TRUST       | false         |
| NC_HTTP_PROXY      |               |
| NC_SYNC_RETRIES    | 3             |
| NC_SYNC_HIDDEN     | false         |


## Automatic build docker image
- Add new tag and take a look at Actions > Build Docker Image on Tag (see .github/workflows/build-docker.yml)

```bash
git tag <x.y.z>
git push --tags
```

## Manually build docker image
```bash
git clone https://github.com/dippeal/nextcloudcmd-cron.git
cd nextcloudcmd-cron/
docker build -t nextcloudcmd-cron .
```
