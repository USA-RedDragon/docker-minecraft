FROM amazoncorretto:21.0.1-alpine@sha256:6a11101b77ee8e6dfb0c60cf804f58549d06a960f73fd6761799880aa42ec117

ARG PAPER_VERSION=1.20.4
ARG PAPER_BUILD=381

ENV PAPER_VERSION="${PAPER_VERSION}"
ENV PAPER_BUILD="${PAPER_BUILD}"

# Used in entrypoint
ARG MC_VARIANT=paper
ENV MC_VARIANT=${MC_VARIANT}

WORKDIR /minecraft

RUN apk add --no-cache \
  curl \
  jq \
  nano \
  bash

SHELL [ "bash", "-c" ]

RUN <<__DOCKER_EOF__
set -eux
SHA256=$(curl -fSsL https://api.papermc.io/v2/projects/paper/versions/${PAPER_VERSION}/builds | jq -r ".builds[] | select(.build==${PAPER_BUILD}).downloads.application.sha256")

curl -fSsL \
  https://api.papermc.io/v2/projects/paper/versions/${PAPER_VERSION}/builds/${PAPER_BUILD}/downloads/paper-${PAPER_VERSION}-${PAPER_BUILD}.jar \
  -o /paper-${PAPER_VERSION}-${PAPER_BUILD}.jar

echo "${SHA256}  /paper-${PAPER_VERSION}-${PAPER_BUILD}.jar" | sha256sum -c
__DOCKER_EOF__

RUN addgroup -g 1000 minecraft
RUN adduser -u 1000 -G minecraft -s /bin/sh -D minecraft
RUN chown -R minecraft:minecraft /minecraft /paper-${PAPER_VERSION}-${PAPER_BUILD}.jar

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 25565

ENV ACCEPT_EULA=false
ENV EXTRA_JAVA_OPTS=""
ENV MEMORY_OPTS="-Xms128M -Xmx1G"

USER minecraft

ENTRYPOINT /entrypoint.sh
