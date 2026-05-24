#!/bin/bash
set -e

echo "[INFO] Injecting proxy settings into nifi.properties..."

sed -i "s|^nifi.web.proxy.host=.*|nifi.web.proxy.host=${NIFI_WEB_PROXY_HOST}|" /opt/nifi/nifi-current/conf/nifi.properties
sed -i "s|^nifi.web.https.host=.*|nifi.web.https.host=${NIFI_WEB_HTTPS_HOST}|" /opt/nifi/nifi-current/conf/nifi.properties

# echo "[INFO] Backing up conf (excluding keystore, truststore, nifi.properties)..."
# tar czvf /backup/conf-backup.tar.gz \
#   --exclude='/opt/nifi/nifi-current/conf/keystore.p12' \
#   --exclude='/opt/nifi/nifi-current/conf/truststore.p12' \
#   --exclude='/opt/nifi/nifi-current/conf/nifi.properties' \
#   /opt/nifi/nifi-current/conf

echo "[INFO] Starting NiFi..."
/opt/nifi/nifi-current/bin/nifi.sh start && tail -F /opt/nifi/nifi-current/logs/nifi-app.log
