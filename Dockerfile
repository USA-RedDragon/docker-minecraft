FROM amazoncorretto:21.0.8-alpine@sha256:3b5deeb603e6d68144a736fe130c0394449d3f904230b92969559513b6b38a5b

ARG MC_VERSION=1.19.2
ENV MC_VERSION=${MC_VERSION}

ARG MC_VARIANT=fabric
ENV MC_VARIANT=${MC_VARIANT}

ARG FABRIC_VERSION=0.16.14
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
