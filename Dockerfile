FROM amazoncorretto:21.0.11-alpine@sha256:30b1b2246cee9a98c9bf8a11537a04f1eaf8c59279b0c70ae02d7e5b934edeaa

ARG MC_VERSION=1.19.2
ENV MC_VERSION=${MC_VERSION}

ARG MC_VARIANT=fabric
ENV MC_VARIANT=${MC_VARIANT}

ARG FABRIC_VERSION=0.19.5
ENV FABRIC_VERSION=${FABRIC_VERSION}

ARG INSTALLER_VERSION=0.11.2
ENV INSTALLER_VERSION=${INSTALLER_VERSION}

WORKDIR /minecraft

RUN apk add --no-cache \
  curl \
  jq \
  nano \
  bash

RUN curl -fsL https://meta.fabricmc.net/v2/versions/loader/${MC_VERSION}/${FABRIC_VERSION}/${INSTALLER_VERSION}/server/jar -o /fabric-${MC_VERSION}-${FABRIC_VERSION}-${INSTALLER_VERSION}.jar

RUN addgroup -g 1000 minecraft
RUN adduser -u 1000 -G minecraft -s /bin/sh -D minecraft
RUN chown -R minecraft:minecraft /minecraft /fabric-${MC_VERSION}-${FABRIC_VERSION}-${INSTALLER_VERSION}.jar

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 25565

ENV ACCEPT_EULA=false
ENV EXTRA_JAVA_OPTS=""
ENV MEMORY_OPTS="-Xms128M -Xmx1G"

USER minecraft

ENTRYPOINT /entrypoint.sh
