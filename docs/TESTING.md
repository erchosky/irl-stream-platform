# Pruebas

## Capas

| Capa | Comando | Verifica |
|---|---|---|
| Configuración | `./scripts/check-config.sh` | secretos, YAML/Compose, shell |
| Unitarias | `./scripts/test-unit.sh` | matriz auth, métodos, config |
| Integración media | `./scripts/test-stream.sh` | RTMP/SRT/RTMP y HLS vía Caddy |
| Salud | `./scripts/health-check.sh` | procesos y API MediaMTX |
| Física | checklist GoPro/OBS | compatibilidad real |

## Prueba sintética

El contenedor genera testsrc H.264 y tono AAC, publica por RTMP, lee por SRT a
MPEG-TS y usa `ffprobe`. Comprueba:

1. H.264 1280×720 a 30 fps y AAC 48 kHz;
2. captura de 2,5-4,5 s y unión A/V dentro de un GOP de 2 s;
3. HLS público devuelve 401 sin token y playlist con Bearer válido;
4. una passphrase SRT incorrecta es rechazada;
5. un token de publicación incorrecto es rechazado;
6. republicación tras desconexión y lectura RTMP autenticada;
7. metadatos finales de la captura.

La prueba se ejecuta también con una ruta no predeterminada durante auditoría
para detectar divergencias entre API, MediaMTX, Caddy y clientes.

No prueba continuidad durante el hueco; es objetivo de Fase 2.

## Matriz Fase 1

- [ ] Docker Linux x86_64.
- [ ] Docker Linux arm64.
- [ ] RTMP desde FFmpeg.
- [ ] RTMPS con certificado público.
- [ ] SRT lectura con cifrado.
- [ ] RTMP lectura alternativa.
- [ ] HLS con/sin token.
- [ ] GoPro Quik iOS instalada.
- [ ] GoPro Quik Android instalada si se usará.
- [ ] OBS macOS.
- [ ] OBS Windows 11.
- [ ] Stream continuo 2 h.
- [ ] Reinicio de contenedor y host.

Solo se marca una casilla tras ejecutar y guardar resultado. Las pruebas de
fallos de red (`tc netem`) se implementan en Fase 2/14.

## Evidencia

Los resultados actuales están en [TEST_REPORT.md](TEST_REPORT.md). El informe
deja explícitamente sin marcar la matriz física y de resistencia pendiente.
