FROM registry.fit2cloud.com/metersphere/alpine-openjdk21-jre

LABEL maintainer="FIT2CLOUD <support@fit2cloud.com>"

ARG MS_VERSION=dev
ARG DEPENDENCY=backend/app/target/dependency

COPY ${DEPENDENCY}/BOOT-INF/lib /app/lib
COPY ${DEPENDENCY}/META-INF /app/META-INF
COPY ${DEPENDENCY}/BOOT-INF/classes /app

# 静态文件
COPY backend/app/src/main/resources/static /app/static
ADD frontend/public /app/static

# Redis配置文件
COPY redisson.yml /opt/metersphere/conf/redisson.yml

# 启动脚本（兼容 docker-compose 配置）
COPY shells /shells
RUN chmod +x /shells/*.sh

ENV JAVA_CLASSPATH=/app:/opt/jmeter/lib/ext/*:/app/lib/*
ENV JAVA_MAIN_CLASS=io.metersphere.Application
ENV AB_OFF=true
ENV MS_VERSION=${MS_VERSION}
ENV JAVA_OPTIONS="-Dfile.encoding=utf-8 -Djava.awt.headless=true --add-opens java.base/jdk.internal.loader=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED"

# Create necessary directories and set permissions
RUN mkdir -p /opt/metersphere/logs/metersphere/history \
    && mkdir -p /opt/metersphere/conf \
    && mkdir -p /opt/metersphere/data \
    && echo -n "${MS_VERSION}" > /tmp/MS_VERSION \
    && touch /opt/metersphere/conf/metersphere.properties \
    && chmod -R 777 /opt/metersphere

CMD ["/deployments/run-java.sh"]
