FROM apache/nifi:latest

USER root

WORKDIR /opt/nifi/nifi-current

# Set default environment variables (can be overridden by Kubernetes)
ENV NIFI_WEB_PROXY_HOST=ih-nifi-svc:8443
ENV NIFI_WEB_HTTPS_HOST=0.0.0.0

COPY nifi_scripts nifi_scripts/
RUN chmod a+x nifi_scripts/LoadStage/*
RUN chmod a+x nifi_scripts/ExtractStage/*

COPY nifi-entrypoint.sh /opt/nifi/nifi-entrypoint.sh
RUN chmod +x /opt/nifi/nifi-entrypoint.sh

ENTRYPOINT ["/opt/nifi/nifi-entrypoint.sh"]
