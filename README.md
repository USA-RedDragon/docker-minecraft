# docker-minecraft

Minecraft server images for Paper, Fabric, Forge and NeoForge.

## Usage

```sh
docker run -d \
  -p 25565:25565 \
  -v minecraft:/minecraft \
  -e ACCEPT_EULA=true \
  -e RCON_PASSWORD=changeme \
  ghcr.io/usa-reddragon/papermc:latest
```

The server runs in `/minecraft`. Mount a volume there to keep the world and config.

## Environment

| Variable | Default | Description |
| --- | --- | --- |
| `ACCEPT_EULA` | `false` | Set to `true` to accept the [Minecraft EULA](https://aka.ms/MinecraftEULA). |
| `RCON_PASSWORD` | | Required. The server does not start without it. |
| `RCON_PORT` | `25575` | RCON port. |
| `MEMORY_OPTS` | `-Xms128M -Xmx1G` | JVM memory flags. |
| `EXTRA_JAVA_OPTS` | | Extra JVM flags. |

RCON is always enabled. On start, `enable-rcon`, `rcon.port` and `rcon.password` are written to `server.properties`. No other properties are changed.

## Health and shutdown

`/health` exits 0 when the game port (`server-port`, default 25565) and the RCON port are listening.

`/pre-stop` is meant for a Kubernetes `preStop` hook. It announces the restart in chat, kicks anyone who joins while it runs, waits up to 10 minutes for players to leave, then kicks the rest and saves the world. Set `terminationGracePeriodSeconds` high enough to cover that, for example 900.

```yaml
readinessProbe:
  exec:
    command: ["/health"]
lifecycle:
  preStop:
    exec:
      command: ["/pre-stop"]
```

## Forge and NeoForge RCON

The Forge and NeoForge images patch the server's `RconClient` at build time (see `rcon-fix/`):

- Forge 1.20.6 and later sends no response packet for a command with no output, such as `say` or `tellraw`. Most RCON clients then hang or time out. The patched server sends an empty response.
- Forge and NeoForge split long responses every 4096 bytes, which can cut a multi-byte UTF-8 character in half. The patched server splits on character boundaries and keeps packets within 4096 bytes.

## Versions

<!-- versions:start -->

### Fabric

`ghcr.io/usa-reddragon/fabric`

| Minecraft | Fabric loader | Java | Tags |
| --- | --- | --- | --- |
| 26.2 | 0.19.5 (installer 1.1.2) | 25 | `26.2`, `latest` |
| 26.1.2 | 0.19.5 (installer 1.1.2) | 25 | `26.1.2` |
| 26.1.1 | 0.19.5 (installer 1.1.2) | 25 | `26.1.1` |
| 26.1 | 0.19.5 (installer 1.1.2) | 25 | `26.1` |
| 1.21.11 | 0.19.5 (installer 1.1.2) | 21 | `1.21.11` |
| 1.21.10 | 0.19.5 (installer 1.1.2) | 21 | `1.21.10` |
| 1.21.9 | 0.19.5 (installer 1.1.2) | 21 | `1.21.9` |
| 1.21.8 | 0.19.5 (installer 1.1.2) | 21 | `1.21.8` |
| 1.21.7 | 0.19.5 (installer 1.1.2) | 21 | `1.21.7` |
| 1.21.6 | 0.19.5 (installer 1.1.2) | 21 | `1.21.6` |
| 1.21.5 | 0.19.5 (installer 1.1.2) | 21 | `1.21.5` |
| 1.21.4 | 0.19.5 (installer 1.1.2) | 21 | `1.21.4` |
| 1.21.3 | 0.19.5 (installer 1.1.2) | 21 | `1.21.3` |
| 1.21.2 | 0.19.5 (installer 1.1.2) | 21 | `1.21.2` |
| 1.21.1 | 0.19.5 (installer 1.1.2) | 21 | `1.21.1` |
| 1.21 | 0.19.5 (installer 1.1.2) | 21 | `1.21` |
| 1.20.6 | 0.19.5 (installer 1.1.2) | 21 | `1.20.6` |
| 1.20.5 | 0.19.5 (installer 1.1.2) | 21 | `1.20.5` |
| 1.20.4 | 0.19.5 (installer 1.1.2) | 21 | `1.20.4` |
| 1.20.3 | 0.19.5 (installer 1.1.2) | 21 | `1.20.3` |
| 1.20.2 | 0.19.5 (installer 0.11.2) | 21 | `1.20.2` |
| 1.20.1 | 0.19.5 (installer 0.11.2) | 21 | `1.20.1` |
| 1.19.2 | 0.19.5 (installer 0.11.2) | 21 | `1.19.2` |

### Forge

`ghcr.io/usa-reddragon/forge`

| Minecraft | Forge | Java | Tags |
| --- | --- | --- | --- |
| 26.2 | 65.1.0 | 25 | `26.2`, `26.2-65.1.0`, `latest` |
| 26.1.2 | 64.1.0 | 25 | `26.1.2`, `26.1.2-64.1.0` |
| 1.21.11 | 61.2.0 | 21 | `1.21.11`, `1.21.11-61.2.0` |
| 1.21.10 | 60.1.0 | 21 | `1.21.10`, `1.21.10-60.1.0` |
| 1.21.8 | 58.1.0 | 21 | `1.21.8`, `1.21.8-58.1.0` |
| 1.21.5 | 55.1.0 | 21 | `1.21.5`, `1.21.5-55.1.0` |
| 1.21.4 | 54.1.14 | 21 | `1.21.4`, `1.21.4-54.1.14` |
| 1.21.3 | 53.1.0 | 21 | `1.21.3`, `1.21.3-53.1.0` |
| 1.21.1 | 52.1.0 | 21 | `1.21.1`, `1.21.1-52.1.0` |
| 1.20.6 | 50.2.0 | 21 | `1.20.6`, `1.20.6-50.2.0` |
| 1.20.1 | 47.4.23 | 17 | `1.20.1`, `1.20.1-47.4.23` |

### NeoForge

`ghcr.io/usa-reddragon/neoforge`

| Minecraft | NeoForge | Java | Tags |
| --- | --- | --- | --- |
| 26.2 | 26.2.0.88 | 25 | `26.2`, `26.2.0.88`, `latest` |
| 26.1.2 | 26.1.2.109 | 25 | `26.1.2`, `26.1.2.109` |
| 1.21.11 | 21.11.45 | 21 | `1.21.11`, `21.11.45` |
| 1.21.10 | 21.10.64 | 21 | `1.21.10`, `21.10.64` |
| 1.21.8 | 21.8.54 | 21 | `1.21.8`, `21.8.54` |
| 1.21.5 | 21.5.98 | 21 | `1.21.5`, `21.5.98` |
| 1.21.4 | 21.4.157 | 21 | `1.21.4`, `21.4.157` |
| 1.21.3 | 21.3.97 | 21 | `1.21.3`, `21.3.97` |
| 1.21.1 | 21.1.250 | 21 | `1.21.1`, `21.1.250` |
| 1.21 | 21.0.167 | 21 | `1.21`, `21.0.167` |
| 1.20.6 | 20.6.141 | 21 | `1.20.6`, `20.6.141` |
| 1.20.4 | 20.4.251 | 17 | `1.20.4`, `20.4.251` |
| 1.20.2 | 20.2.93 | 17 | `1.20.2`, `20.2.93` |

### Paper

`ghcr.io/usa-reddragon/papermc`

| Minecraft | Paper build | Java | Tags |
| --- | --- | --- | --- |
| 26.2 | 123 | 25 | `26.2`, `26.2-123`, `latest` |
| 26.1.2 | 74 | 25 | `26.1.2`, `26.1.2-74` |
| 1.21.11 | 132 | 21 | `1.21.11`, `1.21.11-132` |
| 1.21.10 | 130 | 21 | `1.21.10`, `1.21.10-130` |
| 1.21.8 | 60 | 21 | `1.21.8`, `1.21.8-60` |
| 1.21.7 | 32 | 21 | `1.21.7`, `1.21.7-32` |
| 1.21.6 | 48 | 21 | `1.21.6`, `1.21.6-48` |
| 1.21.4 | 232 | 21 | `1.21.4`, `1.21.4-232` |
| 1.21.3 | 83 | 21 | `1.21.3`, `1.21.3-83` |
| 1.21.1 | 133 | 21 | `1.21.1`, `1.21.1-133` |
| 1.21 | 130 | 21 | `1.21`, `1.21-130` |
| 1.20.6 | 151 | 21 | `1.20.6`, `1.20.6-151` |
| 1.20.4 | 499 | 21 | `1.20.4`, `1.20.4-499` |
| 1.20.2 | 318 | 21 | `1.20.2`, `1.20.2-318` |
| 1.20.1 | 196 | 21 | `1.20.1`, `1.20.1-196` |

<!-- versions:end -->

These tables are generated from `docker-bake.hcl` by CI.

## Building

```sh
docker buildx bake --print
docker buildx bake paper-1_21_11
```

To add a Minecraft version, add an entry to its target in `docker-bake.hcl`.
