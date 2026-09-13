FROM amazoncorretto:17.0.20-alpine@sha256:8aa46a55845b61ba079f8289556fcc1a7887cdf303d360bc27140ab38300d44e

ARG FORGE_VERSION=1.20.1-47.4.23
ENV FORGE_VERSION=${FORGE_VERSION}

# Used in entrypoint
ARG MC_VARIANT=forge
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
INSTALLER="forge-${FORGE_VERSION}-installer.jar"
BASE_URL="https://maven.minecraftforge.net/net/minecraftforge/forge/${FORGE_VERSION}"

cd /tmp
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
__DOCKER_EOF__

RUN addgroup -g 1000 minecraft
RUN adduser -u 1000 -G minecraft -s /bin/sh -D minecraft
RUN chown -R minecraft:minecraft /minecraft /forge

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 25565

ENV ACCEPT_EULA=false
ENV EXTRA_JAVA_OPTS=""
ENV MEMORY_OPTS="-Xms128M -Xmx1G"

USER minecraft

ENTRYPOINT /entrypoint.sh
