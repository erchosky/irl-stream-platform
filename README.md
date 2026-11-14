# IRL Stream Platform

Plataforma propia para recibir una GoPro HERO10 Black mediante GoPro Quik,
transportar la señal por RTMP/RTMPS a un VPS y entregarla a OBS Studio por SRT.

Estado actual: **Fase 1 implementada; validación física con GoPro y VPS
pendiente**. No hay panel web, continuidad de salida ni fallback todavía.
Consulta [STATUS.md](STATUS.md) antes de usarla en un directo.

## Arquitectura actual

```text
GoPro Quik --RTMP(S)--> MediaMTX --SRT cifrado--> OBS --> Twitch
                              |
                        HLS autenticado
                              |
                    API de autenticación Go
```

- MediaMTX 1.19.3 enruta el stream sin transcodificar.
- La API Go valida tokens en tiempo constante y expone salud/estado.
- Caddy 2.11.4 proporciona HTTPS para salud y HLS.
- Docker Compose es la unidad de despliegue. No se usan PostgreSQL, Redis,
  Kubernetes ni colas en esta fase.

La arquitectura, puertos y límites están en
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
La auditoría técnica más reciente está en
[docs/AUDIT_REPORT.md](docs/AUDIT_REPORT.md).

## Arranque

Requisitos: Linux con Docker Engine y Docker Compose v2 o posterior, un dominio
con registros DNS al VPS y puertos de firewall según
[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).

```bash
cp .env.example .env
./scripts/generate-secrets.sh
# Editar PUBLIC_HOST y revisar .env
docker compose config
docker compose up -d --build
./scripts/health-check.sh
./scripts/test-stream.sh
```

`generate-secrets.sh` no sobrescribe valores que ya no sean `CHANGE_ME`.

## URLs

Con los valores por defecto:

- GoPro: `rtmp://HOST:1935/irl?token=PUBLISH_TOKEN`
- OBS/SRT: `srt://HOST:8890?streamid=read:irl:reader:READ_TOKEN&passphrase=SRT_READ_PASSPHRASE&latency=2000000`
- RTMP alternativo: `rtmp://HOST:1935/irl?token=READ_TOKEN`
- HLS: `https://PUBLIC_HOST/irl/index.m3u8` con
  `Authorization: Bearer READ_TOKEN`

Las URLs contienen secretos. No las pegues en capturas, tickets ni logs.

## Pruebas

```bash
./scripts/check-config.sh
./scripts/test-unit.sh
./scripts/test-stream.sh
./scripts/diagnostics.sh
```

La prueba de stream usa una fuente FFmpeg sintética real y comprueba
publicación RTMP, lectura SRT, audio/vídeo, rechazo de token incorrecto y una
republicación. No sustituye la prueba física documentada en
[docs/GOPRO_SETUP.md](docs/GOPRO_SETUP.md).

## Documentación

- [Arquitectura](docs/ARCHITECTURE.md)
- [Roadmap y criterios](docs/ROADMAP.md)
- [Seguridad](docs/SECURITY.md)
- [Despliegue](docs/DEPLOYMENT.md)
- [GoPro HERO10 + Quik](docs/GOPRO_SETUP.md)
- [OBS Studio](docs/OBS_SETUP.md)
- [Pruebas](docs/TESTING.md)
- [Auditoría técnica](docs/AUDIT_REPORT.md)
- [Diagnóstico](docs/TROUBLESHOOTING.md)
- [Backup y restauración](docs/BACKUP_RESTORE.md)
- [Fuentes técnicas](docs/SOURCES.md)
