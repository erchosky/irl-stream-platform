# Solución de problemas

Empieza por:

```bash
./scripts/health-check.sh
./scripts/diagnostics.sh
docker compose logs --since=10m mediamtx control-api gateway
```

Los diagnósticos omiten `.env`; revisa cualquier archivo antes de compartirlo.

## El nodo no arranca

- `CHANGE_ME`: ejecuta `./scripts/generate-secrets.sh`.
- “Compose not found”: instala Docker Compose v2.
- Daemon inaccesible: inicia Docker/Colima o el servicio Docker Linux.
- RTMPS y certificado inexistente: vuelve temporalmente a `no` o instala
  `data/tls/tls.crt` y `tls.key`.
- Puerto ocupado: `sudo ss -lntup` en Linux.

## Quik recibe Unauthorized

Confirma ruta `irl`, `PUBLISH_TOKEN` completo y URL combinada. No pruebes
repetidamente con tokens en terminal compartido. La API registra acción,
protocolo, ruta e IP, nunca el secreto.

## OBS no recibe SRT

SRT es UDP. Revisa UFW/security group, passphrase, streamid y que Quik esté
publicando. Prueba primero desde el VPS con `./scripts/test-stream.sh`.

## HLS devuelve 401

Envía `Authorization: Bearer READ_TOKEN`. Un navegador abierto directamente no
puede adjuntar cómodamente el header; el panel de Fase 3 lo hará desde una
sesión autenticada.

## El stream vuelve pero OBS no

Fase 1 depende de reconexión del cliente. Desactiva/activa la fuente multimedia.
Si requiere intervención, anótalo como evidencia para Fase 2; no es prueba de
continuidad.

## Audio desincronizado

Ejecuta la prueba sintética, registra el desfase y compara RTMP frente a SRT.
No compenses a ciegas. Comprueba sample rate, carga del equipo OBS y latencia
configurada.

