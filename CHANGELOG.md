# Changelog

## [0.1.1] - 2026-07-31

### Corregido

- `MEDIA_PATH` ahora configura de forma coherente autenticación, MediaMTX,
  passphrase SRT, Caddy y pruebas; también se valida como segmento seguro.
- Las actualizaciones fallan de forma segura si no pueden consultar el estado
  multimedia y siguen bloqueadas durante una fuente activa.
- La API rechaza JSON concatenado y valida el origen de la API de MediaMTX.
- Backup y restore aceptan `sha256sum` en Linux o `shasum` en macOS y generan
  checksums trasladables.
- Caddy se ejecuta como UID/GID 10003 sin capacidades efectivas; un servicio
  efímero y aislado migra los permisos de volúmenes existentes.
- Runtimes actualizados a Alpine 3.23.5 y Caddy 2.11.4 recompilado con Go y
  dependencias corregidas; el escaneo de imágenes queda sin HIGH/CRITICAL.

### Mejorado

- Integración ampliada a siete controles: formatos, duración/unión A/V, SRT
  incorrecto, HLS público con/sin token, publicación inválida, republicación y
  lectura RTMP autenticada.
- Imágenes de pruebas con paquetes fijados, análisis estático y auditoría
  documentada.

## [0.1.0] - 2026-07-29

### Añadido

- Diseño y documentación completa de Fase 0.
- Nodo MediaMTX con entradas RTMP/RTMPS/SRT y salidas SRT/RTMP/HLS.
- Servicio Go de autenticación y salud.
- Terminación HTTPS con Caddy.
- Docker Compose de producción y desarrollo.
- Scripts operativos y pruebas sintéticas.
- Corrección de ruta MediaMTX para overrides seguros por entorno.
- HLS autenticado en ruta nativa para conservar redirecciones.
- Bloqueo de actualización durante una fuente activa.

### No incluido

- Continuidad/fallback, panel, OBS WebSocket, grabación y multistream.
