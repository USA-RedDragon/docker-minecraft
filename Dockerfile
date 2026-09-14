# syntax=docker/dockerfile:1

ARG JAVA_IMAGE=amazoncorretto:21.0.12-alpine@sha256:ca805c030d45db58e93b2276580ea141aa7d33497009ab4c6b706c587a97e9b1

FROM ${JAVA_IMAGE} AS base

RUN apk add --no-cache \
  curl \
  nano \
  bash

SHELL [ "bash", "-c" ]

COPY --from=ghcr.io/srs-hosting/rcon:v0.0.5@sha256:effa0b6f89db5f4edd7904677fb1671a88d48a4c62a92f331edbd5a850e34cee /rcon /usr/bin/rcon
COPY --chown=root:root rootfs/ /

RUN addgroup -g 1000 minecraft \
  && adduser -u 1000 -G minecraft -s /bin/sh -D minecraft

WORKDIR /minecraft

EXPOSE 25565

ENV ACCEPT_EULA=false
ENV EXTRA_JAVA_OPTS=""
ENV MEMORY_OPTS="-Xms128M -Xmx1G"

ENTRYPOINT [ "/entrypoint" ]

FROM base AS paper

ARG PAPER_VERSION
ARG PAPER_BUILD

ENV PAPER_VERSION="${PAPER_VERSION}"
ENV PAPER_BUILD="${PAPER_BUILD}"

ENV MC_VARIANT=paper

RUN <<__DOCKER_EOF__
set -euxo pipefail
JAR="/paper-${PAPER_VERSION}-${PAPER_BUILD}.jar"
USER_AGENT="USA-RedDragon/docker-minecraft (https://github.com/USA-RedDragon/docker-minecraft)"

apk add --no-cache --virtual .paper-build jq

BUILD=$(curl -fSsL -A "${USER_AGENT}" "https://fill.papermc.io/v3/projects/paper/versions/${PAPER_VERSION}/builds/${PAPER_BUILD}")
URL=$(echo "${BUILD}" | jq -er '.downloads["server:default"].url')
SHA256=$(echo "${BUILD}" | jq -er '.downloads["server:default"].checksums.sha256')

curl -fSsL -A "${USER_AGENT}" "${URL}" -o "${JAR}"
echo "${SHA256}  ${JAR}" | sha256sum -c

apk del .paper-build
__DOCKER_EOF__

FROM base AS fabric

ARG MC_VERSION
ARG FABRIC_VERSION
ARG INSTALLER_VERSION

ENV MC_VERSION=${MC_VERSION}
ENV FABRIC_VERSION=${FABRIC_VERSION}
ENV INSTALLER_VERSION=${INSTALLER_VERSION}

ENV MC_VARIANT=fabric

RUN <<__DOCKER_EOF__
set -euxo pipefail
JAR="/fabric-${MC_VERSION}-${FABRIC_VERSION}-${INSTALLER_VERSION}.jar"

curl -fSsL "https://meta.fabricmc.net/v2/versions/loader/${MC_VERSION}/${FABRIC_VERSION}/${INSTALLER_VERSION}/server/jar" -o "${JAR}"
__DOCKER_EOF__

FROM base AS forge

ARG FORGE_VERSION
ENV FORGE_VERSION=${FORGE_VERSION}

ENV MC_VARIANT=forge

RUN <<__DOCKER_EOF__
set -euxo pipefail
INSTALLER="forge-${FORGE_VERSION}-installer.jar"
BASE_URL="https://maven.minecraftforge.net/net/minecraftforge/forge/${FORGE_VERSION}"

curl -fSsL "${BASE_URL}/${INSTALLER}" -o "${INSTALLER}"
SHA256=$(curl -fSsL "${BASE_URL}/${INSTALLER}.sha256")
echo "${SHA256}  ${INSTALLER}" | sha256sum -c

java -jar "${INSTALLER}" --installServer /forge
rm -f "${INSTALLER}" "${INSTALLER}.log" /forge/run.bat

# The generated argument file references libraries relative to the install
# directory. Make them absolute so the server can run from /minecraft.
ARGS_FILE="/forge/libraries/net/minecraftforge/forge/${FORGE_VERSION}/unix_args.txt"
sed -i \
  -e 's#libraries/#/forge/libraries/#g' \
  -e 's#^-DlibraryDirectory=libraries$#-DlibraryDirectory=/forge/libraries#' \
  "${ARGS_FILE}"

SHIM="/forge/forge-${FORGE_VERSION}-shim.jar"
if [ -f "${SHIM}" ]; then
  MAIN=$(unzip -p "${SHIM}" bootstrap-shim.properties | tr -d '\r' | sed -n 's/^Main-Class=//p')
  LAUNCH=$(unzip -p "${SHIM}" bootstrap-shim.properties | tr -d '\r' | sed -n 's/^Arguments=//p')
  CLASSPATH=$(unzip -p "${SHIM}" bootstrap-shim.list | tr -d '\r' | cut -f3 | sed 's#^#/forge/libraries/#' | paste -sd: -)
  sed -i "s# -jar forge-${FORGE_VERSION}-shim.jar# -cp ${CLASSPATH} ${MAIN} ${LAUNCH}#" "${ARGS_FILE}"
fi

MC_VERSION="${FORGE_VERSION%%-*}"
SERVER_LIBS="/forge/libraries/net/minecraft/server"
shopt -s nullglob
rm -rf /tmp/* \
  "${SERVER_LIBS}/${MC_VERSION}/server-${MC_VERSION}.jar" \
  "${SERVER_LIBS}"/*/server-*-{bundled,unpacked,slim}.jar \
  "${SERVER_LIBS}"/*/server-*-mappings.*
__DOCKER_EOF__
