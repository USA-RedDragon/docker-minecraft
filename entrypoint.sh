#!/bin/sh

trap "exit" INT TERM ERR
trap "kill 0" EXIT

if [ "${ACCEPT_EULA}" = "true" ]; then
    echo "eula=true" > /minecraft/eula.txt
fi

MEMORY_OPTS=${MEMORY_OPTS:-"-Xms128M -Xmx1G"}

JAVA_OPTS="${MEMORY_OPTS} ${EXTRA_JAVA_OPTS}"

LAUNCH_ARGS=""
if [ "${MC_VARIANT}" = "paper" ]; then
    LAUNCH_ARGS="-jar /paper-${PAPER_VERSION}-${PAPER_BUILD}.jar"
elif [ "${MC_VARIANT}" = "fabric" ]; then
    LAUNCH_ARGS="-jar /fabric-${MC_VERSION}-${FABRIC_VERSION}-${INSTALLER_VERSION}.jar"
elif [ "${MC_VARIANT}" = "forge" ]; then
    LAUNCH_ARGS="@/forge/libraries/net/minecraftforge/forge/${FORGE_VERSION}/unix_args.txt"
else
    echo "Unknown variant: ${MC_VARIANT}"
    exit 1
fi

exec java ${JAVA_OPTS} ${LAUNCH_ARGS} --nogui
