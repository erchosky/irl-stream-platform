# Backup y restauración

La versión 0.1.1 respalda configuración versionable, `.env` y TLS. No hay base
de datos. Grabaciones no se incluyen para evitar copias enormes.

## Backup

```bash
./scripts/backup.sh
```

El resultado es un `.tar.gz` con permisos restrictivos en `BACKUP_DIR`. Contiene
secretos: cópialo a almacenamiento cifrado. El script genera un SHA-256 con
`sha256sum` (Linux) o `shasum` (macOS); el checksum usa un nombre relativo para
que archivo y suma puedan trasladarse juntos.

## Restauración

```bash
./scripts/restore.sh backups/irl-platform-AAAAmmddTHHMMSSZ.tar.gz
```

El script verifica checksum si existe, lista el contenido, rechaza rutas
absolutas/`..`, solicita confirmación y crea una copia previa. Detén la emisión.

Después:

```bash
docker compose config
docker compose up -d --build
./scripts/health-check.sh
./scripts/test-stream.sh
```

## Retención

`BACKUP_RETENTION_DAYS` se aplica al crear backups. No elimina grabaciones.
Prueba restauración trimestralmente en otro VPS; un archivo no probado no es una
estrategia de recuperación.
