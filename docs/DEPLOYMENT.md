# Despliegue

## Requisitos

- VPS Linux x86_64 o arm64 con 2 vCPU, 2 GiB RAM y disco según grabaciones.
- Docker Engine mantenido y Docker Compose v2+.
- Dominio `PUBLIC_HOST` apuntando mediante A/AAAA al VPS.
- Reloj sincronizado y acceso SSH con clave.

No se recomienda el primer despliegue directamente antes de un directo.

## Preparación

```bash
git clone <repositorio>
cd <proyecto>
cp .env.example .env
./scripts/generate-secrets.sh
editor .env
./scripts/install.sh
```

Revisa al menos `PUBLIC_HOST`. Para laboratorio empieza con
`RTMP_ENCRYPTION=no`. Para producción coloca:

```text
data/tls/tls.crt
data/tls/tls.key
```

y usa `RTMP_ENCRYPTION=strict`. La clave debe tener permiso `0600`.

## DNS y HTTPS

Crea A y, si corresponde, AAAA hacia el VPS. Caddy obtiene automáticamente el
certificado web cuando 80/443 son accesibles y el nombre DNS es público. El
certificado de RTMPS se monta por separado; puede obtenerse con un cliente ACME
del host y copiarse mediante un deploy hook que después recree solo MediaMTX.
No apuntes MediaMTX al almacenamiento interno no documentado de Caddy.

## Firewall

Ejemplo UFW; sustituye el puerto SSH y limita 1935 si conoces el rango origen:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow <PUERTO_SSH>/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 443/udp
sudo ufw allow 1936/tcp
sudo ufw allow 8890/udp
sudo ufw enable
```

Durante laboratorio RTMP:

```bash
sudo ufw allow 1935/tcp
```

No abras 8080, 8888, 9997 ni 9998. Docker puede alterar reglas iptables; valida
desde otra máquina con `nmap` y revisa la cadena `DOCKER-USER`.

## Arranque y comprobación

```bash
docker compose config
docker compose up -d --build
./scripts/health-check.sh
./scripts/test-stream.sh
docker compose logs --since=10m
```

`docker compose config` renderiza secretos; no publiques su salida.

## Desarrollo

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up --build
./scripts/test-unit.sh
```

El override publica HLS/API/metrics solo en loopback. No lo uses en producción.

## Actualización

```bash
./scripts/update.sh
```

El script bloquea la actualización si la API informa de la ruta activa, crea
backup y recrea servicios. Si la API de estado no responde o devuelve datos no
válidos, aborta antes del backup y de cualquier mutación. Como las versiones
están fijadas, cambiar una
versión requiere PR/changelog y prueba previa. Ver
[BACKUP_RESTORE.md](BACKUP_RESTORE.md).

## Comprobación posterior

- `healthz` y `readyz` devuelven 200.
- Una clave incorrecta es rechazada.
- La prueba sintética llega por SRT con dos tracks.
- Quik conecta sin emitir a Twitch.
- OBS reproduce audio/vídeo y reconecta tras reiniciar Quik.
- Tras validar RTMPS, cerrar 1935.
